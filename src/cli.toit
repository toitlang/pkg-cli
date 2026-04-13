// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import log
import system

import .cache
import .completion_
import .completion-scripts_
import .config
import .help-generator_
import .options_
import .parser_
import .path_
import .utils_
import .ui

export Ui
export Cache FileStore DirectoryStore
export Config
export CompletionCandidate CompletionContext
export Option OptionString OptionEnum OptionInt OptionPatterns OptionPath
export OptionInFile OptionOutFile OptionUuid Flag
export InFile OutFile

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

  The $completion-as-flag parameter controls whether shell completion is exposed as a
    `--generate-completion` flag or a `completion` subcommand. If null (the default),
    commands with subcommands get a subcommand, and commands without get a flag.
  */
  run arguments/List -> none
      --invoked-command=system.program-name
      --cli/Cli?=null
      --add-ui-help/bool=(not cli)
      --add-completion/bool=true
      --completion-as-flag/bool?=null:
    added-completion-flag := false
    if add-completion:
      added-completion-flag = add-completion-bootstrap_
          --program-path=invoked-command
          --as-flag=completion-as-flag

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

  If $as-flag is null, the choice is automatic: commands with subcommands get a
    "completion" subcommand, commands without get a "--generate-completion" flag.
  If $as-flag is true, a "--generate-completion" flag is always used.
  If $as-flag is false, a "completion" subcommand is always used.

  Returns true if the "--generate-completion" flag was added.
  */
  add-completion-bootstrap_ --program-path/string --as-flag/bool?=null -> bool:
    // Don't add if the user already has a "completion" subcommand.
    if find-subcommand_ "completion": return false
    // Don't add if the user already has a "--generate-completion" option.
    options_.do: | opt/Option |
      if opt.name == "generate-completion": return false

    use-flag/bool := ?
    if as-flag != null:
      use-flag = as-flag
    else:
      // Auto: use a subcommand if there are subcommands, otherwise a flag.
      use-flag = subcommands_.is-empty

    if use-flag:
      add-completion-flag_
      return true

    add-completion-subcommand_ --program-path=program-path
    return false

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
A command that groups two alternative dispatch paths: a set of named
  subcommands and a default command.

When arguments match a named subcommand, dispatch goes there. Otherwise
  the default command handles the arguments. Each command has its own
  independent options and rest arguments — there is no option inheritance
  between the two.

This is useful for commands like `toit` which accept both
  subcommands (`toit run`, `toit compile`) and direct file arguments
  (`toit foo.toit`).

A $CommandGroup can be used anywhere a $Command can — including as a
  nested subcommand.

The help output shows a combined usage section followed by separate
  titled sections for each alternative:

  ```
  <top-level help>

  Usage:
    app <source> [<arg>...]
    app <command> [<options>]

  <default-title>:
  <help for default command>

  <commands-title>:
  <help for commands command>
  ```
*/
class CommandGroup extends Command:
  /** The command used when no named subcommand matches. Must have a run callback. */
  default_/Command

  /** Title shown in help above the default command's section. */
  default-title_/string

  /** The command that holds the named subcommands. Must not have a run callback. */
  commands_/Command

  /** Title shown in help above the commands section. */
  commands-title_/string

  /**
  Constructs a new command group.

  The $default command handles arguments that don't match any named subcommand.
    It must have a run callback.

  The $commands command holds the named subcommands. It must not have a run callback
    and must have at least one subcommand.
  */
  constructor name/string
      --help/string?=null
      --examples/List=[]
      --aliases/List=[]
      --hidden/bool=false
      --default/Command
      --default-title/string="Default"
      --commands/Command
      --commands-title/string="Commands":
    if not default.run-callback_:
      throw "The default command must have a run callback."
    if commands.run-callback_:
      throw "The commands command must not have a run callback."
    default_ = default
    default-title_ = default-title
    commands_ = commands
    commands-title_ = commands-title
    super.private name
        --help=help
        --examples=examples
        --aliases=aliases
        --subcommands=commands.subcommands_
        --hidden=hidden
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
