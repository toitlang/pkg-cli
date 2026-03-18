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
