// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import .cli
import .help_generator_

class Parser_:
  ui_/Ui
  invoked_command_/string
  usage_on_error_/bool

  constructor --ui/Ui --invoked_command/string --usage_on_error=true:
    ui_ = ui
    invoked_command_ = invoked_command
    usage_on_error_ = usage_on_error

  fatal path/List str/string:
    ui_.print "Error: $str"
    if usage_on_error_:
      ui_.print ""
      help_command_ path [] --invoked_command=invoked_command_ --ui=ui_
    ui_.abort
    unreachable

  parse root_command/Command arguments --for_help_example/bool=false -> Parsed:
    path := []
    // Populate the options from the default values or empty lists (for multi-options)
    options := {:}

    seen_options := {}
    all_named_options := {:}
    all_short_options := {:}

    add_option := : | option/Option argument/string |
      if option.is_multi:
        values := option.should_split_commas ? argument.split "," : [argument]
        parsed := values.map: option.parse it --for_help_example=for_help_example
        options[option.name].add_all parsed
      else if seen_options.contains option.name:
        fatal path "Option was provided multiple times: $option.name"
      else:
        value := option.parse argument --for_help_example=for_help_example
        options[option.name] = value

      seen_options.add option.name

    create_help := : | arguments/List |
      help_command := Command "help" --run=::
        help_command_ path arguments --invoked_command=invoked_command_ --ui=ui_
      Parsed.private_ [help_command] {:} {}

    command/Command? := null
    set_command := : | new_command/Command |
      new_command.options.do: | option/Option |
        all_named_options[option.name] = option
        if option.short_name: all_short_options[option.short_name] = option

      // The rest options are only allowed for the last command.
      (new_command.options + new_command.rest).do: | option/Option |
        if option.is_multi:
          options[option.name] = []
        else:
          options[option.name] = option.default

      command = new_command
      path.add command

    set_command.call root_command

    index := 0
    while index < arguments.size:
      argument := arguments[index++]
      if argument == "--":
        break  // We're done!

      if argument.starts_with "--":
        value := null
        // Get the option name.
        split := argument.index_of "="
        name := (split < 0) ? argument[2..] : argument[2..split]
        if split >= 0: value = argument[split + 1 ..]

        is_inverted := false
        if name.starts_with "no-":
          is_inverted = true
          name = name[3..]

        option := all_named_options.get name
        if not option:
          if name == "help" and not is_inverted: return create_help.call []
          fatal path "Unknown option: --$name"

        if option.is_flag and value != null:
          fatal path "Cannot specify value for boolean flag --$name."
        if option.is_flag:
          value = is_inverted ? "false" : "true"
        else if is_inverted:
          fatal path "Cannot invert non-boolean flag --$name."
        if value == null:
          if index >= arguments.size:
            fatal path "Option --$name requires an argument."
          value = arguments[index++]

        add_option.call option value

      else if argument.starts_with "-":
        // Compute the option and the effective name. We allow short form prefixes to have
        // the value encoded in the same argument like -s"123 + 345", so we have to search
        // for prefixes.
        for i := 1; i < argument.size; :
          option_length := 1
          short_name := null
          option := null
          while i + option_length <= argument.size:
            short_name = argument[i..i + option_length]
            option = all_short_options.get short_name
            if option: break
            option_length++

          if not option:
            if short_name == "h": return create_help.call []
            fatal path "Unknown option: -$short_name"

          i += option_length

          if option is Flag:
            add_option.call option "true"
          else:
            if i < argument.size:
              add_option.call option argument[i ..]
              break
            else:
              if index >= arguments.size:
                fatal path "Option -$short_name requires an argument."
              add_option.call option arguments[index++]
              break

      else if not command.run_callback:
        subcommand := command.find_subcommand_ argument
        if not subcommand:
          if argument == "help" and command == root_command:
            // Special case for the help command.
            return create_help.call arguments[index..]

          fatal path "Unknown command: $argument"
        set_command.call subcommand

      else:
        // Make the current argument available as rest option.
        index--
        break

    all_named_options.do: | name/string option/Option |
      if option.is_required and not seen_options.contains name:
        fatal path "Required option $name is missing."

    command.rest.do: | rest_option/Option |
      if rest_option.is_required and index >= arguments.size:
        fatal path "Missing required rest argument: '$rest_option.name'."
      if index >= arguments.size: continue.do

      if rest_option.is_multi:
        while index < arguments.size:
          add_option.call rest_option arguments[index++]
      else:
        add_option.call rest_option arguments[index++]

    if index < arguments.size:
      fatal path "Unexpected rest argument: '$arguments[index]'."

    if not command.run_callback:
      fatal path "Missing subcommand."

    return Parsed.private_ path options seen_options
