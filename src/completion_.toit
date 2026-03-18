// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import .cli
import .utils_

/**
The directive indicating default shell behavior.
*/
DIRECTIVE-DEFAULT_ ::= 0

/**
The directive indicating that the shell should not fall back to file completion.
*/
DIRECTIVE-NO-FILE-COMPLETION_ ::= 1

/**
The directive indicating that the shell should fall back to file completion.
*/
DIRECTIVE-FILE-COMPLETION_ ::= 4

/**
A completion candidate with a value and an optional description.
*/
class CompletionCandidate_:
  value/string
  description/string?

  constructor .value --.description=null:

  to-string -> string:
    if description: return "$value\t$description"
    return value

  stringify -> string:
    return to-string

/**
The result of a completion request.

Contains a list of $candidates and a $directive that tells the shell
  how to handle the results.
*/
class CompletionResult_:
  candidates/List
  directive/int

  constructor .candidates --.directive=DIRECTIVE-DEFAULT_:

/**
Computes completion candidates for the given $arguments.

Walks the command tree starting from $root, determines the completion
  context, and returns appropriate candidates.

The $arguments is the list of words the user has typed so far (everything
  before the cursor, split by the shell).
*/
complete_ root/Command arguments/List -> CompletionResult_:
  // Track the current command and accumulated options from all ancestor commands.
  current-command := root
  is-root := true
  all-named-options := {:}  // Map from kebab-name to Option.
  all-short-options := {:}  // Map from short-name to Option.
  seen-options := {:}  // Map from option name to list of values.

  add-options-for-command_ current-command all-named-options all-short-options

  past-dashdash := false
  // The option that is expecting a value (the previous arg was a non-flag option).
  pending-option/Option? := null
  // How many positional (rest) arguments have been consumed so far.
  positional-index := 0

  // Process all arguments except the last one (which is the word being completed).
  args-to-process := arguments.is-empty ? [] : arguments[..arguments.size - 1]

  args-to-process.size.repeat: | index/int |
    arg/string := args-to-process[index]

    if past-dashdash:
      // After --, everything is a rest argument. Track positional index.
      positional-index++
      continue.repeat

    if pending-option:
      // This argument is the value for the previous option.
      (seen-options.get pending-option.name --init=:[]).add arg
      pending-option = null
      continue.repeat

    if arg == "--":
      past-dashdash = true
      continue.repeat

    if arg.starts-with "--":
      split := arg.index-of "="
      name := (split < 0) ? arg[2..] : arg[2..split]
      if name.starts-with "no-": name = name[3..]
      kebab-name := to-kebab name
      option := all-named-options.get kebab-name
      if option:
        if split >= 0:
          // --option=value: option is fully provided.
          value := arg[split + 1..]
          (seen-options.get option.name --init=:[]).add value
        else if option.is-flag:
          (seen-options.get option.name --init=:[]).add "true"
        else:
          // Next argument is the value.
          pending-option = option
      continue.repeat

    if arg.starts-with "-":
      // Parse short options. They can be packed (-abc) and short names
      // can be multi-character, so we search for matching prefixes like
      // the parser does.
      for i := 1; i < arg.size; :
        option-length := 1
        option/Option? := null
        while i + option-length <= arg.size:
          short-name := arg[i..i + option-length]
          option = all-short-options.get short-name
          if option: break
          option-length++
        if not option:
          // Unknown short option; stop parsing this arg.
          break
        i += option-length
        if option.is-flag:
          if not option.is-multi:
            (seen-options.get option.name --init=:[]).add "true"
        else:
          if i < arg.size:
            // Value is the rest of the argument (e.g., -oValue).
            value := arg[i..]
            (seen-options.get option.name --init=:[]).add value
          else:
            // Next argument is the value.
            pending-option = option
          break
      continue.repeat

    // Not an option — try to descend into a subcommand.
    if not current-command.run-callback_:
      subcommand := current-command.find-subcommand_ arg
      if subcommand:
        current-command = subcommand
        is-root = false
        positional-index = 0
        add-options-for-command_ current-command all-named-options all-short-options
    else:
      // It's a positional/rest argument.
      positional-index++

  // Now determine what to complete for the last argument (the word being typed).
  current-word := arguments.is-empty ? "" : arguments.last

  // If we were expecting a value for an option, complete that option's values.
  if pending-option:
    context := CompletionContext.private_
        --option=pending-option
        --command=current-command
        --seen-options=seen-options
        --prefix=current-word
    completions := pending-option.complete context
    directive := has-completer_ pending-option
        ? DIRECTIVE-NO-FILE-COMPLETION_
        : DIRECTIVE-FILE-COMPLETION_
    return CompletionResult_
        completions.map: to-candidate_ it
        --directive=directive

  // After --, only rest arguments (no option completions).
  if past-dashdash:
    return complete-rest_ current-command seen-options current-word --positional-index=positional-index

  // Completing an option value with --option=prefix.
  if current-word.starts-with "--" and (current-word.index-of "=") >= 0:
    split := current-word.index-of "="
    option-name := current-word[2..split]
    if option-name.starts-with "no-": option-name = option-name[3..]
    prefix := current-word[split + 1..]
    kebab-name := to-kebab option-name
    option := all-named-options.get kebab-name
    if option:
      context := CompletionContext.private_
          --option=option
          --command=current-command
          --seen-options=seen-options
          --prefix=prefix
      completions := option.complete context
      // Prepend the --option= part to each candidate.
      option-prefix := current-word[..split + 1]
      candidates := completions.map: | c/CompletionCandidate |
        CompletionCandidate_ "$option-prefix$c.value" --description=c.description
      directive := has-completer_ option
          ? DIRECTIVE-NO-FILE-COMPLETION_
          : DIRECTIVE-FILE-COMPLETION_
      return CompletionResult_ candidates --directive=directive
    return CompletionResult_ [] --directive=DIRECTIVE-DEFAULT_

  // Completing an option name.
  if current-word.starts-with "-":
    return complete-option-names_ current-command all-named-options seen-options current-word

  // Completing a subcommand or rest argument.
  if not current-command.run-callback_:
    return complete-subcommands_ current-command all-named-options seen-options current-word --is-root=is-root
  else:
    return complete-rest_ current-command seen-options current-word --positional-index=positional-index

/**
Adds the options of the given $command to the option maps.
*/
add-options-for-command_ command/Command named-options/Map short-options/Map:
  command.options_.do: | option/Option |
    named-options[option.name] = option
    if option.short-name: short-options[option.short-name] = option

/**
Completes option names for the given $current-word.
*/
complete-option-names_ command/Command all-named-options/Map seen-options/Map current-word/string -> CompletionResult_:
  candidates := []

  all-named-options.do: | name/string option/Option |
    if option.is-hidden: continue.do
    // Skip already-provided non-multi options.
    if (seen-options.contains name) and not option.is-multi: continue.do

    long-name := "--$name"
    if long-name.starts-with current-word:
      candidates.add (CompletionCandidate_ long-name --description=option.help)

    // Suggest --no-name for flags.
    if option.is-flag:
      no-name := "--no-$name"
      if no-name.starts-with current-word:
        candidates.add (CompletionCandidate_ no-name --description=option.help)

    if option.short-name:
      short := "-$option.short-name"
      if short.starts-with current-word:
        candidates.add (CompletionCandidate_ short --description=option.help)

  // Also suggest --help / -h.
  if "--help".starts-with current-word:
    candidates.add (CompletionCandidate_ "--help" --description="Show help for this command.")
  if "-h".starts-with current-word:
    candidates.add (CompletionCandidate_ "-h" --description="Show help for this command.")

  return CompletionResult_ candidates --directive=DIRECTIVE-NO-FILE-COMPLETION_

/**
Completes subcommand names for the given $current-word.

Also includes option names since they can be interleaved with subcommands.
Only suggests "help" when $is-root is true, matching the parser behavior.
Only suggests option names when $current-word starts with "-".
*/
complete-subcommands_ command/Command all-named-options/Map seen-options/Map current-word/string --is-root/bool -> CompletionResult_:
  candidates := []

  command.subcommands_.do: | sub/Command |
    if sub.is-hidden_: continue.do
    if sub.name.starts-with current-word:
      candidates.add (CompletionCandidate_ sub.name --description=sub.short-help)
    sub.aliases_.do: | alias/string |
      if alias.starts-with current-word:
        candidates.add (CompletionCandidate_ alias --description=sub.short-help)

  // Only suggest "help" at the root level, matching the parser.
  if is-root and "help".starts-with current-word:
    candidates.add (CompletionCandidate_ "help" --description="Show help for a command.")

  // Only include option names when the user is typing an option (starts with "-").
  if current-word.starts-with "-":
    all-named-options.do: | name/string option/Option |
      if option.is-hidden: continue.do
      if (seen-options.contains name) and not option.is-multi: continue.do
      long-name := "--$name"
      if long-name.starts-with current-word:
        candidates.add (CompletionCandidate_ long-name --description=option.help)

    // Also suggest --help / -h.
    if "--help".starts-with current-word:
      candidates.add (CompletionCandidate_ "--help" --description="Show help for this command.")
    if "-h".starts-with current-word:
      candidates.add (CompletionCandidate_ "-h" --description="Show help for this command.")

  return CompletionResult_ candidates --directive=DIRECTIVE-NO-FILE-COMPLETION_

/**
Completes rest arguments.

Returns file completion directive since rest arguments are often file paths.
*/
complete-rest_ command/Command seen-options/Map current-word/string --positional-index/int=0 -> CompletionResult_:
  // If there are rest options with completion callbacks, use them.
  // Skip rest options that have already been consumed by earlier positional args.
  // Multi options absorb all remaining positionals, so we stop skipping once we
  // reach a multi option.
  skip := positional-index
  command.rest_.do: | option/Option |
    if skip > 0 and not option.is-multi:
      skip--
      continue.do
    context := CompletionContext.private_
        --option=option
        --command=command
        --seen-options=seen-options
        --prefix=current-word
    completions := option.complete context
    if not completions.is-empty:
      candidates := completions.map: to-candidate_ it
      return CompletionResult_ candidates --directive=DIRECTIVE-NO-FILE-COMPLETION_

  return CompletionResult_ [] --directive=DIRECTIVE-FILE-COMPLETION_

/**
Whether the given $option has meaningful completion support.

An option has a completer if it has a custom completion callback or
  if it provides built-in completion values (like enum values).
Options without either (like plain string/int options) don't have a
  completer, and should fall back to file completion.
*/
has-completer_ option/Option -> bool:
  return option.completion-callback_ != null
      or not option.options-for-completion.is-empty

/**
Converts a public $CompletionCandidate to an internal $CompletionCandidate_.
*/
to-candidate_ candidate/CompletionCandidate -> CompletionCandidate_:
  return CompletionCandidate_ candidate.value --description=candidate.description
