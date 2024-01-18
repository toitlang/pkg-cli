// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import uuid
import system

import .cache
import .config
import .parser_
import .utils_
import .help-generator_
import .ui

export Ui

/**
An object giving access to common operations for CLI programs.
*/
class Application:
  /**
  The name of the application.

  Used to find configurations and caches.
  */
  name/string

  cache_/Cache? := null
  config_/Config? := null

  ui/Ui

  constructor.private_ .name --.ui:

  cache -> Cache:
    if not cache_: cache_ = Cache --app-name=name
    return cache_

  config -> Config:
    if not config_: config_ = Config --app-name=name
    return config_

/**
A command.

The main program is a command, and so are all subcommands.
*/
class Command:
  /**
  The name of the command.
  The name of the root command is used as application name for the $Application.
  */
  name/string

  /**
  The usage string of this command.
  Usually constructed from the name and the arguments of the command. However, in
    some cases, a different (shorter) usage string is desired.
  */
  usage_/string?

  /** A short (one line) description of the command. */
  short-help_/string?

  /** A longer description of the command. */
  help_/string?

  /** Examples of the command. */
  examples_/List

  /** Aliases of the command. */
  aliases_/List

  /** Options to the command. */
  options_/List := ?

  /** The rest arguments. */
  rest_/List

  /** Whether this command should show up in the help. */
  is-hidden_/bool

  /**
  Subcommands.
  Use $add to add new subcommands.
  */
  subcommands_/List

  /**
  The function to invoke when this command is executed.
  May be null, in which case at least one subcommand must be specified.
  */
  run-callback_/Lambda?

  /**
  Constructs a new command.

  The $name is only optional for the root command, which represents the program. All
    subcommands must have a name.

  The $usage is usually constructed from the name and the arguments of the command, but can
    be provided explicitly if a different usage string is desired.

  The $help is a longer description of the command that can span multiple lines. Use
    indented lines to continue paragraphs (just like toitdoc). The first paragraph of the
    $help is used as short help, and should have meaningful content on its own.

  The $run callback is invoked when the command is executed. It is given the $Application and the
    $Parsed object. If $run is null, then at least one subcommand must be added to this
    command.
  */
  constructor name --usage/string?=null --help/string?=null --examples/List=[] \
      --aliases/List=[] --options/List=[] --rest/List=[] --subcommands/List=[] --hidden/bool=false \
      --run/Lambda?=null:
    return Command.private name --usage=usage --help=help --examples=examples \
        --aliases=aliases --options=options --rest=rest --subcommands=subcommands --hidden=hidden \
        --run=run

  /**
  Deprecated. Use '--help' instead of '--short-help'.
  */
  constructor name --usage/string?=null --short-help/string --examples/List=[] \
      --aliases/List=[] --options/List=[] --rest/List=[] --subcommands/List=[] --hidden/bool=false \
      --run/Lambda?=null:
    return Command.private name --usage=usage --short-help=short-help --examples=examples \
        --aliases=aliases --options=options --rest=rest --subcommands=subcommands --hidden=hidden \
        --run=run

  /**
  Deprecated. Use '--help' instead of '--long-help'.
  */
  constructor name --usage/string?=null --long-help/string --examples/List=[] \
      --aliases/List=[] --options/List=[] --rest/List=[] --subcommands/List=[] --hidden/bool=false \
      --run/Lambda?=null:
    return Command.private name --usage=usage --help=long-help --examples=examples \
        --aliases=aliases --options=options --rest=rest --subcommands=subcommands --hidden=hidden \
        --run=run

  /**
  Deprecated. Use '--help' with a meaningful first paragraph instead of '--short-help' and '--long-help'.
  */
  constructor name --usage/string?=null --short-help/string --long-help/string --examples/List=[] \
      --aliases/List=[] --options/List=[] --rest/List=[] --subcommands/List=[] --hidden/bool=false \
      --run/Lambda?=null:
    return Command.private name --usage=usage --short-help=short-help --help=long-help --examples=examples \
        --aliases=aliases --options=options --rest=rest --subcommands=subcommands --hidden=hidden \
        --run=run

  constructor.private .name --usage/string?=null --short-help/string?=null --help/string?=null --examples/List=[] \
      --aliases/List=[] --options/List=[] --rest/List=[] --subcommands/List=[] --hidden/bool=false \
      --run/Lambda?=null:
    usage_ = usage
    short-help_ = short-help
    help_ = help
    examples_ = examples
    aliases_ = aliases
    options_ = options
    rest_ = rest
    subcommands_ = subcommands
    run-callback_ = run
    is-hidden_ = hidden
    if not subcommands.is-empty and not rest.is-empty:
      throw "Cannot have both subcommands and rest arguments."
    if run and not subcommands.is-empty:
      throw "Cannot have both a run callback and subcommands."

  hash-code -> int:
    return name.hash-code

  /**
  Adds a subcommand to this command.

  Subcommands can also be provided in the constructor.

  It is an error to add a subcommand to a command that has rest arguments.
  It is an error to add a subcommand to a command that has a run callback.
  */
  add command/Command:
    if not rest_.is-empty:
      throw "Cannot add subcommands to a command with rest arguments."
    if run-callback_:
      throw "Cannot add subcommands to a command with a run callback."
    subcommands_.add command

  /** Returns the help string of this command. */
  help --invoked-command/string=system.program-name -> string:
    generator := HelpGenerator [this] --invoked-command=invoked-command
    generator.build-all
    return generator.to-string

  /** Returns the usage string of this command. */
  usage --invoked-command/string=system.program-name -> string:
    generator := HelpGenerator [this] --invoked-command=invoked-command
    generator.build-usage --as-section=false
    return generator.to-string

  /**
  Runs this command.

  Parses the given $arguments and then invokes the command or one of its subcommands
    with the $Parsed output.

  The $invoked-command is used only for the usage message in case of an
    error. It defaults to $system.program-name.

  If no UI is given, the arguments are parsed for `--verbose`, `--verbosity-level` and
    `--output-format` to create the appropriate UI object. If a $ui is given, then these
    arguments are ignored.

  The $add-ui-help flag is used to determine whether to include help for `--verbose`, ...
    in the help output. By default it is active if no $ui is provided.
  */
  run arguments/List --invoked-command=system.program-name --ui/Ui?=null --add-ui-help/bool=(not ui) -> none:
    if not ui: ui = create-ui-from-args_ arguments
    if add-ui-help:
      add-ui-options_
    app := Application.private_ name --ui=ui
    parser := Parser_ --invoked-command=invoked-command
    parsed := parser.parse this arguments
    parsed.command.run-callback_.call app parsed

  add-ui-options_:
    has-output-format-option := false
    has-verbose-flag := false
    has-verbosity-level-option := false

    options_.do: | option/Option |
      if option.name == "output-format": has-output-format-option = true
      if option.name == "verbose": has-verbose-flag = true
      if option.name == "verbosity-level": has-verbosity-level-option = true

    is-copied := false
    if not has-output-format-option:
      options_ = options_.copy
      is-copied = true
      option := OptionEnum "output-format"
        ["text", "json"]
        --help="Specify the format used when printing to the console."
        --default="text"
      options_.add option
    if not has-verbose-flag:
      if not is-copied:
        options_ = options_.copy
        is-copied = true
      option := Flag "verbose"
        --help="Enable verbose output. Shorthand for --verbosity-level=verbose."
        --default=false
      options_.add option
    if not has-verbosity-level-option:
      if not is-copied:
        options_ = options_.copy
        is-copied = true
      option := OptionEnum "verbosity-level"
        ["debug", "info", "verbose", "quiet", "silent"]
        --help="Specify the verbosity level."
        --default="info"
      options_.add option

  /**
  Checks this command and all subcommands for errors.
  */
  check --invoked-command=system.program-name:
    check_ --path=[invoked-command]

  are-prefix-of-each-other_ str1/string str2/string -> bool:
    m := min str1.size str2.size
    return str1[..m] == str2[..m]

  /**
  Checks this command and all subcommands.
  The $path, a list of strings, provides the sequence that was used to reach this command.
  The $outer-long-options and $outer-short-options are the options that are
    available through supercommands.
  */
  check_ --path/List --outer-long-options/Set={} --outer-short-options/Set={}:
    examples_.do: it as Example
    aliases_.do: it as string

    long-options := {}
    short-options := {}
    options_.do: | option/Option |
      if long-options.contains option.name:
        throw "Ambiguous option of '$(path.join " ")': --$option.name."
      if outer-long-options.contains option.name:
        throw "Ambiguous option of '$(path.join " ")': --$option.name conflicts with global option."
      long-options.add option.name

      if option.short-name:
        if (short-options.any: are-prefix-of-each-other_ it option.short-name):
          throw "Ambiguous option of '$(path.join " ")': -$option.short-name."
        if (outer-short-options.any: are-prefix-of-each-other_ it option.short-name):
          throw "Ambiguous option of '$(path.join " ")': -$option.short-name conflicts with global option."
        short-options.add option.short-name

    have-seen-optional-rest := false
    for i := 0; i < rest_.size; i++:
      option/Option := rest_[i]
      if option.is-multi and not i == rest_.size - 1:
        throw "Multi-option '$option.name' of '$(path.join " ")' must be the last rest argument."
      if long-options.contains option.name:
        throw "Rest name '$option.name' of '$(path.join " ")' already used."
      if outer-long-options.contains option.name:
        throw "Rest name '$option.name' of '$(path.join " ")' already a global option."
      if have-seen-optional-rest and option.is-required:
        throw "Required rest argument '$option.name' of '$(path.join " ")' cannot follow optional rest argument."
      if option.is-hidden:
        throw "Rest argument '$option.name' of '$(path.join " ")' cannot be hidden."
      have-seen-optional-rest = not option.is-required
      long-options.add option.name

    if not long-options.is-empty:
      // Make a copy first.
      outer-long-options = outer-long-options.map: it
      outer-long-options.add-all long-options
    if not short-options.is-empty:
      // Make a copy first.
      outer-short-options = outer-short-options.map: it
      outer-short-options.add-all short-options

    subnames := {}
    subcommands_.do: | command/Command |
      names := [command.name] + command.aliases_
      names.do: | name/string? |
        if subnames.contains name:
          throw "Ambiguous subcommand of '$(path.join " ")': '$name'."
        subnames.add name

      command.check_ --path=(path + [command.name])
          --outer-long-options=outer-long-options
          --outer-short-options=outer-short-options

    // We allow a command with a run callback if all subcommands are hidden.
    // As such, we could also allow commands without either. If desired, it should be
    // safe to remove the following check.
    if subcommands_.is-empty and not run-callback_:
      throw "Command '$(path.join " ")' has no subcommands and no run callback."

  find-subcommand_ name/string -> Command?:
    subcommands_.do: | command/Command |
      if command.name == name or command.aliases_.contains name:
        return command
    return null

/**
An option to a command.

Options are used for any input from the command line to the program. They must have unique names,
  so that they can be identified in the $Parsed output.

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

  /** Deprecated. Use '--help' instead of '--short-help'. */
  constructor name/string
      --default/string?=null
      --type/string="string"
      --short-name/string?=null
      --short-help/string
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false
      --split-commas/bool=false:
    return OptionString name
        --default=default
        --type=type
        --short-name=short-name
        --help=short-help
        --required=required
        --hidden=hidden
        --multi=multi
        --split-commas=split-commas

  /** An alias for $OptionString. */
  constructor name/string
      --default/string?=null
      --type/string="string"
      --short-name/string?=null
      --help/string?=null
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false
      --split-commas/bool=false:
    return OptionString name
        --default=default
        --type=type
        --short-name=short-name
        --help=help
        --required=required
        --hidden=hidden
        --multi=multi
        --split-commas=split-commas

  /** Deprecated. Use $help instead. */
  short-help -> string?: return help

  /**
  Creates an option with the given $name.

  This constructor is intended to be called from subclasses. Also see $Option.constructor
    which is an alias for the $OptionString constructor.

  The $name sets the name of the option. It must be unique among all options of a command.
    It is also used to extract the parsed value from the $Parsed object. For multi-word
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
  constructor.from-subclass .name --.short-name --help/string? --required --hidden --multi --split-commas:
    this.help = help
    name = to-kebab name
    is-required = required
    is-hidden = hidden
    is-multi = multi
    should-split-commas = split-commas
    if name.contains "=" or name.starts-with "no-": throw "Invalid option name: $name"
    if short-name and not is-alpha-num-string_ short-name:
      throw "Invalid short option name: '$short-name'"
    if split-commas and not multi:
      throw "--split-commas is only valid for multi options."
    if is-hidden and is-required:
      throw "Option can't be hidden and required."

  /** Deprecated. Use --help instead of '--short-help'. */
  constructor.from-subclass .name --.short-name --short-help/string --required --hidden --multi --split-commas:
    help = short-help
    name = to-kebab name
    is-required = required
    is-hidden = hidden
    is-multi = multi
    should-split-commas = split-commas
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
        print c
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

  If $for-help-example is true, only performs validation that is valid for examples.
    For example, a FileOption would not check that the file exists.
  */
  abstract parse str/string --for-help-example/bool=false -> any


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
      --split-commas/bool=false:
    if multi and default: throw "Multi option can't have default value."
    if required and default: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=help \
        --required=required --hidden=hidden --multi=multi \
        --split-commas=split-commas

  /** Deprecated. Use '--help' instead of '--short-help'. */
  constructor name/string
      --.default=null
      --.type="string"
      --short-name/string?=null
      --short-help/string?
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false
      --split-commas/bool=false:
    if multi and default: throw "Multi option can't have default value."
    if required and default: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=short-help \
        --required=required --hidden=hidden --multi=multi \
        --split-commas=split-commas

  is-flag: return false

  parse str/string --for-help-example/bool=false -> string:
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
      --split-commas/bool=false:
    if multi and default: throw "Multi option can't have default value."
    if required and default: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=help \
        --required=required --hidden=hidden --multi=multi \
        --split-commas=split-commas
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
      --split-commas/bool=false:
    if multi and default: throw "Multi option can't have default value."
    if required and default: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=short-help \
        --required=required --hidden=hidden --multi=multi \
        --split-commas=split-commas
    if default and not values.contains default:
      throw "Default value of '$name' is not a valid value: $default"

  is-flag: return false

  parse str/string --for-help-example/bool=false -> string:
    if not values.contains str:
      throw "Invalid value for option '$name': '$str'. Valid values are: $(values.join ", ")."
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
      --split-commas/bool=false:
    if multi and default: throw "Multi option can't have default value."
    if required and default: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=help \
        --required=required --hidden=hidden --multi=multi \
        --split-commas=split-commas

  /** Deprecated. Use '--help' instead of '--short-help'. */
  constructor name/string
      --.default=null
      --.type="int"
      --short-name/string?=null
      --short-help/string?
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false
      --split-commas/bool=false:
    if multi and default: throw "Multi option can't have default value."
    if required and default: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=short-help \
        --required=required --hidden=hidden --multi=multi \
        --split-commas=split-commas

  is-flag: return false

  parse str/string --for-help-example/bool=false -> int:
    return int.parse str --on-error=:
      throw "Invalid integer value for option '$name': '$str'."

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
      --split-commas/bool=false:
    if multi and default: throw "Multi option can't have default value."
    if required and default: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=help \
        --required=required --hidden=hidden --multi=multi \
        --split-commas=split-commas
    if default:
      parse_ default --on-error=:
        throw "Default value of '$name' is not a valid value: $default"

  is-flag -> bool: return false

  /**
  Returns the pattern that matches the given $str in a map with the pattern as key.
  */
  parse str/string --for-help-example/bool=false -> any:
    return parse_ str --on-error=:
      throw "Invalid value for option '$name': '$str'. Valid values are: $(patterns.join ", ")."

  parse_ str/string [--on-error]:
    if not str.contains ":" and not str.contains "=":
      if not patterns.contains str: on-error.call
      return str

    separator-index := str.index-of ":"
    if separator-index < 0: separator-index = str.index-of "="
    key := str[..separator-index]
    key-with-equals := "$key="
    key-with-colon := "$key:"
    if not (patterns.any: it.starts-with key-with-equals or it.starts-with key-with-colon):
      on-error.call

    return {
      key: str[separator-index + 1..]
    }

/**
A Uuid option.
*/
class OptionUuid extends Option:
  default/uuid.Uuid?

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
      --split-commas/bool=false:
    if multi and default: throw "Multi option can't have default value."
    if required and default: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=help \
        --required=required --hidden=hidden --multi=multi \
        --split-commas=split-commas

  is-flag: return false

  type -> string: return "uuid"

  parse str/string --for-help-example/bool=false -> uuid.Uuid:
    return uuid.parse str --on-error=:
      throw "Invalid value for option '$name': '$str'. Expected a UUID."


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
      --multi/bool=false:
    if multi and default != null: throw "Multi option can't have default value."
    if required and default != null: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=help \
        --required=required --hidden=hidden --multi=multi --no-split-commas

  /** Deprecated. Use '--help' instead of '--short-help'. */
  constructor name/string
      --.default=null
      --short-name/string?=null
      --short-help/string?
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false:
    if multi and default != null: throw "Multi option can't have default value."
    if required and default != null: throw "Option can't have default value and be required."
    super.from-subclass name --short-name=short-name --help=short-help \
        --required=required --hidden=hidden --multi=multi --no-split-commas

  type -> string:
    return "true|false"

  is-flag: return true

  parse str/string --for-help-example/bool=false -> bool:
    if str == "true": return true
    if str == "false": return false
    throw "Invalid value for boolean flag '$name': '$str'. Valid values are: true, false."

/**
An example.

Examples are parsed and must be valid. They are used to generate the help.
*/
class Example:
  description/string
  arguments/string
  global-priority/int

  /**
  Creates an example.

  The $description should describe the example without any context. This is especially true
    if the $global-priority is greater than 0 (see below). It should start with a capital
    letter and finish with a ":". It may contain newlines. Use indentation to group
    paragraphs (just like toitdoc).

  The $arguments is a string containing the arguments to this command (or to super commands).
    The help generator parses the arguments and assigns all options to the corresponding commands.

  The $arguments should not contain the path up to this command. For example, if we want to
    document the command `foo bar baz --gee` and are writing the example for the command `baz`, then
    $arguments should be equal to `--gee`. If the example is for the command `bar`, then $arguments
    should be equal to `baz --gee`.

  The $global-priority is used to sort the examples of sub commands. Examples with a higher priority
    are shown first. Examples with the same priority are sorted in the order in which they are
    encountered.

  The $global-priority must be in the range 0 to 10 (both inclusive). The default value is 0.

  If the $global-priority is 0, then it is not used as example for super commands.
  */
  constructor .description --.arguments --.global-priority=0:
    if not 0 <= global-priority <= 10: throw "INVALID_ARGUMENT"

/**
The result of parsing the command line arguments.

An instance of this class is given to the command's `run` method.
*/
class Parsed:
  /**
  A list of $Command objects, representing the commands that were given on the command line.
  The first command is the root command, the last command is the command that should be executed.
  */
  path/List

  /**
  The parsed options.
  All options, including flags and rest arguments, are stored in this map.
  */
  options_/Map

  /**
  The set of options that were given on the command line.
  Contrary to the $options_ map, this set only contains options that were actually given, and
    not filled in by default values.
  */
  seen-options_/Set

  /**
  Builds a new $Parsed object.
  */
  constructor.private_ .path .options_ .seen-options_:

  /**
  The command that should be executed.
  */
  command -> Command: return path.last

  /**
  Returns the value of the option with the given $name.
  The $name must be an option of the command or one of its super commands.

  If the given $name is in snake_case, it is automatically converted
    to kebab-case.
  */
  operator[] name/string -> any:
    kebab-name := to-kebab name
    return options_.get kebab-name --if-absent=: throw "No option named '$name'"

  /**
  Whether an option with the given $name was given on the command line.
  */
  was-provided name/string -> bool:
    return seen-options_.contains name

  stringify:
    buffer := []
    options_.do: | name value | buffer.add "$name=$value"
    return buffer.join " "
