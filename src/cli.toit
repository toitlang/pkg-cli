// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import fs
import host.directory
import host.file
import host.pipe
import io
import log
import uuid show Uuid
import system

import .cache
import .completion_
import .completion-scripts_
import .config
import .help-generator_
import .parser_
import .path_
import .utils_
import .ui

export Ui
export Cache FileStore DirectoryStore
export Config

/**
Shells for which $Command can generate completion scripts.
*/
COMPLETION-SHELLS_ ::= ["bash", "zsh", "fish", "powershell"]

/**
Returns the completion script for the given $shell.

The $program-path is baked into the script and used to re-invoke the
  binary at completion time.
*/
completion-script-for-shell_ --shell/string --program-path/string -> string:
  if shell == "bash": return bash-completion-script_ --program-path=program-path
  if shell == "zsh": return zsh-completion-script_ --program-path=program-path
  if shell == "fish": return fish-completion-script_ --program-path=program-path
  if shell == "powershell": return powershell-completion-script_ --program-path=program-path
  unreachable

/**
Scans $arguments for a "--generate-completion <shell>" or
  "--generate-completion=<shell>" occurrence with a known shell value.

Returns the shell name if found, null otherwise.

Unknown or missing values are ignored, so that the normal parser can
  report them with its standard error machinery.
*/
find-generate-completion-arg_ arguments/List -> string?:
  prefix := "--generate-completion="
  for i := 0; i < arguments.size; i++:
    arg/string := arguments[i]
    value/string? := null
    if arg == "--generate-completion":
      if i + 1 < arguments.size: value = arguments[i + 1]
    else if arg.starts-with prefix:
      value = arg[prefix.size..]
    if value and (COMPLETION-SHELLS_.contains value):
      return value
  return null

/**
An object giving access to common operations for CLI programs.

If no ui is given uses $Ui.human.
*/
interface Cli:
  constructor
      name/string
      --ui/Ui?=null
      --cache/Cache?=null
      --config/Config?=null:
    if not ui: ui = Ui.human
    return Cli_ name --ui=ui --cache=cache --config=config

  /**
  The name of the application.

  Used to find configurations and caches.
  */
  name -> string

  /**
  The UI object to use for this application.

  Output should be written to this object.
  */
  ui -> Ui

  /** The cache object for this application. */
  cache -> Cache

  /** The configuration object for this application. */
  config -> Config

  /**
  Returns a new UI object based on the given arguments.

  All non-null arguments are used to create the UI object. If an argument is null, the
    current value is used.
  */
  with -> Cli
      --name/string?=null
      --ui/Ui?=null
      --cache/Cache?=null
      --config/Config?=null

/**
An object giving access to common operations for CLI programs.
*/
class Cli_ implements Cli:
  /**
  The name of the application.

  Used to find configurations and caches.
  */
  name/string

  cache_/Cache? := null
  config_/Config? := null

  /**
  The UI object to use for this application.

  Output should be written to this object.
  */
  ui/Ui

  constructor .name --.ui --cache/Cache? --config/Config?:
    cache_ = cache
    config_ = config

  /** The cache object for this application. */
  cache -> Cache:
    if not cache_: cache_ = Cache --app-name=name
    return cache_

  /** The configuration object for this application. */
  config -> Config:
    if not config_: config_ = Config --app-name=name
    return config_

  with -> Cli
      --name/string?=null
      --ui/Ui?=null
      --cache/Cache?=null
      --config/Config?=null:
    return Cli_
        name or this.name
        --ui=ui or this.ui
        --cache=cache or cache_
        --config=config or config_

/**
A command.

The main program is a command, and so are all subcommands.
*/
class Command:
  /**
  The name of the command.
  The name of the root command is used as application name for the $Cli.
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

  The $run callback is invoked when the command is executed. It is given an
    $Invocation object. If $run is null, then at least one subcommand must be added
    to this command.
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
    path := Path this --invoked-command=invoked-command
    generator := HelpGenerator path
    generator.build-all
    return generator.to-string

  /**
  The short help string of this command.

  This is the first paragraph of the help string.
  */
  short-help -> string:
    if help := short-help_:
      return help
    if long-help := help_:
      // Take the first paragraph (potentially multiple lines) of the long help.
      paragraph-index := long-help.index-of "\n\n"
      if paragraph-index == -1:
        return long-help.trim
      return long-help[..paragraph-index].trim
    return ""

  /** Returns the usage string of this command. */
  usage --invoked-command/string=system.program-name -> string:
    path := Path this --invoked-command=invoked-command
    generator := HelpGenerator path
    generator.build-usage --as-section=false
    return generator.to-string

  /**
  Runs this command.

  Parses the given $arguments and then invokes the command or one of its subcommands
    with the $Invocation output.

  The $invoked-command is used only for the usage message in case of an
    error. It defaults to $system.program-name.

  If no $cli is given, the arguments are parsed for `--verbose`, `--verbosity-level` and
    `--output-format` to create the appropriate UI object. If a $cli object is given,
    then these arguments are ignored.

  The $add-ui-help flag is used to determine whether to include help for `--verbose`, ...
    in the help output. By default it is active if no $cli is provided.
  */
  run arguments/List -> none
      --invoked-command=system.program-name
      --cli/Cli?=null
      --add-ui-help/bool=(not cli)
      --add-completion/bool=true:
    added-completion-flag := false
    if add-completion:
      added-completion-flag = add-completion-bootstrap_
          --program-path=invoked-command

    // Handle __complete requests before any other processing.
    if add-completion and not arguments.is-empty and arguments[0] == "__complete":
      if add-ui-help: add-ui-options_
      completion-args := arguments[1..]
      if not completion-args.is-empty and completion-args[0] == "--":
        completion-args = completion-args[1..]
      result := complete_ this completion-args
      result.candidates.do: | candidate/CompletionCandidate_ |
        print candidate.to-string
      if result.extensions and not result.extensions.is-empty:
        print ":$result.directive:$(result.extensions.join ",")"
      else:
        print ":$result.directive"
      return

    // Handle --generate-completion before any other processing, so that
    //   required rest arguments and run callbacks are skipped.
    if added-completion-flag:
      shell := find-generate-completion-arg_ arguments
      if shell:
        print (completion-script-for-shell_ --shell=shell --program-path=invoked-command)
        return

    if not cli:
      ui := create-ui-from-args_ arguments
      log.set-default (ui.logger --name=name)
      if add-ui-help:
        add-ui-options_
      cli = Cli_ name --ui=ui --cache=null --config=null
    parser := Parser_ --invoked-command=invoked-command
    parser.parse this arguments: | path/Path parameters/Parameters |
      invocation := Invocation.private_ cli path.commands parameters
      invocation.command.run-callback_.call invocation

  /**
  Adds a bootstrap mechanism for shell completions.

  If the command has no run callback, a "completion" subcommand is added.
  Otherwise, a "--generate-completion" option is added to the root command.

  Returns true if the "--generate-completion" flag was added.
  */
  add-completion-bootstrap_ --program-path/string -> bool:
    // Don't add if the user already has a "completion" subcommand.
    if find-subcommand_ "completion": return false
    // Don't add if the user already has a "--generate-completion" option.
    options_.do: | opt/Option |
      if opt.name == "generate-completion": return false

    if not run-callback_:
      add-completion-subcommand_ --program-path=program-path
      return false

    // The root has a run callback, so we can't add a subcommand. Fall back
    //   to a "--generate-completion" flag.
    add-completion-flag_
    return true

  add-completion-flag_:
    options_ = options_.copy
    options_.add
        OptionEnum "generate-completion" COMPLETION-SHELLS_
            --type="shell"
            --help="Print a shell completion script (bash, zsh, fish, powershell) to stdout and exit."

  add-completion-subcommand_ --program-path/string:
    prog-name := basename_ program-path
    completion-command := Command "completion"
        --help="""
          Generate shell completion scripts.

          To enable completions, add the appropriate command to your shell
            configuration:

            Bash (~/.bashrc):
              source <($program-path completion bash)

            Zsh (~/.zshrc):
              source <($program-path completion zsh)

            Fish (~/.config/fish/config.fish):
              $program-path completion fish | source

          Alternatively, install the script to the system completion directory
            so it loads automatically for all sessions:

            Bash:
              $program-path completion bash > /etc/bash_completion.d/$prog-name

            Zsh:
              $program-path completion zsh > \$fpath[1]/_$prog-name

            Fish:
              $program-path completion fish > ~/.config/fish/completions/$(prog-name).fish

            PowerShell:
              $program-path completion powershell >> \$PROFILE"""
        --rest=[
          OptionEnum "shell" COMPLETION-SHELLS_
              --help="The shell to generate completions for."
              --required,
        ]
        --run=:: | invocation/Invocation |
          shell := invocation["shell"]
          print (completion-script-for-shell_ --shell=shell --program-path=program-path)
    subcommands_.add completion-command

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
        ["human", "plain", "json"]
        --help="Specify the format used when printing to the console."
        --default="human"
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
  Returns a shell completion script for this command.

  The $shell must be one of "bash", "zsh", or "fish".
  The $program-path is the path to the executable. The basename of this path
    is used to register the completion with the shell.
  */
  completion-script --shell/string --program-path/string=name -> string:
    if shell == "bash":
      return bash-completion-script_ --program-path=program-path
    if shell == "zsh":
      return zsh-completion-script_ --program-path=program-path
    if shell == "fish":
      return fish-completion-script_ --program-path=program-path
    throw "Unknown shell: $shell. Supported shells: bash, zsh, fish."

  /**
  Checks this command and all subcommands for errors.

  If an error is found, an exception is thrown with a message describing the error.

  Typically, a call to this method is added to the program's main function in an
    assert block.
  */
  check --invoked-command=system.program-name:
    path := Path this --invoked-command=invoked-command
    check_ --path=path --invoked-command=invoked-command

  are-prefix-of-each-other_ str1/string str2/string -> bool:
    m := min str1.size str2.size
    return str1[..m] == str2[..m]

  /**
  Checks this command and all subcommands.
  The $path, a list of strings, provides the sequence that was used to reach this command.
  The $outer-long-options and $outer-short-options are the options that are
    available through supercommands.
  */
  check_ --path/Path --invoked-command/string --outer-long-options/Set={} --outer-short-options/Set={}:
    examples_.do: it as Example
    aliases_.do: it as string

    long-options := {}
    short-options := {}
    options_.do: | option/Option |
      if long-options.contains option.name:
        throw "Ambiguous option of '$path.to-string': --$option.name."
      if outer-long-options.contains option.name:
        throw "Ambiguous option of '$path.to-string': --$option.name conflicts with global option."
      long-options.add option.name

      if option.short-name:
        if (short-options.any: are-prefix-of-each-other_ it option.short-name):
          throw "Ambiguous option of '$path.to-string': -$option.short-name."
        if (outer-short-options.any: are-prefix-of-each-other_ it option.short-name):
          throw "Ambiguous option of '$path.to-string': -$option.short-name conflicts with global option."
        short-options.add option.short-name

    have-seen-optional-rest := false
    for i := 0; i < rest_.size; i++:
      option/Option := rest_[i]
      if option.is-multi and not i == rest_.size - 1:
        throw "Multi-option '$option.name' of '$path.to-string' must be the last rest argument."
      if long-options.contains option.name:
        throw "Rest name '$option.name' of '$path.to-string' already used."
      if outer-long-options.contains option.name:
        throw "Rest name '$option.name' of '$path.to-string' already a global option."
      if have-seen-optional-rest and option.is-required:
        throw "Required rest argument '$option.name' of '$path.to-string' cannot follow optional rest argument."
      if option.is-hidden:
        throw "Rest argument '$option.name' of '$path.to-string' cannot be hidden."
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
          throw "Ambiguous subcommand of '$path.to-string': '$name'."
        subnames.add name

      command.check_
          --path=(path + command)
          --invoked-command=invoked-command
          --outer-long-options=outer-long-options
          --outer-short-options=outer-short-options

    // We allow a command with a run callback if all subcommands are hidden.
    // As such, we could also allow commands without either. If desired, it should be
    // safe to remove the following check.
    if subcommands_.is-empty and not run-callback_:
      throw "Command '$path.to-string' has no subcommands and no run callback."

    if not examples_.is-empty:
      generator := HelpGenerator path
      examples_.do: | example/Example |
        generator.build-example_ example --example-path=path

  find-subcommand_ name/string -> Command?:
    subcommands_.do: | command/Command |
      if command.name == name or command.aliases_.contains name:
        return command
    return null

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
class Invocation:
  /**
  The $Cli object representing this application.

  It is common to pass this object to other functions and libraries.
  */
  cli/Cli

  /**
  A list of $Command objects, representing the commands that were given on the command line.
  The first command is the root command, the last command is the command that should be executed.
  */
  path/List

  /**
  The parameters passed to the command.
  */
  parameters/Parameters

  /**
  Constructors a new invocation object.
  */
  constructor.private_ .cli .path .parameters:

  /**
  The command that should be executed.
  */
  command -> Command: return path.last

  /**
  Returns the value of the option with the given $name.
  The $name must be an option of the command or one of its super commands.

  If the given $name is in snake_case, it is automatically converted
    to kebab-case.

  This method is a shortcut for $parameters[name] ($Parameters.[]).
  */
  operator[] name/string -> any:
    return parameters[name]

/**
The parameters passed to the command.
*/
class Parameters:
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
  Builds a new parameters object.
  */
  constructor.private_ .options_ .seen-options_:

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
