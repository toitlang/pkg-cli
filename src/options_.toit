// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import fs
import host.directory
import host.file
import host.pipe
import io
import uuid show Uuid

import .cli show Command
import .completion_ show DIRECTIVE-FILE-COMPLETION_ DIRECTIVE-DIRECTORY-COMPLETION_
import .ui
import .utils_ show to-kebab

/**
A completion candidate returned by completion callbacks.

Contains a $value and an optional $description. The $description is shown
  alongside the value in shells that support it (zsh, fish).
*/
class CompletionCandidate:
  /** The completion value. */
  value/string

  /**
  An optional description shown alongside the value.
  For example, if the value is a UUID, the description could be the
    human-readable name of the entity.
  */
  description/string?

  /**
  Creates a completion candidate with the given $value and optional $description.
  */
  constructor .value --.description=null:

/**
Context provided to completion callbacks.

Contains the prefix being completed, the option being completed, the
  current command, and the options that have already been seen.
*/
class CompletionContext:
  /**
  The text the user has typed so far for the value being completed.
  */
  prefix/string

  /**
  The option whose value is being completed.
  */
  option/Option

  /**
  The command that is currently being completed.
  */
  command/Command

  /**
  A map from option name to a list of values that have been provided
    for that option so far.

  Includes both named options and rest (positional) options. Rest options
    are keyed by their name, and their value list preserves the order of
    the positionals consumed. This lets a completion callback for a later
    rest argument condition its output on earlier rest values.
  */
  seen-options/Map

  constructor.private_ --.prefix --.option --.command --.seen-options:

/**
An option to a command.

Options are used for any input from the command line to the program. They must have unique names,
  so that they can be identified in the $Invocation output.

Non-rest options can be used with '--$name' or '-$short-name' (if provided). Rest options are positional
  and their name is not exposed to the user except for the help.
*/
abstract class Option:
  name/string
  short-name/string?
  help/string?
  is-required/bool
  is-hidden/bool
  is-multi/bool
  should-split-commas/bool
  completion-callback_/Lambda?

  /** Deprecated. Use '--help' instead of '--short-help'. */
  constructor name/string
      --default/string?=null
      --type/string="string"
      --short-name/string?=null
      --short-help/string
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false
      --split-commas/bool=false
      --completion/Lambda?=null:
    return OptionString name
        --default=default
        --type=type
        --short-name=short-name
        --help=short-help
        --required=required
        --hidden=hidden
        --multi=multi
        --split-commas=split-commas
        --completion=completion

  /** An alias for $OptionString. */
  constructor name/string
      --default/string?=null
      --type/string="string"
      --short-name/string?=null
      --help/string?=null
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false
      --split-commas/bool=false
      --completion/Lambda?=null:
    return OptionString name
        --default=default
        --type=type
        --short-name=short-name
        --help=help
        --required=required
        --hidden=hidden
        --multi=multi
        --split-commas=split-commas
        --completion=completion

  /** Deprecated. Use $help instead. */
  short-help -> string?: return help

  /**
  Creates an option with the given $name.

  This constructor is intended to be called from subclasses. Also see $Option.constructor
    which is an alias for the $OptionString constructor.

  The $name sets the name of the option. It must be unique among all options of a command.
    It is also used to extract the parsed value from the $Invocation object. For multi-word
    options kebab case ('foo-bar') is recommended. The constructor automatically converts
    snake case ('foo_bar') to kebab case. This also means, that it's not possible to
    have two options that only differ in their case (kebab and snake).

  The $short-name is optional and will normally be a single-character string when provided.

  The $help is optional and is used for help output. It should be a full sentence, starting
    with a capital letter and ending with a period.

  If $required is true, then the option must be provided. Otherwise, it is optional.

  If $hidden is true, then the option is not shown in help output. Rest arguments must not be
    hidden.

  If $multi is true, then the option can be provided multiple times. The parsed value will
    be a list of strings.

  If $split-commas is true, then $multi must be true too. Values given to this option are then
    split on commas. For example, `--option a,b,c` will result in the list `["a", "b", "c"]`.
  */
  constructor.from-subclass .name --.short-name --help/string? --required --hidden --multi --split-commas --completion/Lambda?=null:
    this.help = help
    name = to-kebab name
    is-required = required
    is-hidden = hidden
    is-multi = multi
    should-split-commas = split-commas
    completion-callback_ = completion
    if name.contains "=" or name.starts-with "no-": throw "Invalid option name: $name"
    if short-name and not is-alpha-num-string_ short-name:
      throw "Invalid short option name: '$short-name'"
    if split-commas and not multi:
      throw "--split-commas is only valid for multi options."
    if is-hidden and is-required:
      throw "Option can't be hidden and required."

  /** Deprecated. Use --help instead of '--short-help'. */
  constructor.from-subclass .name --.short-name --short-help/string --required --hidden --multi --split-commas --completion/Lambda?=null:
    help = short-help
    name = to-kebab name
    is-required = required
    is-hidden = hidden
    is-multi = multi
    should-split-commas = split-commas
    completion-callback_ = completion
    if name.contains "=" or name.starts-with "no-": throw "Invalid option name: $name"
    if short-name and not is-alpha-num-string_ short-name:
      throw "Invalid short option name: '$short-name'"
    if split-commas and not multi:
      throw "--split_commas is only valid for multi options."
    if is-hidden and is-required:
      throw "Option can't be hidden and required."

  static is-alpha-num-string_ str/string -> bool:
    if str.size < 1: return false
    str.do --runes: | c |
      if not ('a' <= c <= 'z' or 'A' <= c <= 'Z' or '0' <= c <= '9'):
        return false
    return true

  /**
  The default value of this option, as a string.

  This output is used in the help output.
  */
  default-as-string -> string?:
    default-value := default
    if default-value != null: return default-value.stringify
    return null

  /** The default value of this option. */
  abstract default -> any

  /** The type of the option. This property is only used in help output. */
  abstract type -> string

  /** Whether this option is a flag. */
  abstract is-flag -> bool

  /**
  Parses the given $str and returns the parsed value.

  Calls the $if-error block with an error message if parsing fails.

  If $for-help-example is true, only performs validation that is valid for examples.
    For example, a FileOption would not check that the file exists.
  */
  abstract parse str/string [--if-error] --for-help-example/bool=false -> any

  /**
  Returns the default completion candidates for this option.

  Subclasses override this to provide type-specific completions.
    For example, $OptionEnum returns its $OptionEnum.values list.
  */
  abstract options-for-completion -> List

  /**
  Returns the completion directive for this option, or null.

  If non-null, the completion engine uses this directive instead of computing
    one from the candidates. Subclasses like $OptionPath override this to
    request file or directory completion from the shell.
  */
  completion-directive -> int?:
    return null

  /**
  Returns file extensions to filter completions by, or null.

  When non-null, the shell only shows files matching these extensions
    (plus directories for navigation). Extensions include the leading
    dot, e.g. [".txt", ".json"].
  */
  completion-extensions -> List?:
    return null

  /**
  Returns completion candidates for this option's value.

  If a completion callback was provided via `--completion` in the constructor, it is
    called with the given $context and must return a list of $CompletionCandidate
    objects. Otherwise, the default completions from $options-for-completion are
    wrapped as candidates without descriptions.
  */
  complete context/CompletionContext -> List:
    if completion-callback_: return completion-callback_.call context
    return options-for-completion.map: CompletionCandidate it


/**
A string option.
*/
class OptionString extends Option:
  default/string?
  type/string

  /**
  Creates a new string option.

  The $default value is null.

  The $type is set to 'string', but can be changed to something else. The $type is
    only used for help output.

  See $Option.constructor for the other parameters.
  */
  constructor name/string
      --.default=null
      --.type="string"
      --short-name/string?=null
      --help/string?=null
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false
      --split-commas/bool=false
      --completion/Lambda?=null:
    if multi and default: throw "Multi option can't have default value."
    if required and default: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=help \
        --required=required --hidden=hidden --multi=multi \
        --split-commas=split-commas --completion=completion

  /** Deprecated. Use '--help' instead of '--short-help'. */
  constructor name/string
      --.default=null
      --.type="string"
      --short-name/string?=null
      --short-help/string?
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false
      --split-commas/bool=false
      --completion/Lambda?=null:
    if multi and default: throw "Multi option can't have default value."
    if required and default: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=short-help \
        --required=required --hidden=hidden --multi=multi \
        --split-commas=split-commas --completion=completion

  is-flag: return false

  options-for-completion -> List: return []

  parse str/string [--if-error] --for-help-example/bool=false -> string:
    return str

/**
An option that must be one of a set of $values.

The $parse function ensures that the value is one of the $values.
The $type defaults to a string enumerating the $values separated by '|'. For
  example `OptionEnum("color", ["red", "green", "blue"])` would have a type of
  "red|green|blue".
*/
class OptionEnum extends Option:
  default/string? := null
  values/List
  type/string

  /**
  Creates a new enum option.

  The $values list provides the list of valid values for this option.

  The $default value is null.
  The $type defaults to a string joining all $values with a '|'.

  See $Option.constructor for the other parameters.
  */
  constructor name/string .values/List
      --.default=null
      --.type=(values.join "|")
      --short-name/string?=null
      --help/string?=null
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false
      --split-commas/bool=false
      --completion/Lambda?=null:
    if multi and default: throw "Multi option can't have default value."
    if required and default: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=help \
        --required=required --hidden=hidden --multi=multi \
        --split-commas=split-commas --completion=completion
    if default and not values.contains default:
      throw "Default value of '$name' is not a valid value: $default"

  /** Deprecated. Use '--help' instead of '--short-help'. */
  constructor name/string .values/List
      --.default=null
      --.type=(values.join "|")
      --short-name/string?=null
      --short-help/string?
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false
      --split-commas/bool=false
      --completion/Lambda?=null:
    if multi and default: throw "Multi option can't have default value."
    if required and default: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=short-help \
        --required=required --hidden=hidden --multi=multi \
        --split-commas=split-commas --completion=completion
    if default and not values.contains default:
      throw "Default value of '$name' is not a valid value: $default"

  is-flag: return false

  options-for-completion -> List: return values

  parse str/string [--if-error] --for-help-example/bool=false -> string:
    if not values.contains str:
      return if-error.call "Invalid value for option '$name': '$str'. Valid values are: $(values.join ", ")."
    return str

/**
An option that must be an integer value.

The $parse function ensures that the value is an integer.
*/
class OptionInt extends Option:
  default/int?
  type/string

  /**
  Creates a new integer option.

  The $default value is null.
  The $type defaults to "int".

  See $Option.constructor for the other parameters.
  */
  constructor name/string
      --.default=null
      --.type="int"
      --short-name/string?=null
      --help/string?=null
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false
      --split-commas/bool=false
      --completion/Lambda?=null:
    if multi and default: throw "Multi option can't have default value."
    if required and default: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=help \
        --required=required --hidden=hidden --multi=multi \
        --split-commas=split-commas --completion=completion

  /** Deprecated. Use '--help' instead of '--short-help'. */
  constructor name/string
      --.default=null
      --.type="int"
      --short-name/string?=null
      --short-help/string?
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false
      --split-commas/bool=false
      --completion/Lambda?=null:
    if multi and default: throw "Multi option can't have default value."
    if required and default: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=short-help \
        --required=required --hidden=hidden --multi=multi \
        --split-commas=split-commas --completion=completion

  is-flag: return false

  options-for-completion -> List: return []

  parse str/string [--if-error] --for-help-example/bool=false -> int:
    return int.parse str --if-error=:
      return if-error.call "Invalid integer value for option '$name': '$str'."

/**
An option for patterns.

Patterns are an extension to enums: they allow to specify a prefix to a value.
For example, a pattern `"interval:<duration>"` would allow values like
  `"interval:1h"`, `"interval:30m"`, etc.

Both '=' and ':' are allowed as separators between the prefix and the value.
*/
class OptionPatterns extends Option:
  default/string?
  patterns/List
  type/string

  constructor name/string .patterns/List
      --.default=null
      --.type=(patterns.join "|")
      --short-name/string?=null
      --help/string?=null
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false
      --split-commas/bool=false
      --completion/Lambda?=null:
    if multi and default: throw "Multi option can't have default value."
    if required and default: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=help \
        --required=required --hidden=hidden --multi=multi \
        --split-commas=split-commas --completion=completion
    if default:
      parse_ default --if-error=:
        throw "Default value of '$name' is not a valid value: $default"

  is-flag -> bool: return false

  options-for-completion -> List: return patterns

  /**
  Returns the pattern that matches the given $str in a map with the pattern as key.
  */
  parse str/string [--if-error] --for-help-example/bool=false -> any:
    return parse_ str --if-error=:
      return if-error.call "Invalid value for option '$name': '$str'. Valid values are: $(patterns.join ", ")."

  parse_ str/string [--if-error]:
    if not str.contains ":" and not str.contains "=":
      if not patterns.contains str: if-error.call
      return str

    separator-index := str.index-of ":"
    if separator-index < 0: separator-index = str.index-of "="
    key := str[..separator-index]
    key-with-equals := "$key="
    key-with-colon := "$key:"
    if not (patterns.any: it.starts-with key-with-equals or it.starts-with key-with-colon):
      if-error.call

    return {
      key: str[separator-index + 1..]
    }

/**
A path option.

When completing, the shell will suggest file or directory paths depending
  on the $is-directory flag.
*/
class OptionPath extends Option:
  default/string?
  type/string

  /**
  Whether this option completes only directories.

  If true, the shell only suggests directories. If false, it suggests
    all files and directories.
  */
  is-directory/bool

  /**
  File extensions to filter completions by, or null.

  When non-null, the shell only shows files matching these extensions
    (plus directories for navigation). Extensions include the leading
    dot, e.g. [".txt", ".json"].
  */
  extensions/List?

  /**
  Creates a new path option.

  The $default value is null.
  The $type defaults to "path" for file paths or "directory" for directory paths.

  If $directory is true, the shell only completes directories.

  If $extensions is non-null, the shell only completes files matching
    the given extensions (plus directories for navigation). Extensions
    must include the leading dot, e.g. `[".txt", ".json"]`. Cannot be
    combined with $directory.

  See $Option.constructor for the other parameters.
  */
  constructor name/string
      --.default=null
      --directory/bool=false
      --.extensions/List?=null
      --.type=(directory ? "directory" : "path")
      --short-name/string?=null
      --help/string?=null
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false
      --split-commas/bool=false
      --completion/Lambda?=null:
    is-directory = directory
    if directory and extensions and not extensions.is-empty:
      throw "OptionPath can't have both --directory and --extensions."
    if multi and default: throw "Multi option can't have default value."
    if required and default: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=help \
        --required=required --hidden=hidden --multi=multi \
        --split-commas=split-commas --completion=completion

  is-flag: return false

  options-for-completion -> List: return []

  completion-directive -> int?:
    if is-directory: return DIRECTIVE-DIRECTORY-COMPLETION_
    return DIRECTIVE-FILE-COMPLETION_

  completion-extensions -> List?:
    return extensions

  parse str/string [--if-error] --for-help-example/bool=false -> string:
    return str

/**
An input file option.

The parsed value is an $InFile, which can be opened lazily.

If $allow-dash is true (the default), the value "-" is interpreted as
  stdin.

If $check-exists is true (the default), the file is checked for
  existence at parse time. This check is skipped for "-" (stdin).
*/
class OptionInFile extends Option:
  default/string?
  type/string

  /**
  Whether "-" is interpreted as stdin.
  */
  allow-dash/bool

  /**
  Whether the file is checked for existence at parse time.
  */
  check-exists/bool

  /**
  File extensions to filter completions by, or null.

  When non-null, the shell only shows files matching these extensions
    (plus directories for navigation). Extensions include the leading
    dot, e.g. [".txt", ".json"].
  */
  extensions/List?

  /**
  Creates a new input file option.

  The $default value is null.
  The $type defaults to "file".

  If $allow-dash is true (the default), the value "-" is interpreted
    as stdin.

  If $check-exists is true (the default), the file must exist at parse
    time. This check is skipped for "-" (stdin) and for help examples.

  If $extensions is non-null, the shell only completes files matching
    the given extensions (plus directories for navigation). Extensions
    must include the leading dot, e.g. `[".txt", ".json"]`.

  See $Option.constructor for the other parameters.
  */
  constructor name/string
      --.default=null
      --.type="file"
      --.allow-dash=true
      --.check-exists=true
      --.extensions/List?=null
      --short-name/string?=null
      --help/string?=null
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false
      --split-commas/bool=false
      --completion/Lambda?=null:
    if multi and default: throw "Multi option can't have default value."
    if required and default: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=help \
        --required=required --hidden=hidden --multi=multi \
        --split-commas=split-commas --completion=completion

  is-flag: return false

  options-for-completion -> List: return []

  completion-directive -> int?: return DIRECTIVE-FILE-COMPLETION_

  completion-extensions -> List?:
    return extensions

  parse str/string [--if-error] --for-help-example/bool=false -> any:
    if allow-dash and str == "-":
      return InFile.stdin_ --option-name=name
    result := InFile.from-path_ str --option-name=name
    if check-exists and not for-help-example:
      result.check --if-error=if-error
    return result

/**
An output file option.

The parsed value is an $OutFile, which can be opened lazily.

If $allow-dash is true (the default), the value "-" is interpreted as
  stdout.

If $create-directories is true, parent directories are created
  automatically when opening the file for writing.
*/
class OptionOutFile extends Option:
  default/string?
  type/string

  /**
  Whether "-" is interpreted as stdout.
  */
  allow-dash/bool

  /**
  Whether parent directories are created when opening for writing.
  */
  create-directories/bool

  /**
  File extensions to filter completions by, or null.

  When non-null, the shell only shows files matching these extensions
    (plus directories for navigation). Extensions include the leading
    dot, e.g. [".txt", ".json"].
  */
  extensions/List?

  /**
  Creates a new output file option.

  The $default value is null.
  The $type defaults to "file".

  If $allow-dash is true (the default), the value "-" is interpreted
    as stdout.

  If $create-directories is true, parent directories are created
    automatically when opening the file for writing. Defaults to false.

  If $extensions is non-null, the shell only completes files matching
    the given extensions (plus directories for navigation). Extensions
    must include the leading dot, e.g. `[".txt", ".json"]`.

  See $Option.constructor for the other parameters.
  */
  constructor name/string
      --.default=null
      --.type="file"
      --.allow-dash=true
      --.create-directories=false
      --.extensions/List?=null
      --short-name/string?=null
      --help/string?=null
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false
      --split-commas/bool=false
      --completion/Lambda?=null:
    if multi and default: throw "Multi option can't have default value."
    if required and default: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=help \
        --required=required --hidden=hidden --multi=multi \
        --split-commas=split-commas --completion=completion

  is-flag: return false

  options-for-completion -> List: return []

  completion-directive -> int?: return DIRECTIVE-FILE-COMPLETION_

  completion-extensions -> List?:
    return extensions

  parse str/string [--if-error] --for-help-example/bool=false -> any:
    if allow-dash and str == "-":
      return OutFile.stdout_ --create-directories=create-directories --option-name=name
    return OutFile.from-path_ str --create-directories=create-directories --option-name=name

/**
A wrapper around an input file or stdin.

Returned by $OptionInFile when parsing command-line arguments.

Use $open or $do to read from the file or stdin.
*/
class InFile:
  /** The file path, or null if this represents stdin. */
  path/string?

  /**
  Whether this $InFile represents stdin.
  */
  is-stdin/bool

  /**
  The option name, used in error messages.
  */
  option-name/string

  constructor.from-path_ .path/string --.option-name:
    is-stdin = false

  constructor.stdin_ --.option-name:
    path = null
    is-stdin = true

  /**
  Checks that the file exists.

  Throws if the file does not exist. Does nothing for stdin.
  */
  check -> none:
    check --if-error=: throw it

  /**
  Checks that the file exists.

  Calls the $if-error block with an error message if the file does not exist.
  Does nothing for stdin.
  */
  check [--if-error] -> none:
    if is-stdin: return
    if not file.is-file path:
      if-error.call "File not found for option '$option-name': '$path'."

  /**
  Checks that the file exists.

  Calls $Ui.abort with the error message if the file does not exist.
  Does nothing for stdin.
  */
  check --ui/Ui -> none:
    check --if-error=: ui.abort it

  /**
  Opens the file (or stdin) for reading.

  The caller is responsible for closing the returned reader.
  */
  open -> io.CloseableReader:
    if is-stdin: return pipe.stdin.in
    return (file.Stream.for-read path).in

  /**
  Opens the file (or stdin) for reading, calls the given $block
    with the reader, and closes the reader afterwards.
  */
  do [block] -> none:
    reader := open
    try:
      block.call reader
    finally:
      reader.close

  /**
  Reads the entire content of the file or stdin.
  */
  read-contents -> ByteArray:
    if not is-stdin: return file.read-contents path
    reader := pipe.stdin.in
    try:
      return reader.read-all
    finally:
      reader.close

/**
A wrapper around an output file or stdout.

Returned by $OptionOutFile when parsing command-line arguments.

Use $open or $do to write to the file or stdout.
*/
class OutFile:
  /** The file path, or null if this represents stdout. */
  path/string?

  create-directories_/bool

  /**
  Whether this $OutFile represents stdout.
  */
  is-stdout/bool

  /**
  The option name, used in error messages.
  */
  option-name/string

  constructor.from-path_ .path/string --create-directories/bool --.option-name:
    create-directories_ = create-directories
    is-stdout = false

  constructor.stdout_ --create-directories/bool --.option-name:
    path = null
    create-directories_ = create-directories
    is-stdout = true

  /**
  Opens the file (or stdout) for writing.

  If $OptionOutFile.create-directories was set, parent directories are
    created automatically.

  The caller is responsible for closing the returned writer.
  */
  open -> io.CloseableWriter:
    if is-stdout: return pipe.stdout.out
    if create-directories_:
      directory.mkdir --recursive (fs.dirname path)
    return (file.Stream.for-write path).out

  /**
  Opens the file (or stdout) for writing, calls the given $block
    with the writer, and closes the writer afterwards.
  */
  do [block] -> none:
    writer := open
    try:
      block.call writer
    finally:
      writer.close

  /**
  Writes the given $data to the file or stdout.

  If $OptionOutFile.create-directories was set, parent directories are
    created automatically.
  */
  write-contents data/io.Data -> none:
    if not is-stdout:
      if create-directories_:
        directory.mkdir --recursive (fs.dirname path)
      file.write-contents --path=path data
      return
    writer := pipe.stdout.out
    try:
      writer.write data
    finally:
      writer.close

/**
A Uuid option.
*/
class OptionUuid extends Option:
  default/Uuid?

  /**
  Creates a new Uuid option.

  The $default value is null.

  The $type is set to 'uuid'.

  Ensures that values are valid Uuids.
  */
  constructor name/string
      --.default=null
      --short-name/string?=null
      --help/string?=null
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false
      --split-commas/bool=false
      --completion/Lambda?=null:
    if multi and default: throw "Multi option can't have default value."
    if required and default: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=help \
        --required=required --hidden=hidden --multi=multi \
        --split-commas=split-commas --completion=completion

  is-flag: return false

  options-for-completion -> List: return []

  type -> string: return "uuid"

  parse str/string [--if-error] --for-help-example/bool=false -> Uuid:
    return Uuid.parse str --if-error=:
      return if-error.call "Invalid value for option '$name': '$str'. Expected a UUID."


/**
An option that must be a boolean value.

Flags are handled specially by the parser, as they don't have a value.
The parser also allows to invert flags by prefixing them with '--no-'.

The type of a flag is written as "true|false", but the help only uses this
  type when a flag is used as a rest argument.
*/
class Flag extends Option:
  default/bool?

  /**
  Creates a new flag.

  The $default value is null.
  The $type is only visible when using this option as a rest argument and is then "true|false"

  See $Option.constructor for the other parameters.
  */
  constructor name/string
      --.default=null
      --short-name/string?=null
      --help/string?=null
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false
      --completion/Lambda?=null:
    if multi and default != null: throw "Multi option can't have default value."
    if required and default != null: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=help \
        --required=required --hidden=hidden --multi=multi --no-split-commas \
        --completion=completion

  /** Deprecated. Use '--help' instead of '--short-help'. */
  constructor name/string
      --.default=null
      --short-name/string?=null
      --short-help/string?
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false
      --completion/Lambda?=null:
    if multi and default != null: throw "Multi option can't have default value."
    if required and default != null: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=short-help \
        --required=required --hidden=hidden --multi=multi --no-split-commas \
        --completion=completion

  type -> string:
    return "true|false"

  is-flag: return true

  options-for-completion -> List: return ["true", "false"]

  parse str/string [--if-error] --for-help-example/bool=false -> bool:
    if str == "true": return true
    if str == "false": return false
    return if-error.call "Invalid value for boolean flag '$name': '$str'. Valid values are: true, false."
