// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import .cli
import .help-generator_
import .utils_

class Parser_:
  ui_/Ui
  invoked-command_/string
  usage-on-error_/bool

  constructor --ui/Ui --invoked-command/string --usage-on-error=true:
    ui_ = ui
    invoked-command_ = invoked-command
    usage-on-error_ = usage-on-error

  fatal path/List str/string:
    ui_.print "Error: $str"
    if usage-on-error_:
      ui_.print ""
      help-command_ path [] --invoked-command=invoked-command_ --ui=ui_
    ui_.abort
    unreachable

  parse root-command/Command arguments --for-help-example/bool=false -> Parsed:
    path := []
    // Populate the options from the default values or empty lists (for multi-options)
    options := {:}

    seen-options := {}
    all-named-options := {:}
    all-short-options := {:}

    add-option := : | option/Option argument/string |
      if option.is-multi:
        values := option.should-split-commas ? argument.split "," : [argument]
        parsed := values.map: option.parse it --for-help-example=for-help-example
        options[option.name].add-all parsed
      else if seen-options.contains option.name:
        fatal path "Option was provided multiple times: $option.name"
      else:
        value := option.parse argument --for-help-example=for-help-example
        options[option.name] = value

      seen-options.add option.name

    create-help := : | arguments/List |
      help-command := Command "help" --run=::
        help-command_ path arguments --invoked-command=invoked-command_ --ui=ui_
      Parsed.private_ [help-command] {:} {}

    command/Command? := null
    set-command := : | new-command/Command |
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
      path.add command

    set-command.call root-command

    rest := []

    index := 0
    while index < arguments.size:
      argument := arguments[index++]
      if argument == "--":
        rest.add-all arguments[index ..]
        break  // We're done!

      if argument.starts-with "--":
        value := null
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
          if name == "help" and not is-inverted: return create-help.call []
          fatal path "Unknown option: --$name"

        if option.is-flag and value != null:
          fatal path "Cannot specify value for boolean flag --$name."
        if option.is-flag:
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
            if short-name == "h": return create-help.call []
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
            return create-help.call arguments[index..]

          fatal path "Unknown command: $argument"
        set-command.call subcommand

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

    return Parsed.private_ path options seen-options
