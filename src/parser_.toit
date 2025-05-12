// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import .cli
import .help-generator_
import .path_
import .ui
import .utils_
import host.pipe

class StderrPrinter_ extends HumanPrinterBase:
  needs-structured --kind/int -> bool: return false
  emit-structured --kind/int o/any: unreachable
  print_ o:
    pipe.stderr.out.write "$o\n"

test-ui_/Ui? := null

class Parser_:
  invoked-command_/string
  for-help-example_/bool

  constructor --invoked-command/string --for-help-example/bool=false:
    invoked-command_ = invoked-command
    for-help-example_ = for-help-example

  /**
  Reports and error and aborts the program.

  The program was called with wrong arguments.
  */
  fatal path/Path str/string:
    if for-help-example_:
      throw str

    // If there is a test-ui_ use it.
    // Otherwise, ignore the ui that was determined through the command line and
    // print the usage on stderr, followed by an exit 1.
    ui := test-ui_ or (Ui --level=Ui.QUIET-LEVEL --printer=StderrPrinter_)
    ui.emit --error str
    help-command_ path [] --ui=ui
    ui.abort
    unreachable

  /**
  Parses the command line $arguments and calls the given $block with
    the result.

  Calls the $block with two arguments:
  - The path (a list of $Command) to the command that was invoked.
  - The $Parameters that were parsed.
  */
  parse root-command/Command arguments/List [block] -> none:
    path := Path root-command --invoked-command=invoked-command_
    // Populate the options from the default values or empty lists (for multi-options)
    options := {:}

    seen-options := {}
    all-named-options := {:}
    all-short-options := {:}

    add-option := : | option/Option argument/string |
      if option.is-multi:
        values := option.should-split-commas ? argument.split "," : [argument]
        parsed := values.map: option.parse it --for-help-example=for-help-example_
        options[option.name].add-all parsed
      else if seen-options.contains option.name:
        fatal path "Option was provided multiple times: $option.name"
      else:
        value := option.parse argument --for-help-example=for-help-example_
        options[option.name] = value

      seen-options.add option.name

    return-help := : | arguments/List |
      help-command := Command "help" --run=:: | app/Invocation |
        help-command_ path arguments --ui=app.cli.ui
      help-path := Path help-command --invoked-command=invoked-command_
      block.call help-path (Parameters.private_ {:} {})
      return

    command/Command? := null
    set-command := : | new-command/Command add-to-path/bool |
      new-command.options_.do: | option/Option |
        all-named-options[option.name] = option
        if option.short-name: all-short-options[option.short-name] = option

      // The rest options are only allowed for the last command.
      (new-command.options_ + new-command.rest_).do: | option/Option |
        if option.is-multi:
          options[option.name] = []
        else:
          options[option.name] = option.default

      command = new-command
      if add-to-path: path += command

    set-command.call root-command false

    rest := []

    index := 0
    while index < arguments.size:
      argument/string := arguments[index++]
      if argument == "--":
        rest.add-all arguments[index ..]
        break  // We're done!

      if argument.starts-with "--":
        value/string? := null
        // Get the option name.
        split := argument.index-of "="
        name := (split < 0) ? argument[2..] : argument[2..split]
        if split >= 0: value = argument[split + 1 ..]

        is-inverted := false
        if name.starts-with "no-":
          is-inverted = true
          name = name[3..]

        kebab-name := to-kebab name

        option := all-named-options.get kebab-name
        if not option:
          if name == "help" and not is-inverted: return-help.call []
          fatal path "Unknown option: --$name"

        if option.is-flag and value != null:
          if is-inverted:
            fatal path "Cannot specify value for inverted boolean flag --$name."
          if value != "true" and value != "false":
            fatal path "Invalid value for boolean flag '$name': '$value'. Valid values are: true, false."
        else if option.is-flag and value == null:
          value = is-inverted ? "false" : "true"
        else if is-inverted:
          fatal path "Cannot invert non-boolean flag --$name."
        if value == null:
          if index >= arguments.size:
            fatal path "Option --$name requires an argument."
          value = arguments[index++]

        add-option.call option value

      else if argument.starts-with "-":
        // Compute the option and the effective name. We allow short form prefixes to have
        // the value encoded in the same argument like -s"123 + 345", so we have to search
        // for prefixes.
        for i := 1; i < argument.size; :
          option-length := 1
          short-name := null
          option := null
          while i + option-length <= argument.size:
            short-name = argument[i..i + option-length]
            option = all-short-options.get short-name
            if option: break
            option-length++

          if not option:
            if short-name == "h": return-help.call []
            fatal path "Unknown option: -$short-name"

          i += option-length

          if option is Flag:
            add-option.call option "true"
          else:
            if i < argument.size:
              add-option.call option argument[i ..]
              break
            else:
              if index >= arguments.size:
                fatal path "Option -$short-name requires an argument."
              add-option.call option arguments[index++]
              break

      else if not command.run-callback_:
        subcommand := command.find-subcommand_ argument
        if not subcommand:
          if argument == "help" and command == root-command:
            // Special case for the help command.
            return-help.call arguments[index..]

          fatal path "Unknown command: $argument"
        set-command.call subcommand true

      else:
        rest.add argument

    all-named-options.do: | name/string option/Option |
      if option.is-required and not seen-options.contains name:
        fatal path "Required option $name is missing."

    rest-index := 0
    command.rest_.do: | rest-option/Option |
      if rest-option.is-required and rest-index >= rest.size:
        fatal path "Missing required rest argument: '$rest-option.name'."
      if rest-index >= rest.size: continue.do

      if rest-option.is-multi:
        while rest-index < rest.size:
          add-option.call rest-option rest[rest-index++]
      else:
        add-option.call rest-option rest[rest-index++]

    if rest-index < rest.size:
      fatal path "Unexpected rest argument: '$rest[rest-index]'."

    if not command.run-callback_:
      fatal path "Missing subcommand."

    block.call path (Parameters.private_ options seen-options)
