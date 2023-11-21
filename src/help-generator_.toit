// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import .cli
import .parser_
import .utils_
import .ui

/**
The 'help' command that can be executed on the root command.

It finds the selected command and prints its help.
*/
help-command_ path/List arguments/List --invoked-command/string --ui/Ui:
  // We are modifying the path, so make a copy.
  path = path.copy

  command/Command := path.last

  for i := 0; i < arguments.size; i++:
    argument := arguments[i]
    if argument == "--": break

    // Simply drop all options.
    if argument.starts-with "-":
      continue

    subcommand := command.find-subcommand_ argument
    if not subcommand:
      ui.abort "Unknown command: $argument"
      unreachable
    command = subcommand
    path.add command

  emit-help_ path --invoked-command=invoked-command --ui=ui

/**
Emits the help for the given command.

The command is identified by the $path where the command is the last element.
*/
emit-help_ path/List --invoked-command/string --ui/Ui:
  ui.do --kind=Ui.RESULT: | printer/Printer |
    printer.emit-structured
        --json=: build-json-help_ path --invoked-command=invoked-command
        --stdout=:
          generator := HelpGenerator path --invoked-command=invoked-command
          generator.build-all
          help := generator.to-string
          printer.emit help

build-json-help_ path/List --invoked-command/string -> Map:

  extract-options := : | command/Command out-map/Map |
    options := command.options_.filter: | option/Option | not option.is-hidden
    command.options_.do: | option/Option |
      if not out-map.contains option.name:
        default := option.default
        if default != null and default is not bool and default is not num and default is not string and
            default is not List and default is not Map:
          default = "$default"
        json-option := {
          "type": option.type,
          "is-flag": option.is-flag,
          "is-multi": option.is-multi,
          "is-required": option.is-required,
        }
        if not option.is-required: json-option["default"] = default
        if option.help: json-option["help"] = option.help
        if option.short-name: json-option["short-name"] = option.short-name
        out-map[option.name] = json-option
    out-map

  command/Command := path.last

  global-options := {:}
  for i := path.size - 2; i >= 0; i--:
    parent-command := path[i]
    extract-options.call parent-command global-options

  json-examples := command.examples_.map: | example/Example |
    {
      "description": example.description,
      "arguments": example.arguments,
      "global-priority": example.global-priority,
    }

  return {
    "name": command.name,
    "path": path.map: | command/Command | command.name,
    "help": command.help_,
    "aliases": command.aliases_,
    "options": extract-options.call command {:},
    "global-options": global-options,
    "examples": json-examples,
  }

/**
Generates the help for a command.

The class also serves as a string builder for the `build_X` methods. The methods call
  the $write_, $writeln_, ... functions. The generated help can be obtained by
  calling the $to-string method.
*/
class HelpGenerator:
  command_/Command
  path_/List
  invoked-command_/string
  buffer_/List := []  // Buffered string.
  // The index in the buffer of the last separator.
  last-separator-pos_/int := 0

  constructor .path_ --invoked-command/string:
    invoked-command_ = invoked-command
    command_=path_.last

  /**
  Builds the full help for the command that was given to the constructor.
  */
  build-all:
    build-description
    build-usage
    build-aliases
    build-commands
    build-local-options
    build-global-options
    build-examples

  /**
  Whether his help generator is for the root command.
  */
  is-root-command_ -> bool: return path_.size == 1

  /**
  The options that are defined in super commands.
  */
  global-options_ -> List:
    result := []
    for i := 0; i < path_.size - 1; i++:
      result.add-all path_[i].options_
    return result

  /**
  Builds the description.

  If available, the description is the $Command.help_, otherwise, the
    (now deprecated) $Command.short-help_ is used. If none exists, no description is built.
  */
  build-description -> none:
    if help := command_.help_:
      ensure-vertical-space_
      writeln_ (help.trim --right)
    else if short-help := command_.short-help_:
      ensure-vertical-space_
      writeln_ (short-help.trim --right)

  /**
  Builds the usage section.

  If the command has a $Command.usage_ line, then that one is used. Otherwise the
    usage line is built from the available options or subcommands.

  If $as-section is true, then the section is preceded by a "Usage:" title, indented,
    and followed by an empty line.
  */
  build-usage --as-section/bool=true -> none:
    ensure-vertical-space_
    if as-section:
      writeln_ "Usage:"
    indentation := as-section ? 2 : 0
    if command_.usage_:
      write_ command_.usage_ --indentation=indentation
      if as-section: writeln_
      return

    // We want to construct a usage line like
    //    cmd --option1=<string> --option2=<bar|baz> [<options>] [--] <rest1> [<rest2>...]
    // We only show required named options in the usage line.
    // Options are stored together with the (super)command that defines them.
    // They are sorted by name.
    // For the usage line we don't care for the short names of options.

    write_ invoked-command_ --indentation=indentation
    has-more-options := false
    for i := 0; i < path_.size; i++:
      current-command/Command := path_[i]
      if i != 0: write_ " $current-command.name"
      current-options := current-command.options_
      sorted := current-options.sort: | a/Option b/Option | a.name.compare-to b.name
      sorted.do: | option/Option |
        if option.is-required:
          write_ " --$option.name"
          if not option.is-flag:
            write_ "=<$option.type>"
        else if not option.is-hidden:
          has-more-options = true

    if not command_.subcommands_.is-empty: write_ " <command>"
    if has-more-options: write_ " [<options>]"
    if not command_.rest_.is-empty: write_ " [--]"
    command_.rest_.do: | option/Option |
      type := option.type
      option-str/string := ?
      if type == "string": option-str = "<$option.name>"
      else: option-str = "<$option.name:$option.type>"
      if option.is-multi: option-str = "$option-str..."
      if not option.is-required: option-str = "[$option-str]"
      write_ " $option-str"
    if as-section: writeln_

  /**
  Builds the aliases section.

  Only generates the alias section if the command is not the root command.
  */
  build-aliases -> none:
    if is-root-command_ or command_.aliases_.is-empty: return
    ensure-vertical-space_
    writeln_ "Aliases:"
    writeln_ (command_.aliases_.join ", ") --indentation=2

  /**
  Builds the commands section.

  Lists all subcommands with a short help.
  Uses the first line of the long help if no short help is available.

  If the command is the root-command also adds the 'help' command.
  */
  build-commands -> none:
    if command_.subcommands_.is-empty: return
    ensure-vertical-space_
    writeln_ "Commands:"

    commands-and-help := []
    has-help-subcommand := false
    command_.subcommands_.do: | subcommand/Command |
      if subcommand.name == "help": has-help-subcommand = true
      subcommand.aliases_.do: if it == "help": has-help-subcommand = true

      if subcommand.is-hidden_: continue.do

      help-str := ?
      if help := subcommand.short-help_:
        help-str = help
      else if long-help := subcommand.help_:
        // Take the first paragraph (potentially multiple lines) of the long help.
        paragraph-index := long-help.index-of "\n\n"
        if paragraph-index == -1:
          help-str = long-help
        else:
          help-str = long-help[..paragraph-index]
      else:
        help-str = ""
      commands-and-help.add [subcommand.name, help-str]

    if not has-help-subcommand and is-root-command_:
      commands-and-help.add ["help", "Show help for a command."]

    sorted-commands := commands-and-help.sort: | a/List b/List | a[0].compare-to b[0]
    write-table_ sorted-commands --indentation=2

  /**
  Builds the local options section.

  Automatically adds the help option if it is not already defined.
  */
  build-local-options -> none:
    build-options_ --title="Options" command_.options_ --add-help
    build-options_ --title="Rest" command_.rest_ --rest

  /**
  Builds the global options section.

  Global options are the ones inherited from super commands.
  */
  build-global-options -> none:
    build-options_ --title="Global options" global-options_

  build-options_ --title/string options/List --add-help/bool=false --rest/bool=false -> none:
    if options.is-empty and not add-help: return

    ensure-vertical-space_
    writeln_ "$title:"

    if add-help:
      has-help-flag := false
      has-short-help-flag := false
      options.do: | option/Option |
        if option.name == "help": has-help-flag = true
        if option.short-name == "h": has-short-help-flag = true

      if not has-help-flag:
        options = options.copy
        short-name := has-short-help-flag ? null : "h"
        help-flag := Flag "help" --short-name=short-name --help="Show help for this command."
        options.add help-flag

    sorted-options := options.sort: | a/Option b/Option | a.name.compare-to b.name

    max-short-name := 1
    sorted-options.do:
      if it.short-name: max-short-name = max max-short-name it.short-name.size

    options-type-defaults-and-help := []

    sorted-options.do: | option/Option |
      if option.is-hidden: continue.do
      option-str/string := ?
      if rest:
        option-str = "$option.name $option.type"
      else:
        if option.short-name: option-str = "-$option.short-name, "
        else: option-str = "    "
        option-str = option-str.pad --right (3 + max-short-name) ' '
        option-str += "--$option.name"
        type-str := option.type
        if not option.is-flag:
          option-str += " $type-str"

      help-str := option.help or ""
      additional-info := ""
      default-value := option.default
      needs-separator := false
      if default-value:
        assert: not needs-separator
        additional-info += "default: $default-value"
        needs-separator = true
      if option.is-multi:
        if needs-separator: additional-info += ", "
        additional-info += "multi"
        needs-separator = true
      if option.is-required:
        if needs-separator: additional-info += ", "
        additional-info += "required"
        needs-separator = true
      if additional-info != "": help-str += " ($additional-info)"
      help-str = help-str.trim

      options-type-defaults-and-help.add [option-str, help-str]

    write-table_ options-type-defaults-and-help --indentation=2

  /**
  Builds the examples section.

  Local examples are first, followed by examples from subcommands, as long as
    their $Example.global-priority is greater than 0.

  Examples from subcommands are sorted by their $Example.global-priority.
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
  build-examples:
    // Get the local examples directly, as we want to keep them on top, and as we
    // don't want to filter them.
    this-examples := command_.examples_.map: | example/Example | [example, path_]
    sub-examples := []
    add-global-examples_ command_ sub-examples --path=path_ --skip-first-level
    sub-examples.sort --in-place: | a/List b/List | a[0].global-priority - b[0].global-priority

    all-examples := this-examples + sub-examples
    if all-examples.is-empty: return

    ensure-vertical-space_
    writeln_ "Examples:"
    for i := 0; i < all-examples.size; i++:
      if i != 0: writeln_
      example-and-path := all-examples[i]
      example/Example := example-and-path[0]
      example-path/List := example-and-path[1]

      build-example_ example --example-path=example-path

  /**
  Adds all global examples (with $Example.global-priority > 0) to the $all-examples list.

  The $path provides the sequence that was used to reach this command. It is updated for
    subcommands and stored together with the examples in  $all-examples.

  If $skip-first-level is true, then does not add the examples of this command, but only
    those of subcommands.
  */
  add-global-examples_ command/Command all-examples/List --path/List --skip-first-level/bool=false -> none:
    if not skip-first-level:
      global-examples := (command.examples_.filter: it.global-priority > 0)
      all-examples.add-all (global-examples.map: [it, path])

    command.subcommands_.do: | subcommand/Command |
      if subcommand.is-hidden_: continue.do
      add-global-examples_ subcommand all-examples --path=(path + [subcommand])

  /**
  Builds a single example.

  The $example contains the description and arguments, and the $example-path is
    the path to the command that contains the example.
  */
  build-example_ example/Example --example-path/List:
    description := example.description.trim --right
    description-lines := ?
    if description.contains "\n": description-lines = description.split "\n"
    else: description-lines = [example.description]
    description-lines.do:
      write_ "# " --indentation=2
      writeln_ it

    arguments-strings := example.arguments.split "\n"
    if arguments-strings.size > 1 and arguments-strings.last == "":
      arguments-strings = arguments-strings[..arguments-strings.size - 1]
    arguments-strings.do:
      build-example-command-line_ it --example-path=example-path

  /**
  Builds the example command line for the given $arguments-line.
  The command that defined the example is identified by the $example-path.
  */
  build-example-command-line_ arguments-line/string --example-path/List:
    // Start by constructing a valid command line.

    // The prefix consists of the subcommands.
    prefix := example-path[1..].map: | command/Command | command.name
    // Split the arguments line into individual arguments.
    // For example, `"foo --bar \"my password\""` is split into `["foo", "--bar", "my password"]`.
    example-arguments := split-arguments_ arguments-line
    command-line := prefix + example-arguments

    // Parse it, to verify that it actually is valid.
    // We are also using the result to reorder the options.
    parser := Parser_ --invoked-command="root" --for-help-example
    parsed/Parsed? := null
    exception := catch:
      parsed = parser.parse example-path.first command-line
    if exception:
      throw "Error in example '$arguments-line': $exception"

    parsed-path := parsed.path

    // For each command, collect the options that are defined on it and that were
    // used in the example.
    option-to-command := {:}  // Map from option to command.
    command-level := {:}
    flags := {}
    for j := 0; j < parsed-path.size; j++:
      current-command/Command := parsed-path[j]
      command-level[current-command] = j
      current-command.options_.do: | option/Option |
        if not parsed.was-provided option.name: continue.do
        option-to-command["--$option.name"] = current-command
        if option.short-name: option-to-command["-$option.short-name"] = current-command
        if option.is-flag:
          flags.add "--$option.name"
          if option.short-name: flags.add "-$option.short-name"

    // Collect all the options that are destined for a (sub/super)command.
    options-for-command := {:}  // Map from command to list of options.

    argument-index := 0
    path-index := 0
    while argument-index < command-line.size:
      argument := command-line[argument-index++]
      if argument == "--":
        break
      if not argument.starts-with "-":
        if path-index >= parsed-path.size - 1:
          argument-index--
          break
        else:
          path-index++
          continue

      if argument.starts-with "--":
        option-name := ?
        equal-pos := argument.index-of "="
        if equal-pos >= 0:
          option-name = argument[..equal-pos]
        else if argument.starts-with "--no-":
          option-name = "--$argument[5..]"
        else:
          option-name = argument
        option-name = to-kebab option-name
        option-command := option-to-command[option-name]
        is-flag := flags.contains option-name
        options-for-command.update option-command --init=(: []): | list/List |
          list.add argument
          if not is-flag and equal-pos < 0:
            list.add command-line[argument-index++]
          list

      else if argument.starts-with "-" and argument != "-":
        highest-level := -1
        highest-command := null
        takes-extra-arg := false
        // We find the first command that accepts all of the options in this cluster.
        for j := 1; j < argument.size; j++:
          c := argument[j]
          option-name := "-$(string.from-rune c)"
          option-command := option-to-command[option-name]
          level/int := command-level[option-command]
          if level > highest-level:
            highest-level = level
            highest-command = option-command
          if j == argument.size - 1 and not flags.contains option-name:
            takes-extra-arg = true

        options-for-command.update highest-command --init=(: []): | list/List |
          list.add argument
          if takes-extra-arg:
            list.add command-line[argument-index++]
          list

    options-for-command.update parsed-path.last --init=(: []) : | list/List |
      list.add-all command-line[argument-index..]
      list

    // Reconstruct the full command line, but now with the options next to the
    // commands that defined them.
    full-command := []
    parsed-path.do: | current-command |
      full-command.add current-command.name
      command-options := options-for-command.get current-command
      if command-options:
        command-options.do: | option/string |
          full-command.add option

    writeln_ (full-command.join " ") --indentation=2

  /**
  Splits a string into individual arguments.
  */
  split-arguments_ arguments-string/string -> List:
    arguments-string = arguments-string.trim
    arguments-string += " "
    arguments := []
    // Currently only handles double quotes.
    in-quotes := false
    start := 0
    for i := 0; i < arguments-string.size; i++:
      c := arguments-string[i]
      if c == ' ' and not in-quotes:
        if i != start:
          arguments.add arguments-string[start..i]
        start = i + 1
      else if c == '"':
        in-quotes = not in-quotes

    if in-quotes: throw "Unterminated quotes: $arguments-string.trim"
    return arguments

  write_ str/string:
    buffer_.add str

  write_ str/string --indentation/int --indent-first-line/bool=true:
    indentation-str := " " * indentation
    if indent-first-line:
      buffer_.add indentation-str
    buffer_.add (str.replace "\n"  "\n$indentation-str")

  writeln_ str/string="":
    if str != "": buffer_.add str
    buffer_.add "\n"

  writeln_ str/string --indentation/int --indent-first-line/bool=true:
    write_ str --indentation=indentation --indent-first-line=indent-first-line
    buffer_.add "\n"

  count-occurrences_ str/string needle/string -> int:
    if needle.size == 0: throw "INVALID_ARGUMENT"
    count := 0
    index := 0
    while true:
      index = str.index-of needle index
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
  write-table_ rows/List --indentation/int=0:
    if rows.is-empty: return
    column-count := rows[0].size

    // If an entry in the row has multiple lines split it into multiple rows.
    split-rows := []
    rows.do: | row/List |
      max-line-count := 1
      row.do: | entry/string |
        // Remove trailing whitespace.
        trimmed := entry.trim --right
        // Count number of lines in the entry.
        line-count := 1 + (count-occurrences_ trimmed "\n")
        max-line-count = max max-line-count line-count

      if max-line-count == 1:
        split-rows.add row
      else:
        columns := []
        row.do: | entry/string |
          // Remove trailing whitespace.
          trimmed := entry.trim --right
          // Split the entry into lines.
          lines := trimmed.split "\n"
          (max-line-count - lines.size).repeat:
            lines.add ""
          columns.add lines
        max-line-count.repeat: | line-index/int |
          line := columns.map: it[line-index]
          split-rows.add line

    max-len := List column-count: 0
    split-rows.do: | row/List |
      for i := 0; i < column-count; i++:
        max-len[i] = max max-len[i] row[i].size

    split-rows.do: | row/List |
      write_ --indentation=indentation ""
      for i := 0; i < column-count; i++:
        entry := row[i]
        write_ entry
        needs-spacing := false
        for j := i + 1; j < column-count; j++:
          if row[j] != "":
            needs-spacing = true
            break
        if needs-spacing:
          write_ " " * (max-len[i] - entry.size + 2)
      writeln_

  /**
  Ensures that there is vertical space at the current position.

  Vertical space is currently just an empty line.
  */
  ensure-vertical-space_ -> none:
    if buffer_.size == last-separator-pos_:
      // Nothing was written since the last separator.
      // There is still a separator at the end of the buffer.
      return
    writeln_
    last-separator-pos_ = buffer_.size

  to-string -> string:
    return buffer_.join ""
