// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

/// Used as an argument for the `--max` option.
UNLIMITED ::= -1

/**
A customizable parser of command line arguments.
*/
class ArgumentParser:
  static calculate_minimum_ rest_names/List? -> int:
    if rest_names == null:
      return 0
    size := rest_names.size
    if size > 0 and rest_names[size - 1] == "...":
      size--
    while size > 0 and rest_names[size - 1].starts_with "[" and rest_names[size - 1].ends_with "]":
      size--
    return size

  static calculate_maximum_ rest_names/List? -> int:
    if rest_names == null:
      return UNLIMITED
    size := rest_names.size
    if size > 0 and rest_names[size - 1] == "...":
      return UNLIMITED
    return size

  static calculate_rest_usage_ rest_names/List? rest_minimum/int rest_maximum/int -> string:
    if rest_maximum == 0: return ""

    parts := [""]

    count := max
      rest_maximum == UNLIMITED ? rest_minimum : rest_maximum
      rest_names ? rest_names.size : 0

    count.repeat: | i |
      name := (rest_names and rest_names.size > i) ? rest_names[i] : "argument"
      if name.starts_with "<" and name.ends_with ">":
        parts.add name
      if name.starts_with "[" and name.ends_with "]":
        parts.add name
      else if i >= rest_minimum and name != "...":
        parts.add "[$name]"
      else if name != "...":
        parts.add "<$name>"

    if rest_maximum == UNLIMITED:
      parts.add "..."

    return parts.join " "

  /**
  Add a new command to the parser.
  Returns a new $ArgumentParser for the given command.
  */
  add_command name/string -> ArgumentParser:
    if rest_was_described_: throw "Can't have rest arguments and commands"
    // TODO(kasper): Check if we already have a parser for the given
    // command name. Don't allow duplicates.
    return commands_[name] = ArgumentParser

  /// Adds a boolean flag for the given name. Always defaults to false. Can be
  ///   set to true by passing '--<name>' or '-<short>' if short isn't null.
  add_flag name/string --short/string?=null -> none:
    options_["--$name"] = Option_ name --is_flag --default=false
    if short: add_alias name short

  /// Adds an option with the given default value.
  add_option name/string --default=null --short/string?=null -> none:
    options_["--$name"] = Option_ name --default=default
    if short: add_alias name short

  /// Adds an option that can be provided multiple times.
  add_multi_option name/string --split_commas/bool=true --short/string?=null -> none:
    options_["--$name"] = Option_ name --is_multi_option --split_commas=split_commas
    if short: add_alias name short

  /// Adds a short alias for an option.
  add_alias name/string short/string:
    options_["-$short"] = options_["--$name"]

  /**
  Provides a list of arguments that can be provided after the options.  This
    list will be used for usage messages.
  $min specifies the minimum number of arguments that must be provided
    after the options.  It defaults to the length of the $names list, or
    zero.  When using the length of the $names to determine default
    $min, trailing arguments that are surrounded by "[]" are not counted, nor
    are trailing arguments that are named "...".
  $max specifies the maximum number of arguments that must be provided
    after the options.  It defaults to the length of the $names list, or
    $UNLIMITED if the last member of the $names list is "...".
  $usage is a textual description of the rest arguments that can be
    provided.  It defaults to a string constructed from the other arguments.
  */
  describe_rest -> none
      names /List? = null
      --min /int = (calculate_minimum_ names)
      --max /int = (calculate_maximum_ names)
      --usage /string? = (calculate_rest_usage_ names min max):
    if commands_.size != 0: throw "Can't have rest arguments and commands"
    rest_minimum = min
    rest_maximum = max
    rest_usage = usage
    rest_was_described_ = true

  /**
  Parses the given $arguments.
  If there is an error it prints the error message and the usage
    description on stderr, then exits the VM completely with a non-zero
    exit value.
  The $invoked_command is used only for the usage message in case of an
    error.  It defaults to $program_name.
  */
  parse arguments --invoked_command=program_name -> Arguments:
    return parse arguments --invoked_command=invoked_command: | error_message usage_string |
      print_on_stderr_ "$error_message"
      print_on_stderr_
          usage_string
      exit 1

  /**
  Parses the given $arguments.
  If there is an error in the arguments the block will be called.  If the block
    returns, an exception is thrown.  The arguments to the block are:
  `error_message`: the error message.
  `usage_string`: A usage string for the whole parser, or perhaps just the subcommand the user attempted to use.
    This may be a multiline string, but it doesn't have a terminating newline.
  The $invoked_command is used only for the usage message in case of an
    error.  It defaults to $program_name.
  */
  parse arguments --invoked_command=program_name [error_block] -> Arguments:
    try:
      return parse_ this null arguments 0
    finally: | is_exception exception |
      if is_exception:
        (arguments.size + 1).repeat:
          if it >= arguments.size or not arguments[it].starts_with "-":
            error_block.call exception.value (usage arguments[it..] --invoked_command=invoked_command)

  commands_ := {:}
  options_ := {:}
  rest_minimum/int := 0
  rest_maximum/int := UNLIMITED
  rest_usage/string := ""
  rest_was_described_/bool := false

  /**
  Provides a usage guide for the user.  The arguments list is
    used to limit usage to a subcommand if any.
  The $invoked_command is used only for the usage message in case of an
    error.  It defaults to $program_name.
  */
  usage arguments/List=[] --invoked_command=program_name -> string:
    result := "Usage:"
    prefix := "$invoked_command "
    parser := this
    for index := 0; index < arguments.size; index++:
      command := arguments[index]
      if parser.commands_.contains command:
        if parser.options_.size != 0:
          // When giving usage for a subcommand we don't specify all the
          // options of the super-command.
          prefix += "[options] "
        prefix += command + " "
        parser = commands_[command]
      else if parser.options_.contains command:
        if (command.index_of "=") == -1 and not parser.options_[command].is_flag and parser.options_[command].default == null:
          index++  // Skip the option's argument.
        continue
      else:
        break
    return "Usage:" + (parser.usage_ --prefix=prefix)

  usage_ --prefix -> string:
    options_.do: | name option |
      if name.starts_with "--":
        display_name := name
        options_.do: | shortname shortoption |
          if shortname != name and shortoption == option:
            display_name = "$display_name|$shortname"
        if option.is_flag:
          prefix = "$(prefix)[$display_name] "
        else:
          star := option.is_multi_option ? "*" : ""
          prefix = "$(prefix)[$display_name=<$name[2..]>]$star "
    if commands_.is_empty:
      if rest_usage != "":
        return "\n$(prefix)[--]$rest_usage"
      return "\n$prefix[..prefix.size - 1]"
    result := ""
    commands_.do: | command subparser |
      result += subparser.usage_ --prefix="$prefix$command "
    return result

class Arguments:
  constructor .command_:
  constructor .command_ .options_ .rest_:

  /// Returns the parsed command or null.
  command -> string?:
    return command_

  // Returns the parsed option or the default value.
  operator[] key/string -> any:
    return options_.get key --if_absent=: throw "No option named '$key'"

  // Returns the non-option arguments.
  rest -> List:
    return rest_

  stringify:
    buffer := []
    if command_: buffer.add command_
    options_.do: | name value | buffer.add "--$name=$value"
    if not rest_.is_empty:
      buffer.add "--"
      rest_.do: buffer.add it
    return buffer.join " "

  command_ := ?
  options_ := {:}
  rest_ := []

// ----------------------------------------------------------------------------

// Argument parsing functionality.
parse_ grammar command arguments index:
  if not command and index < arguments.size:
    first := arguments[index]
    grammar.commands_.get first --if_present=:
      sub := it
      return parse_ sub first arguments index + 1

  // Populate the options from the default values or empty lists (for multi-options)
  options := {:}
  rest := []
  grammar.options_.do --values:
    if it.is_multi_option:
      options[it.name] = []
    else:
      options[it.name] = it.default

  seen_options := {}

  while index < arguments.size:
    argument := arguments[index]
    if argument == "--":
      for i := index + 1; i < arguments.size; i++: rest.add arguments[i]
      break  // We're done!

    option := null
    value := null
    if argument.starts_with "--":
      // Get the option name.
      split := argument.index_of "="
      name := (split < 0) ? argument : argument.copy 0 split

      option = grammar.options_.get name --if_absent=: throw "Unknown option $name"
      if split >= 0: value = argument.copy split + 1
    else if argument.starts_with "-":
      // Compute the option and the effective name. We allow short form prefixes to have
      // the value encoded in the same argument like -s"123 + 345", so we have to search
      // for prefixes.
      name := argument
      grammar.options_.get argument
        --if_present=:
          name = argument
          option = it
        --if_absent=:
          grammar.options_.do --keys:
            if argument.starts_with it:
              name = it
              option = grammar.options_[it]
      if not option: throw "Unknown option $argument"

      if name != argument:
        value = argument.copy name.size

    if option:
      if option.is_flag:
        if value: throw "Cannot specify value for boolean flags ($value)"
        value = true
      else if not value:
        if ++index >= arguments.size: throw "No value provided for option $argument"
        value = arguments[index]

      if option.is_multi_option:
        values := option.split_commas ? value.split "," : [value]
        options[option.name].add_all values
      else if seen_options.contains option.name:
        throw "Option was provided multiple times: $argument"
      else:
        options[option.name] = value
        seen_options.add option.name
    else:
      rest.add argument
    index++

  if rest.size < grammar.rest_minimum:
    throw "Too few arguments"

  if grammar.rest_maximum != UNLIMITED and rest.size > grammar.rest_maximum:
    throw "Too many arguments"

  // Construct an [Arguments] object and return it.
  return Arguments command options rest

class Option_:
  name := ?
  is_flag := false
  is_multi_option := false
  split_commas := false  // Only used, if this is a multi-option.
  default := ?

  constructor .name --.is_flag=false --.is_multi_option=false --.split_commas=false --.default=null:
    assert: not split_commas or is_multi_option
