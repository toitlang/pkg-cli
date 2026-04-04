// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli
import cli.completion_ show *
import expect show *


main:
  test-empty-input
  test-subcommand-completion
  test-option-name-completion
  test-option-value-completion
  test-enum-completion
  test-flag-completion
  test-after-dashdash
  test-hidden-excluded
  test-alias-completion
  test-already-provided-excluded
  test-multi-still-suggested
  test-custom-completion-callback
  test-completion-context
  test-nested-subcommands
  test-rest-completion
  test-option-equals-value
  test-completion-with-descriptions
  test-help-only-at-root
  test-flags-hidden-without-dash-prefix
  test-option-path
  test-rest-positional-index
  test-rest-positional-index-after-dashdash
  test-rest-multi-not-skipped
  test-short-option-marks-seen
  test-short-option-pending-value
  test-packed-short-options
  test-custom-completer-no-file-fallback
  test-option-extensions
  test-help-completion
  test-help-gated-on-availability

test-empty-input:
  root := cli.Command "app"
      --subcommands=[
        cli.Command "serve" --help="Start a server." --run=:: null,
        cli.Command "build" --help="Build the project." --run=:: null,
      ]
  result := complete_ root [""]
  values := result.candidates.map: it.value
  expect (values.contains "serve")
  expect (values.contains "build")
  expect (values.contains "help")
  // Flags should NOT appear when prefix is empty (no "-" prefix).
  expect (not (values.contains "--help"))
  expect (not (values.contains "-h"))

test-subcommand-completion:
  root := cli.Command "app"
      --subcommands=[
        cli.Command "serve" --help="Start a server." --run=:: null,
        cli.Command "status" --help="Show status." --run=:: null,
        cli.Command "build" --help="Build the project." --run=:: null,
      ]
  // Complete with prefix "s".
  result := complete_ root ["s"]
  values := result.candidates.map: it.value
  expect (values.contains "serve")
  expect (values.contains "status")
  expect (not (values.contains "build"))

test-option-name-completion:
  root := cli.Command "app"
      --options=[
        cli.Option "output" --short-name="o" --help="Output path.",
        cli.Flag "verbose" --short-name="v" --help="Be verbose.",
      ]
      --run=:: null
  // Complete "--".
  result := complete_ root ["--"]
  values := result.candidates.map: it.value
  expect (values.contains "--output")
  expect (values.contains "--verbose")
  expect (values.contains "--no-verbose")
  expect (values.contains "--help")

  // Complete "-".
  result = complete_ root ["-"]
  values = result.candidates.map: it.value
  expect (values.contains "-o")
  expect (values.contains "-v")
  expect (values.contains "-h")

  // Complete "--ou".
  result = complete_ root ["--ou"]
  values = result.candidates.map: it.value
  expect (values.contains "--output")
  expect (not (values.contains "--verbose"))

test-option-value-completion:
  root := cli.Command "app"
      --options=[
        cli.OptionEnum "format" ["json", "text", "csv"] --help="Output format.",
        cli.Option "file" --help="Input file.",
      ]
      --run=:: null

  // After a non-flag option, complete its values.
  result := complete_ root ["--format", ""]
  values := result.candidates.map: it.value
  expect-equals 3 values.size
  expect (values.contains "json")
  expect (values.contains "text")
  expect (values.contains "csv")
  expect-equals DIRECTIVE-NO-FILE-COMPLETION_ result.directive

  // After a string option with no completions, expect file completion.
  result = complete_ root ["--file", ""]
  expect-equals 0 result.candidates.size
  expect-equals DIRECTIVE-FILE-COMPLETION_ result.directive

test-enum-completion:
  root := cli.Command "app"
      --options=[
        cli.OptionEnum "color" ["red", "green", "blue"] --help="Pick a color.",
      ]
      --run=:: null
  // Complete after --color.
  result := complete_ root ["--color", "r"]
  values := result.candidates.map: it.value
  // All enum values are returned; shell filters by prefix.
  expect (values.contains "red")
  expect (values.contains "green")
  expect (values.contains "blue")

test-flag-completion:
  root := cli.Command "app"
      --options=[
        cli.Flag "verbose" --help="Be verbose.",
      ]
      --run=:: null
  // Flags don't need value completion in normal flow since the parser
  // doesn't consume the next arg. But --verbose= should complete.
  result := complete_ root ["--verbose="]
  values := result.candidates.map: it.value
  expect (values.contains "--verbose=true")
  expect (values.contains "--verbose=false")

test-after-dashdash:
  root := cli.Command "app"
      --options=[
        cli.Option "output" --help="Output path.",
      ]
      --rest=[
        cli.Option "files" --multi --help="Input files.",
      ]
      --run=:: null
  // After --, no option completion.
  result := complete_ root ["--", ""]
  values := result.candidates.map: it.value
  expect (not (values.contains "--output"))
  expect-equals DIRECTIVE-FILE-COMPLETION_ result.directive

test-hidden-excluded:
  root := cli.Command "app"
      --options=[
        cli.Option "secret" --hidden --help="Secret option.",
        cli.Option "visible" --help="Visible option.",
      ]
      --subcommands=[
        cli.Command "hidden-cmd" --hidden --run=:: null,
        cli.Command "visible-cmd" --help="Visible command." --run=:: null,
      ]
  // Hidden options and commands should not appear.
  result := complete_ root [""]
  values := result.candidates.map: it.value
  expect (not (values.contains "--secret"))
  expect (not (values.contains "hidden-cmd"))
  expect (values.contains "visible-cmd")

  result = complete_ root ["--"]
  values = result.candidates.map: it.value
  expect (not (values.contains "--secret"))
  expect (values.contains "--visible")

test-alias-completion:
  root := cli.Command "app"
      --subcommands=[
        cli.Command "device" --aliases=["dev", "d"] --help="Device commands." --run=:: null,
      ]
  result := complete_ root [""]
  values := result.candidates.map: it.value
  expect (values.contains "device")
  expect (values.contains "dev")
  expect (values.contains "d")

  result = complete_ root ["de"]
  values = result.candidates.map: it.value
  expect (values.contains "device")
  expect (values.contains "dev")

test-already-provided-excluded:
  root := cli.Command "app"
      --options=[
        cli.Option "output" --help="Output path.",
        cli.Option "input" --help="Input path.",
      ]
      --run=:: null
  // After providing --output, it should not be suggested again.
  result := complete_ root ["--output", "foo", "--"]
  values := result.candidates.map: it.value
  expect (not (values.contains "--output"))
  expect (values.contains "--input")

test-multi-still-suggested:
  root := cli.Command "app"
      --options=[
        cli.Option "tag" --multi --help="Tags.",
      ]
      --run=:: null
  // Multi options should still be suggested after being provided.
  result := complete_ root ["--tag", "v1", "--"]
  values := result.candidates.map: it.value
  expect (values.contains "--tag")

test-custom-completion-callback:
  root := cli.Command "app"
      --options=[
        cli.Option "host" --help="Target host."
            --completion=:: | context/cli.CompletionContext |
              hosts := ["localhost", "staging.example.com", "prod.example.com"]
              (hosts.filter: it.starts-with context.prefix).map: cli.CompletionCandidate it,
      ]
      --run=:: null
  // Custom callback is called with the context.
  result := complete_ root ["--host", "local"]
  values := result.candidates.map: it.value
  expect-equals 1 values.size
  expect (values.contains "localhost")

  result = complete_ root ["--host", ""]
  values = result.candidates.map: it.value
  expect-equals 3 values.size

test-completion-context:
  // Verify that the completion context provides seen options.
  seen/Map? := null
  root := cli.Command "app"
      --options=[
        cli.Option "output" --help="Output path.",
        cli.Option "target" --help="Target."
            --completion=:: | context/cli.CompletionContext |
              seen = context.seen-options
              ["a", "b"].map: cli.CompletionCandidate it,
      ]
      --run=:: null
  result := complete_ root ["--output", "foo", "--target", ""]
  expect-not-null seen
  expect (seen.contains "output")
  expect-equals ["foo"] seen["output"]

test-completion-with-descriptions:
  root := cli.Command "app"
      --options=[
        cli.Option "device" --help="Device to use."
            --completion=:: | context/cli.CompletionContext |
              [
                cli.CompletionCandidate "abc-123" --description="My Phone",
                cli.CompletionCandidate "def-456" --description="My Laptop",
              ],
      ]
      --run=:: null
  result := complete_ root ["--device", ""]
  expect-equals 2 result.candidates.size
  // Check that descriptions are preserved.
  candidate := result.candidates.first
  expect-equals "abc-123" candidate.value
  expect-equals "My Phone" candidate.description

  // Also verify --device=prefix preserves descriptions.
  result = complete_ root ["--device=a"]
  expect-equals 2 result.candidates.size
  candidate = result.candidates.first
  expect-equals "--device=abc-123" candidate.value
  expect-equals "My Phone" candidate.description

test-nested-subcommands:
  root := cli.Command "app"
      --options=[
        cli.Flag "verbose" --help="Be verbose.",
      ]
      --subcommands=[
        cli.Command "device"
            --help="Device commands."
            --options=[
              cli.Option "name" --help="Device name.",
            ]
            --subcommands=[
              cli.Command "list" --help="List devices." --run=:: null,
              cli.Command "show" --help="Show device." --run=:: null,
            ],
      ]
  // After "device", complete its subcommands.
  result := complete_ root ["device", ""]
  values := result.candidates.map: it.value
  expect (values.contains "list")
  expect (values.contains "show")
  // Flags should NOT appear without "-" prefix.
  expect (not (values.contains "--verbose"))
  expect (not (values.contains "--name"))

  // But with "-" prefix, options should appear.
  result = complete_ root ["device", "-"]
  values = result.candidates.map: it.value
  expect (values.contains "--verbose")
  expect (values.contains "--name")
  expect (values.contains "--help")
  expect (values.contains "-h")

  // Complete "device l".
  result = complete_ root ["device", "l"]
  values = result.candidates.map: it.value
  expect (values.contains "list")
  expect (not (values.contains "show"))

test-rest-completion:
  root := cli.Command "app"
      --rest=[
        cli.OptionEnum "action" ["start", "stop", "restart"]
            --help="Action to perform.",
      ]
      --run=:: null
  // Rest arguments with completion should work.
  result := complete_ root [""]
  values := result.candidates.map: it.value
  expect (values.contains "start")
  expect (values.contains "stop")
  expect (values.contains "restart")

test-option-equals-value:
  root := cli.Command "app"
      --options=[
        cli.OptionEnum "format" ["json", "text"] --help="Output format.",
      ]
      --run=:: null
  // Complete --format=j.
  result := complete_ root ["--format=j"]
  values := result.candidates.map: it.value
  expect (values.contains "--format=json")
  expect (values.contains "--format=text")

test-help-only-at-root:
  root := cli.Command "app"
      --subcommands=[
        cli.Command "device"
            --help="Device commands."
            --subcommands=[
              cli.Command "list" --help="List devices." --run=:: null,
            ],
      ]
  // "help" should appear at root level.
  result := complete_ root [""]
  values := result.candidates.map: it.value
  expect (values.contains "help")

  // "help" should NOT appear after descending into a subcommand.
  result = complete_ root ["device", ""]
  values = result.candidates.map: it.value
  expect (not (values.contains "help"))
  expect (values.contains "list")

test-flags-hidden-without-dash-prefix:
  root := cli.Command "app"
      --options=[
        cli.Option "output" --help="Output path.",
      ]
      --subcommands=[
        cli.Command "serve" --help="Start a server." --run=:: null,
      ]
  // With empty prefix, flags should not appear.
  result := complete_ root [""]
  values := result.candidates.map: it.value
  expect (values.contains "serve")
  expect (not (values.contains "--output"))
  expect (not (values.contains "--help"))
  expect (not (values.contains "-h"))

  // With "-" prefix, flags should appear.
  result = complete_ root ["-"]
  values = result.candidates.map: it.value
  expect (values.contains "--output")
  expect (values.contains "--help")
  expect (values.contains "-h")
  // Subcommands should not appear when prefix starts with "-".
  expect (not (values.contains "serve"))

test-option-path:
  // OptionPath for files should use file-completion directive.
  root := cli.Command "app"
      --options=[
        cli.OptionPath "config" --help="Config file.",
      ]
      --run=:: null
  result := complete_ root ["--config", ""]
  expect-equals 0 result.candidates.size
  expect-equals DIRECTIVE-FILE-COMPLETION_ result.directive

  // OptionPath for directories should use directory-completion directive.
  root = cli.Command "app"
      --options=[
        cli.OptionPath "output-dir" --directory --help="Output directory.",
      ]
      --run=:: null
  result = complete_ root ["--output-dir", ""]
  expect-equals 0 result.candidates.size
  expect-equals DIRECTIVE-DIRECTORY-COMPLETION_ result.directive

  // OptionPath with --option=prefix should also use the correct directive.
  result = complete_ root ["--output-dir=foo"]
  expect-equals DIRECTIVE-DIRECTORY-COMPLETION_ result.directive

  // OptionPath type should reflect the directory flag.
  file-opt := cli.OptionPath "file" --help="A file."
  expect-equals "path" file-opt.type
  dir-opt := cli.OptionPath "dir" --directory --help="A dir."
  expect-equals "directory" dir-opt.type

test-rest-positional-index:
  root := cli.Command "app"
      --rest=[
        cli.OptionEnum "action" ["start", "stop", "restart"]
            --help="Action to perform.",
        cli.OptionEnum "target" ["dev", "staging", "prod"]
            --help="Target environment.",
      ]
      --run=:: null
  // With no prior positional args, should complete the first rest option.
  result := complete_ root [""]
  values := result.candidates.map: it.value
  expect (values.contains "start")
  expect (not (values.contains "dev"))

  // After providing the first positional, should complete the second rest option.
  result = complete_ root ["start", ""]
  values = result.candidates.map: it.value
  expect (not (values.contains "start"))
  expect (values.contains "dev")
  expect (values.contains "staging")
  expect (values.contains "prod")

test-rest-positional-index-after-dashdash:
  root := cli.Command "app"
      --rest=[
        cli.OptionEnum "action" ["start", "stop"]
            --help="Action to perform.",
        cli.OptionEnum "target" ["dev", "prod"]
            --help="Target environment.",
      ]
      --run=:: null
  // After -- and one positional, should complete the second rest option.
  result := complete_ root ["--", "start", ""]
  values := result.candidates.map: it.value
  expect (not (values.contains "start"))
  expect (values.contains "dev")
  expect (values.contains "prod")

test-rest-multi-not-skipped:
  root := cli.Command "app"
      --rest=[
        cli.OptionEnum "files" ["a.txt", "b.txt"] --multi
            --help="Input files.",
      ]
      --run=:: null
  // Multi rest options should still complete even after prior positionals.
  result := complete_ root ["a.txt", ""]
  values := result.candidates.map: it.value
  expect (values.contains "a.txt")
  expect (values.contains "b.txt")

test-short-option-marks-seen:
  root := cli.Command "app"
      --options=[
        cli.Option "output" --short-name="o" --help="Output path.",
        cli.Option "input" --short-name="i" --help="Input path.",
      ]
      --run=:: null
  // After providing -o with a value, --output should not be suggested again.
  result := complete_ root ["-o", "foo", "-"]
  values := result.candidates.map: it.value
  expect (not (values.contains "--output"))
  expect (not (values.contains "-o"))
  expect (values.contains "--input")
  expect (values.contains "-i")

test-short-option-pending-value:
  root := cli.Command "app"
      --options=[
        cli.OptionEnum "format" ["json", "text"] --short-name="f" --help="Format.",
      ]
      --run=:: null
  // After -f, the next word should complete the option's values.
  result := complete_ root ["-f", ""]
  values := result.candidates.map: it.value
  expect (values.contains "json")
  expect (values.contains "text")
  expect-equals DIRECTIVE-NO-FILE-COMPLETION_ result.directive

test-packed-short-options:
  root := cli.Command "app"
      --options=[
        cli.Flag "verbose" --short-name="v" --help="Be verbose.",
        cli.Option "output" --short-name="o" --help="Output path.",
        cli.Flag "force" --short-name="F" --help="Force.",
      ]
      --run=:: null
  // Packed flags: -vF should mark both as seen.
  result := complete_ root ["-vF", "--"]
  values := result.candidates.map: it.value
  expect (not (values.contains "--verbose"))
  expect (not (values.contains "--force"))
  expect (values.contains "--output")

  // Packed flag + value option: -vo should set pending for output.
  result = complete_ root ["-vo", "out.txt", "--"]
  values = result.candidates.map: it.value
  expect (not (values.contains "--verbose"))
  expect (not (values.contains "--output"))

  // Packed with inline value: -ofile.txt should consume the value.
  result = complete_ root ["-ofile.txt", "--"]
  values = result.candidates.map: it.value
  expect (not (values.contains "--output"))
  expect (values.contains "--verbose")

test-custom-completer-no-file-fallback:
  root := cli.Command "app"
      --options=[
        cli.Option "host" --help="Target host."
            --completion=:: | context/cli.CompletionContext |
              hosts := ["localhost", "staging.example.com"]
              (hosts.filter: it.starts-with context.prefix).map: cli.CompletionCandidate it,
      ]
      --run=:: null
  // When a custom completer returns no matches, should NOT fall back to file completion.
  result := complete_ root ["--host", "xyz"]
  expect-equals 0 result.candidates.size
  expect-equals DIRECTIVE-NO-FILE-COMPLETION_ result.directive

  // Same with --option=prefix form.
  result = complete_ root ["--host=xyz"]
  expect-equals 0 result.candidates.size
  expect-equals DIRECTIVE-NO-FILE-COMPLETION_ result.directive

  // A plain string option with no completer SHOULD fall back to file completion.
  root2 := cli.Command "app"
      --options=[
        cli.Option "file" --help="Input file.",
      ]
      --run=:: null
  result = complete_ root2 ["--file", ""]
  expect-equals 0 result.candidates.size
  expect-equals DIRECTIVE-FILE-COMPLETION_ result.directive

test-option-extensions:
  // OptionPath with extensions should report them in the result.
  root := cli.Command "app"
      --options=[
        cli.OptionPath "config" --extensions=[".toml", ".yaml"] --help="Config file.",
      ]
      --run=:: null
  result := complete_ root ["--config", ""]
  expect-equals DIRECTIVE-FILE-COMPLETION_ result.directive
  expect-equals 2 result.extensions.size
  expect (result.extensions.contains ".toml")
  expect (result.extensions.contains ".yaml")

  // With --option=prefix form.
  result = complete_ root ["--config=foo"]
  expect-equals DIRECTIVE-FILE-COMPLETION_ result.directive
  expect-equals 2 result.extensions.size

  // OptionInFile with extensions.
  root = cli.Command "app"
      --options=[
        cli.OptionInFile "input" --extensions=[".csv"] --help="Input file.",
      ]
      --run=:: null
  result = complete_ root ["--input", ""]
  expect-equals DIRECTIVE-FILE-COMPLETION_ result.directive
  expect-equals 1 result.extensions.size
  expect (result.extensions.contains ".csv")

  // OptionOutFile with extensions.
  root = cli.Command "app"
      --options=[
        cli.OptionOutFile "output" --extensions=[".log"] --help="Output file.",
      ]
      --run=:: null
  result = complete_ root ["--output", ""]
  expect-equals DIRECTIVE-FILE-COMPLETION_ result.directive
  expect-equals 1 result.extensions.size
  expect (result.extensions.contains ".log")

  // Without extensions, result.extensions should be null.
  root = cli.Command "app"
      --options=[
        cli.OptionPath "file" --help="Any file.",
      ]
      --run=:: null
  result = complete_ root ["--file", ""]
  expect-equals DIRECTIVE-FILE-COMPLETION_ result.directive
  expect-equals null result.extensions

  // OptionPath with --directory and --extensions should throw.
  expect-throw "OptionPath can't have both --directory and --extensions.":
    cli.OptionPath "dir" --directory --extensions=[".txt"] --help="Bad."

  // Rest option with extensions.
  root = cli.Command "app"
      --rest=[
        cli.OptionPath "config" --extensions=[".toml"] --help="Config file.",
      ]
      --run=:: null
  result = complete_ root [""]
  expect-equals DIRECTIVE-FILE-COMPLETION_ result.directive
  expect-equals 1 result.extensions.size
  expect (result.extensions.contains ".toml")

test-help-completion:
  root := cli.Command "app"
      --options=[
        cli.Flag "verbose" --help="Be verbose.",
      ]
      --subcommands=[
        cli.Command "serve" --help="Start a server."
            --options=[
              cli.Option "port" --help="Port number.",
            ]
            --run=:: null,
        cli.Command "build" --help="Build the project." --run=:: null,
        cli.Command "device"
            --help="Device commands."
            --options=[
              cli.Option "name" --help="Device name.",
            ]
            --subcommands=[
              cli.Command "list" --help="List devices." --run=:: null,
              cli.Command "show" --help="Show device." --run=:: null,
            ],
      ]
  // "app help " should complete subcommands but not "help" itself.
  result := complete_ root ["help", ""]
  values := result.candidates.map: it.value
  expect (values.contains "serve")
  expect (values.contains "build")
  expect (values.contains "device")
  expect (not (values.contains "help"))

  // "app help s" should filter by prefix.
  result = complete_ root ["help", "s"]
  values = result.candidates.map: it.value
  expect (values.contains "serve")
  expect (not (values.contains "build"))

  // "app help device " should complete device's subcommands.
  result = complete_ root ["help", "device", ""]
  values = result.candidates.map: it.value
  expect (values.contains "list")
  expect (values.contains "show")
  expect (not (values.contains "help"))

  // "app help -" should NOT complete options (help doesn't use them).
  result = complete_ root ["help", "-"]
  values = result.candidates.map: it.value
  expect (values.is-empty)

  // "app help device -" should NOT complete device's options.
  result = complete_ root ["help", "device", "-"]
  values = result.candidates.map: it.value
  expect (values.is-empty)

  // "app help serve " should complete nothing (leaf command in help mode).
  result = complete_ root ["help", "serve", ""]
  values = result.candidates.map: it.value
  expect (values.is-empty)
  expect-equals DIRECTIVE-NO-FILE-COMPLETION_ result.directive

test-help-gated-on-availability:
  // When a command defines its own "help" option, --help should not be suggested.
  root := cli.Command "app"
      --options=[
        cli.Option "help" --help="Custom help option.",
      ]
      --run=:: null
  result := complete_ root ["--"]
  values := result.candidates.map: it.value
  // The user's own --help is in all-named-options and will appear.
  expect (values.contains "--help")
  // But it should appear only once (from the user's option, not the synthetic one).
  expect-equals 1 (values.filter: it == "--help").size

  // When a command uses short-name "h", -h should not be suggested as help.
  root2 := cli.Command "app"
      --options=[
        cli.Flag "hack" --short-name="h" --help="Hack mode.",
      ]
      --run=:: null
  result = complete_ root2 ["-"]
  values = result.candidates.map: it.value
  // -h should appear (for --hack), but only once.
  expect (values.contains "-h")
  expect-equals 1 (values.filter: it == "-h").size
  // --help should still appear since "help" as a name is not taken.
  expect (values.contains "--help")
