// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import .cli
import .parser_

/**
The 'help' command that can be executed on the root command.

It finds the selected command and prints its help.
*/
help_command_ path/List arguments/List --invoked_command/string --ui/Ui:
  // We are modifying the path, so make a copy.
  path = path.copy

  command/Command := path.last

  for i := 0; i < arguments.size; i++:
    argument := arguments[i]
    if argument == "--": break

    // Simply drop all options.
    if argument.starts_with "-":
      continue

    subcommand := command.find_subcommand_ argument
    if not subcommand:
      ui.print "Unknown command: $argument"
      ui.abort
      unreachable
    command = subcommand
    path.add command

  print_help_ path --invoked_command=invoked_command --ui=ui

/**
Prints the help for the given command.

The command is identified by the $path where the command is the last element.
*/
print_help_ path --invoked_command/string --ui/Ui:
  generator := HelpGenerator path --invoked_command=invoked_command
  generator.build_all
  help := generator.to_string
  ui.print help

/**
Generates the help for a command.

The class also serves as a string builder for the `build_X` methods. The methods call
  the $write_, $writeln_, ... functions. The generated help can be obtained by
  calling the $to_string method.
*/
class HelpGenerator:
  command_/Command
  path_/List
  invoked_command_/string
  buffer_/List := []  // Buffered string.
  // The index in the buffer of the last separator.
  last_separator_pos_/int := 0

  constructor .path_ --invoked_command/string:
    invoked_command_ = invoked_command
    command_=path_.last

  /**
  Builds the full help for the command that was given to the constructor.
  */
  build_all:
    build_description
    build_usage
    build_aliases
    build_commands
    build_local_options
    build_global_options
    build_examples

  /**
  Whether his help generator is for the root command.
  */
  is_root_command_ -> bool: return path_.size == 1

  /**
  The options that are defined in super commands.
  */
  global_options_ -> List:
    result := []
    for i := 0; i < path_.size - 1; i++:
      result.add_all path_[i].options
    return result

  /**
  Builds the description.

  If available, the description is the $Command.long_help, otherwise, the
    $Command.short_help is used. If none exists, no description is built.
  */
  build_description -> none:
    if help := command_.long_help:
      ensure_vertical_space_
      writeln_ (help.trim --right)
    else if short_help := command_.short_help:
      ensure_vertical_space_
      writeln_ (short_help.trim --right)

  /**
  Builds the usage section.

  If the command has a $Command.usage line, then that one is used. Otherwise the
    usage line is built from the available options or subcommands.
  */
  build_usage -> none:
    ensure_vertical_space_
    writeln_ "Usage:"
    if command_.usage:
      writeln_ command_.usage --indentation=2
      return

    // We want to construct a usage line like
    //    cmd --option1=<string> --option2=<bar|baz> [<options>] [--] <rest1> [<rest2>...]
    // We only show required named options in the usage line.
    // Options are stored together with the (super)command that defines them.
    // They are sorted by name.
    // For the usage line we don't care for the short names of options.

    write_ invoked_command_ --indentation=2
    has_more_options := false
    for i := 0; i < path_.size; i++:
      current_command := path_[i]
      if i != 0: write_ " $current_command.name"
      current_options := current_command.options
      sorted := current_options.sort: | a/Option b/Option | a.name.compare_to b.name
      sorted.do: | option/Option |
        if option.is_required:
          write_ " --$option.name"
          if not option.is_flag:
            write_ "=<$option.type>"
        else if not option.is_hidden:
          has_more_options = true

    if not command_.subcommands.is_empty: write_ " <command>"
    if has_more_options: write_ " [<options>]"
    if not command_.rest.is_empty: write_ " [--]"
    command_.rest.do: | option/Option |
      type := option.type
      option_str/string := ?
      if type == "string": option_str = "<$option.name>"
      else: option_str = "<$option.name:$option.type>"
      if option.is_multi: option_str = "$option_str..."
      if not option.is_required: option_str = "[$option_str]"
      write_ " $option_str"
    writeln_

  /**
  Builds the aliases section.

  Only generates the alias section if the command is not the root command.
  */
  build_aliases -> none:
    if is_root_command_ or command_.aliases.is_empty: return
    ensure_vertical_space_
    writeln_ "Aliases:"
    writeln_ (command_.aliases.join ", ") --indentation=2

  /**
  Builds the commands section.

  Lists all subcommands with a short help.
  Uses the first line of the long help if no short help is available.

  If the command is the root-command also adds the 'help' command.
  */
  build_commands -> none:
    if command_.subcommands.is_empty: return
    ensure_vertical_space_
    writeln_ "Commands:"

    commands_and_help := []
    has_help_subcommand := false
    command_.subcommands.do: | subcommand/Command |
      if subcommand.name == "help": has_help_subcommand = true
      subcommand.aliases.do: if it == "help": has_help_subcommand = true

      if subcommand.is_hidden: continue.do

      help_str := ?
      if help := subcommand.short_help:
        help_str = help
      else if long_help := subcommand.long_help:
        // Take the first paragraph (potentially multiple lines) of the long help.
        paragraph_index := long_help.index_of "\n\n"
        if paragraph_index == -1:
          help_str = long_help
        else:
          help_str = long_help[..paragraph_index]
      else:
        help_str = ""
      commands_and_help.add [subcommand.name, help_str]

    if not has_help_subcommand and is_root_command_:
      commands_and_help.add ["help", "Show help for a command."]

    sorted_commands := commands_and_help.sort: | a/List b/List | a[0].compare_to b[0]
    write_table_ sorted_commands --indentation=2

  /**
  Builds the local options section.

  Automatically adds the help option if it is not already defined.
  */
  build_local_options -> none:
    build_options_ --title="Options" command_.options --add_help

  /**
  Builds the global options section.

  Global options are the ones inherited from super commands.
  */
  build_global_options -> none:
    build_options_ --title="Global options" global_options_

  build_options_ --title/string options/List --add_help/bool=false -> none:
    if options.is_empty and not add_help: return

    ensure_vertical_space_
    writeln_ "$title:"

    if add_help:
      has_help_flag := false
      has_short_help_flag := false
      options.do: | option/Option |
        if option.name == "help": has_help_flag = true
        if option.short_name == "h": has_short_help_flag = true

      if not has_help_flag:
        options = options.copy
        short_name := has_short_help_flag ? null : "h"
        help_flag := Flag "help" --short_name=short_name --short_help="Show help for this command."
        options.add help_flag

    sorted_options := options.sort: | a/Option b/Option | a.name.compare_to b.name

    max_short_name := 1
    sorted_options.do:
      if it.short_name: max_short_name = max max_short_name it.short_name.size

    options_type_defaults_and_help := []

    sorted_options.do: | option/Option |
      if option.is_hidden: continue.do
      option_str/string := ?
      if option.short_name: option_str = "-$option.short_name, "
      else: option_str = "    "
      option_str = option_str.pad --right (3 + max_short_name) ' '
      option_str += "--$option.name"
      type_str := option.type
      if not option.is_flag:
        option_str += " $type_str"

      help_str := option.short_help or ""
      additional_info := ""
      default_value := option.default
      needs_separator := false
      if default_value:
        assert: not needs_separator
        additional_info += "default: $default_value"
        needs_separator = true
      if option.is_multi:
        if needs_separator: additional_info += ", "
        additional_info += "multi"
        needs_separator = true
      if option.is_required:
        if needs_separator: additional_info += ", "
        additional_info += "required"
        needs_separator = true
      if additional_info != "": help_str += " ($additional_info)"
      help_str = help_str.trim

      options_type_defaults_and_help.add [option_str, help_str]

    write_table_ options_type_defaults_and_help --indentation=2

  /**
  Builds the examples section.

  Local examples are first, followed by examples from subcommands, as long as
    their $Example.global_priority is greater than 0.

  Examples from subcommands are sorted by their $Example.global_priority.
  Examples that have the same priority are printed in the order in which they are
    discovered.

  Each example is parsed and must be valid. The example's $Example.arguments are
    just arguments to the command on which they are defined. This function is
    prefixing the arguments with the commands.

  Options are moved to the command that defines them.
  For short-hand options (like `-abc`) groups are moved to the first command that
    accepts them all.

  # Examples
  For commands `root --global=<string> sub --local=<int>` an example on the `sub` command
    could be: `--global=xyz --local 123`. The example would be reconstructed as
    `root --global=xyz sub --local 123`. Note, that options are only moved, but not canonicalized
    to a certain way of writing options (like `--foo=bar` vs `--foo bar`).
  */
  build_examples:
    // Get the local examples directly, as we want to keep them on top, and as we
    // don't want to filter them.
    this_examples := command_.examples.map: | example/Example | [example, path_]
    sub_examples := []
    add_global_examples_ command_ sub_examples --path=path_ --skip_first_level
    sub_examples.sort --in_place: | a/List b/List | a[0].global_priority - b[0].global_priority

    all_examples := this_examples + sub_examples
    if all_examples.is_empty: return

    ensure_vertical_space_
    writeln_ "Examples:"
    for i := 0; i < all_examples.size; i++:
      if i != 0: writeln_
      example_and_path := all_examples[i]
      example/Example := example_and_path[0]
      example_path/List := example_and_path[1]

      build_example_ example --example_path=example_path

  /**
  Adds all global examples (with $Example.global_priority > 0) to the $all_examples list.

  The $path provides the sequence that was used to reach this command. It is updated for
    subcommands and stored together with the examples in  $all_examples.

  If $skip_first_level is true, then does not add the examples of this command, but only
    those of subcommands.
  */
  add_global_examples_ command/Command all_examples/List --path/List --skip_first_level/bool=false -> none:
    if not skip_first_level:
      global_examples := (command.examples.filter: it.global_priority > 0)
      all_examples.add_all (global_examples.map: [it, path])

    command.subcommands.do: | subcommand/Command |
      if subcommand.is_hidden: continue.do
      add_global_examples_ subcommand all_examples --path=(path + [subcommand])

  /**
  Builds a single example.

  The $example contains the description and arguments, and the $example_path is
    the path to the command that contains the example.
  */
  build_example_ example/Example --example_path/List:
    description := example.description.trim --right
    description_lines := ?
    if description.contains "\n": description_lines = description.split "\n"
    else: description_lines = [example.description]
    description_lines.do:
      write_ "# " --indentation=2
      writeln_ it

    arguments_strings := example.arguments.split "\n"
    if arguments_strings.size > 1 and arguments_strings.last == "":
      arguments_strings = arguments_strings[..arguments_strings.size-1]
    arguments_strings.do:
      build_example_command_line_ it --example_path=example_path

  /**
  Builds the example command line for the given $arguments_line.
  The command that defined the example is identified by the $example_path.
  */
  build_example_command_line_ arguments_line/string --example_path/List:
    // Start by constructing a valid command line.

    // The prefix consists of the subcommands.
    prefix := example_path[1..].map: | command/Command | command.name
    // Split the arguments line into individual arguments.
    // For example, `"foo --bar \"my password\""` is split into `["foo", "--bar", "my password"]`.
    example_arguments := split_arguments_ arguments_line
    command_line := prefix + example_arguments

    // Parse it, to verify that it actually is valid.
    // We are also using the result to reorder the options.
    parser := Parser_ --ui=(ExampleUi_ arguments_line) --invoked_command="root" --no-usage_on_error
    parsed := parser.parse example_path.first command_line --for_help_example

    parsed_path := parsed.path

    // For each command, collect the options that are defined on it and that were
    // used in the example.
    option_to_command := {:}  // Map from option to command.
    command_level := {:}
    flags := {}
    for j := 0; j < parsed_path.size; j++:
      current_command/Command := parsed_path[j]
      command_level[current_command] = j
      current_command.options.do: | option/Option |
        if not parsed.was_provided option.name: continue.do
        option_to_command["--$option.name"] = current_command
        if option.short_name: option_to_command["-$option.short_name"] = current_command
        if option.is_flag:
          flags.add "--$option.name"
          if option.short_name: flags.add "-$option.short_name"

    // Collect all the options that are destined for a (sub/super)command.
    options_for_command := {:}  // Map from command to list of options.

    argument_index := 0
    path_index := 0
    while argument_index < command_line.size:
      argument := command_line[argument_index++]
      if argument == "--":
        break
      if not argument.starts_with "-":
        if path_index >= parsed_path.size - 1:
          argument_index--
          break
        else:
          path_index++
          continue

      if argument.starts_with "--":
        option_name := ?
        equal_pos := argument.index_of "="
        if equal_pos >= 0:
          option_name = argument[..equal_pos]
        else if argument.starts_with "--no-":
          option_name = "--$argument[5..]"
        else:
          option_name = argument
        option_command := option_to_command[option_name]
        is_flag := flags.contains option_name
        options_for_command.update option_command --init=(: []): | list/List |
          list.add argument
          if not is_flag and equal_pos < 0:
            list.add command_line[argument_index++]
          list

      else if argument.starts_with "-" and argument != "-":
        highest_level := -1
        highest_command := null
        takes_extra_arg := false
        // We find the first command that accepts all of the options in this cluster.
        for j := 1; j < argument.size; j++:
          c := argument[j]
          option_name := "-$(string.from_rune c)"
          option_command := option_to_command[option_name]
          level/int := command_level[option_command]
          if level > highest_level:
            highest_level = level
            highest_command = option_command
          if j == argument.size - 1 and not flags.contains option_name:
            takes_extra_arg = true

        options_for_command.update highest_command --init=(: []): | list/List |
          list.add argument
          if takes_extra_arg:
            list.add command_line[argument_index++]
          list

    options_for_command.update parsed_path.last --init=(: []) : | list/List |
      list.add_all command_line[argument_index..]
      list

    // Reconstruct the full command line, but now with the options next to the
    // commands that defined them.
    full_command := []
    parsed_path.do: | current_command |
      full_command.add current_command.name
      command_options := options_for_command.get current_command
      if command_options:
        command_options.do: | option/string |
          full_command.add option

    writeln_ (full_command.join " ") --indentation=2

  /**
  Splits a string into individual arguments.
  */
  split_arguments_ arguments_string/string -> List:
    arguments_string = arguments_string.trim
    arguments_string += " "
    arguments := []
    // Currently only handles double quotes.
    in_quotes := false
    start := 0
    for i := 0; i < arguments_string.size; i++:
      c := arguments_string[i]
      if c == ' ' and not in_quotes:
        if i != start:
          arguments.add arguments_string[start..i]
        start = i + 1
      else if c == '"':
        in_quotes = not in_quotes

    if in_quotes: throw "Unterminated quotes: $arguments_string.trim"
    return arguments

  write_ str/string:
    buffer_.add str

  write_ str/string --indentation/int --indent_first_line/bool=true:
    indentation_str := " " * indentation
    if indent_first_line:
      buffer_.add indentation_str
    buffer_.add (str.replace "\n"  "\n$indentation_str")

  writeln_ str/string="":
    if str != "": buffer_.add str
    buffer_.add "\n"

  writeln_ str/string --indentation/int --indent_first_line/bool=true:
    write_ str --indentation=indentation --indent_first_line=indent_first_line
    buffer_.add "\n"

  count_occurrences_ str/string needle/string -> int:
    if needle.size == 0: throw "INVALID_ARGUMENT"
    count := 0
    index := 0
    while true:
      index = str.index_of needle index
      if index >= 0:
        count++
        index += needle.size
      else:
        return count

  /**
  Writes a table into the buffer.

  Determines the size of each column, and aligns the columns.
  Uses 2 spaces as the column separator.
  */
  write_table_ rows/List --indentation/int=0:
    if rows.is_empty: return
    column_count := rows[0].size

    // If an entry in the row has multiple lines split it into multiple rows.
    split_rows := []
    rows.do: | row/List |
      max_line_count := 1
      row.do: | entry/string |
        // Remove trailing whitespace.
        trimmed := entry.trim --right
        // Count number of lines in the entry.
        line_count := 1 + (count_occurrences_ trimmed "\n")
        max_line_count = max max_line_count line_count

      if max_line_count == 1:
        split_rows.add row
      else:
        columns := []
        row.do: | entry/string |
          // Remove trailing whitespace.
          trimmed := entry.trim --right
          // Split the entry into lines.
          lines := trimmed.split "\n"
          (max_line_count - lines.size).repeat:
            lines.add ""
          columns.add lines
        max_line_count.repeat: | line_index/int |
          line := columns.map: it[line_index]
          split_rows.add line

    max_len := List column_count: 0
    split_rows.do: | row/List |
      for i := 0; i < column_count; i++:
        max_len[i] = max max_len[i] row[i].size

    split_rows.do: | row/List |
      write_ --indentation=indentation ""
      for i := 0; i < column_count; i++:
        entry := row[i]
        write_ entry
        needs_spacing := false
        for j := i + 1; j < column_count; j++:
          if row[j] != "":
            needs_spacing = true
            break
        if needs_spacing:
          write_ " " * (max_len[i] - entry.size + 2)
      writeln_

  /**
  Ensures that there is vertical space at the current position.

  Vertical space is currently just an empty line.
  */
  ensure_vertical_space_ -> none:
    if buffer_.size == last_separator_pos_:
      // Nothing was written since the last separator.
      // There is still a separator at the end of the buffer.
      return
    writeln_
    last_separator_pos_ = buffer_.size

  to_string -> string:
    return buffer_.join ""


global_print_ str/string:
  print str

class ExampleUi_ implements Ui:
  example_/string

  constructor .example_:

  print str/string:
    global_print_ str

  abort:
    throw "Error in example: $example_"
