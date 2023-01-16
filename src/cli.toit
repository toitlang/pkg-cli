// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import .parser_
import .utils_

/**
When the arg-parser needs to report an error, or write a help message, it
  uses this interface.

The $abort function either calls $exit or throws an exception.
*/
interface Ui:
  print str/string
  abort -> none

/**
A command.

The main program is a command, and so are all subcommands.
*/
class Command:
  /**
  The name of the command.
  The name of the root command is usually ignored (and replaced by the executable name).
  */
  name/string

  /**
  The usage string of this command.
  Usually constructed from the name and the arguments of the command. However, in
    some cases, a different (shorter) usage string is desired.
  */
  usage/string?

  /** A short (one line) description of the command. */
  short_help/string?

  /** A longer description of the command. */
  long_help/string?

  /** Examples of the command. */
  examples/List

  /** Aliases of the command. */
  aliases/List

  /** Options to the command. */
  options/List

  /** The rest arguments. */
  rest/List

  /** Whether this command should show up in the help. */
  is_hidden/bool

  /**
  Subcommands.
  Use $add to add new subcommands.
  */
  subcommands/List

  /**
  The function to invoke when this command is executed.
  May be null, in which case at least one subcommand must be specified.
  */
  run_callback/Lambda?

  /**
  Constructs a new command.

  The $name is only optional for the root command, which represents the program. All
    subcommands must have a name.

  The $usage is usually constructed from the name and the arguments of the command, but can
    be provided explicitly if a different usage string is desired.

  The $long_help is a longer description of the command that can span multiple lines. Use
    indented lines to continue paragraphs (just like toitdoc).

  The $short_help is a short description of the command. In most cases this help is a single
    line, but it can span multiple lines/paragraphs if necessary. Use indented lines to
    continue paragraphs (just like toitdoc).
  */
  constructor .name --.usage=null --.short_help=null --.long_help=null --.examples=[] \
      --.aliases=[] --.options=[] --.rest=[] --.subcommands=[] --hidden/bool=false \
      --run/Lambda?=null:
    run_callback = run
    is_hidden = hidden
    if not subcommands.is_empty and not rest.is_empty:
      throw "Cannot have both subcommands and rest arguments."
    if run and not subcommands.is_empty:
      throw "Cannot have both a run callback and subcommands."

  hash_code -> int:
    return name.hash_code

  /**
  Adds a subcommand to this command.

  Subcommands can also be provided in the constructor.

  It is an error to add a subcommand to a command that has rest arguments.
  It is an error to add a subcommand to a command that has a run callback.
  */
  add command/Command:
    if not rest.is_empty:
      throw "Cannot add subcommands to a command with rest arguments."
    if run_callback:
      throw "Cannot add subcommands to a command with a run callback."
    subcommands.add command

  /**
  Runs this command.

  Parses the given $arguments and then invokes the command or one of its subcommands
    with the $Parsed output.

  The $invoked_command is used only for the usage message in case of an
    error. It defaults to $program_name.

  The default $ui prints to stdout and calls `exit 1` when $Ui.abort is called.
  */
  run arguments/List --invoked_command=program_name --ui/Ui=Ui_ -> none:
    parser := Parser_ --ui=ui --invoked_command=invoked_command
    parsed := parser.parse this arguments
    parsed.command.run_callback.call parsed

  /**
  Checks this command and all subcommands for errors.
  */
  check --invoked_command=program_name:
    check_ --path=[invoked_command]

  are_prefix_of_each_other_ str1/string str2/string -> bool:
    m := min str1.size str2.size
    return str1[..m] == str2[..m]

  /**
  Checks this command and all subcommands.
  The $path, a list of strings, provides the sequence that was used to reach this command.
  The $outer_long_options and $outer_short_options are the options that are
    available through supercommands.
  */
  check_ --path/List --outer_long_options/Set={} --outer_short_options/Set={}:
    examples.do: it as Example
    aliases.do: it as string

    long_options := {}
    short_options := {}
    options.do: | option/Option |
      if long_options.contains option.name:
        throw "Ambiguous option of '$(path.join " ")': --$option.name."
      if outer_long_options.contains option.name:
        throw "Ambiguous option of '$(path.join " ")': --$option.name conflicts with global option."
      long_options.add option.name

      if option.short_name:
        if (short_options.any: are_prefix_of_each_other_ it option.short_name):
          throw "Ambiguous option of '$(path.join " ")': -$option.short_name."
        if (outer_short_options.any: are_prefix_of_each_other_ it option.short_name):
          throw "Ambiguous option of '$(path.join " ")': -$option.short_name conflicts with global option."
        short_options.add option.short_name

    have_seen_optional_rest := false
    for i := 0; i < rest.size; i++:
      option/Option := rest[i]
      if option.is_multi and not i == rest.size - 1:
        throw "Multi-option '$option.name' of '$(path.join " ")' must be the last rest argument."
      if long_options.contains option.name:
        throw "Rest name '$option.name' of '$(path.join " ")' already used."
      if outer_long_options.contains option.name:
        throw "Rest name '$option.name' of '$(path.join " ")' already a global option."
      if have_seen_optional_rest and option.is_required:
        throw "Required rest argument '$option.name' of '$(path.join " ")' cannot follow optional rest argument."
      if option.is_hidden:
        throw "Rest argument '$option.name' of '$(path.join " ")' cannot be hidden."
      have_seen_optional_rest = not option.is_required
      long_options.add option.name

    if not long_options.is_empty:
      // Make a copy first.
      outer_long_options = outer_long_options.map: it
      outer_long_options.add_all long_options
    if not short_options.is_empty:
      // Make a copy first.
      outer_short_options = outer_short_options.map: it
      outer_short_options.add_all short_options

    subnames := {}
    subcommands.do: | command/Command |
      names := [command.name] + command.aliases
      names.do: | name/string? |
        if subnames.contains name:
          throw "Ambiguous subcommand of '$(path.join " ")': '$name'."
        subnames.add name

      command.check_ --path=(path + [command.name])
          --outer_long_options=outer_long_options
          --outer_short_options=outer_short_options

    // We allow a command with a run callback if all subcommands are hidden.
    // As such, we could also allow commands without either. If desired, it should be
    // safe to remove the following check.
    if subcommands.is_empty and not run_callback:
      throw "Command '$(path.join " ")' has no subcommands and no run callback."

  find_subcommand_ name/string -> Command?:
    subcommands.do: | command/Command |
      if command.name == name or command.aliases.contains name:
        return command
    return null

/**
An option to a command.

Options are used for any input from the command line to the program. They must have unique names,
  so that they can be identified in the $Parsed output.

Non-rest options can be used with '--$name' or '-$short_name' (if provided). Rest options are positional
  and their name is not exposed to the user except for the help.
*/
abstract class Option:
  name/string
  short_name/string?
  short_help/string?
  is_required/bool
  is_hidden/bool
  is_multi/bool
  should_split_commas/bool

  /**
  Creates an option with the given $name.

  The $name sets the name of the option. It must be unique among all options of a command.
    It is also used to extract the parsed value from the $Parsed object. For multi-word
    options kebab case ('foo-bar') is recommended. The constructor automatically converts
    snake case ('foo_bar') to kebab case. This also means, that it's not possible to
    have two options that only differ in their case (kebab and snake).

  The $short_name is optional and will normally be a single-character string when provided.

  The $short_help is optional and is used for help output. It should be a full sentence, starting
    with a capital letter and ending with a period.

  If $required is true, then the option must be provided. Otherwise, it is optional.

  If $hidden is true, then the option is not shown in help output. Rest arguments must not be
    hidden.

  If $multi is true, then the option can be provided multiple times. The parsed value will
    be a list of strings.

  If $split_commas is true, then $multi must be true too. Values given to this option are then
    split on commas. For example, `--option a,b,c` will result in the list `["a", "b", "c"]`.

  */
  constructor .name --.short_name --.short_help --required --hidden --multi --split_commas:
    name = to_kebab name
    is_required = required
    is_hidden = hidden
    is_multi = multi
    should_split_commas = split_commas
    if name.contains "=" or name.starts_with "no-": throw "Invalid option name: $name"
    if short_name and not is_alpha_num_string_ short_name:
      throw "Invalid short option name: '$short_name'"
    if split_commas and not multi:
      throw "--split_commas is only valid for multi options."
    if is_hidden and is_required:
      throw "Option can't be hidden and required."

  static is_alpha_num_string_ str/string -> bool:
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
  default_as_string -> string?:
    default_value := default
    if default_value != null: return default_value.stringify
    return null

  /** The default value of this option. */
  abstract default -> any

  /** The type of the option. This property is only used in help output. */
  abstract type -> string

  /** Whether this option is a flag. */
  abstract is_flag -> bool

  /**
  Parses the given $str and returns the parsed value.

  If $for_help_example is true, only performs validation that is valid for examples.
    For example, a FileOption would not check that the file exists.
  */
  abstract parse str/string --for_help_example/bool=false -> any

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
      --short_name/string?=null
      --short_help/string?=null
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false
      --split_commas/bool=false:
    if multi and default: throw "Multi option can't have default value."
    if required and default: throw "Option can't have default value and be required."
    super name --short_name=short_name --short_help=short_help \
        --required=required --hidden=hidden --multi=multi \
        --split_commas=split_commas

  is_flag: return false

  parse str/string --for_help_example/bool=false -> string:
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
      --short_name/string?=null
      --short_help/string?=null
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false
      --split_commas/bool=false:
    if multi and default: throw "Multi option can't have default value."
    if required and default: throw "Option can't have default value and be required."
    super name --short_name=short_name --short_help=short_help \
        --required=required --hidden=hidden --multi=multi \
        --split_commas=split_commas
    if default and not values.contains default:
      throw "Default value of '$name' is not a valid value: $default"

  is_flag: return false

  parse str/string --for_help_example/bool=false -> string:
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
      --short_name/string?=null
      --short_help/string?=null
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false
      --split_commas/bool=false:
    if multi and default: throw "Multi option can't have default value."
    if required and default: throw "Option can't have default value and be required."
    super name --short_name=short_name --short_help=short_help \
        --required=required --hidden=hidden --multi=multi \
        --split_commas=split_commas

  is_flag: return false

  parse str/string --for_help_example/bool=false -> int:
    return int.parse str --on_error=:
      throw "Invalid integer value for option '$name': '$str'."

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
      --short_name/string?=null
      --short_help/string?=null \
      --required/bool=false
      --hidden/bool=false
      --multi/bool=false:
    if multi and default != null: throw "Multi option can't have default value."
    if required and default != null: throw "Option can't have default value and be required."
    super name --short_name=short_name --short_help=short_help \
        --required=required --hidden=hidden --multi=multi --no-split_commas

  type -> string:
    return "true|false"

  is_flag: return true

  parse str/string --for_help_example/bool=false -> bool:
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
  global_priority/int

  /**
  Creates an example.

  The $description should describe the example without any context. This is especially true
    if the $global_priority is greater than 0 (see below). It should start with a capital
    letter and finish with a ":". It may contain newlines. Use indentation to group
    paragraphs (just like toitdoc).

  The $arguments is a string containing the arguments to this command (or to super commands).
    The help generator parses the arguments and assigns all options to the corresponding commands.

  The $arguments should not contain the path up to this command. For example, if we want to
    document the command `foo bar baz --gee` and are writing the example for the command `baz`, then
    $arguments should be equal to `--gee`. If the example is for the command `bar`, then $arguments
    should be equal to `baz --gee`.

  The $global_priority is used to sort the examples of sub commands. Examples with a higher priority
    are shown first. Examples with the same priority are sorted in the order in which they are
    encountered.

  The $global_priority must be in the range 0 to 10 (both inclusive). The default value is 0.

  If the $global_priority is 0, then it is not used as example for super commands.
  */
  constructor .description --.arguments --.global_priority=0:
    if not 0 <= global_priority <= 10: throw "INVALID_ARGUMENT"

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
  seen_options_/Set

  /**
  Builds a new $Parsed object.
  */
  constructor.private_ .path .options_ .seen_options_:

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
    kebab_name := to_kebab name
    return options_.get kebab_name --if_absent=: throw "No option named '$name'"

  /**
  Whether an option with the given $name was given on the command line.
  */
  was_provided name/string -> bool:
    return seen_options_.contains name

  stringify:
    buffer := []
    options_.do: | name value | buffer.add "$name=$value"
    return buffer.join " "

global_print_ str/string: print str

class Ui_ implements Ui:
  print str/string: global_print_ str
  abort: exit 1
