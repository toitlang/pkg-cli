// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli
import cli.completion_ show *
import cli.test show *
import expect show *

/**
Tests that a simple single-command app — one with a run callback and a
  required rest argument, like the examples/comp.toit example — gets a
  "--generate-completion" flag as a fallback to the "completion" subcommand,
  and that runtime ($complete_) completion still works.
*/
main:
  test-flag-added-for-single-command-app
  test-subcommand-used-when-no-run-callback
  test-flag-skips-run-callback
  test-equals-form-also-skips-run-callback
  test-invalid-shell-falls-through
  test-user-defined-option-not-overridden
  test-normal-invocation-still-works
  test-runtime-completion-with-extensions

// Builds a "comp"-style single-command app: run callback plus a required
//   input rest arg with extension filtering.
build-comp-app --on-run/Lambda -> cli.Command:
  return cli.Command "comp"
      --help="An imaginary compiler."
      --options=[
        cli.OptionPath "output" --short-name="o" --required,
      ]
      --rest=[
        cli.OptionPath "input" --extensions=[".toit"] --required,
      ]
      --run=on-run

test-flag-added-for-single-command-app:
  cmd := build-comp-app --on-run=:: null
  // Invoke normally so that run() wires up the completion bootstrap.
  cmd.run ["-o", "/tmp/x", "in.toit"]
  help := cmd.help --invoked-command="comp"
  expect (help.contains "--generate-completion shell")
  // And no "completion" subcommand exists (there are no subcommands at all).
  expect (not help.contains "completion  Generate shell completion scripts.")

test-subcommand-used-when-no-run-callback:
  cmd := cli.Command "multi"
      --subcommands=[
        cli.Command "build" --help="Build it." --run=:: null,
      ]
  cmd.run ["build"]
  help := cmd.help --invoked-command="multi"
  // The subcommand path is used; no fallback flag.
  expect (help.contains "completion")
  expect (not help.contains "--generate-completion")

test-flag-skips-run-callback:
  called := false
  cmd := build-comp-app --on-run=:: called = true
  cmd.run ["--generate-completion", "bash"]
  // The run callback must not have been invoked, even though the
  //   required rest argument is missing.
  expect (not called)

test-equals-form-also-skips-run-callback:
  called := false
  cmd := build-comp-app --on-run=:: called = true
  cmd.run ["--generate-completion=zsh"]
  expect (not called)

test-invalid-shell-falls-through:
  // An unknown shell value should NOT be intercepted. The parser then reports
  //   a standard enum validation error, which calls ui.abort.
  called := false
  cmd := build-comp-app --on-run=:: called = true
  test-cli := TestCli
  exception := catch:
    cmd.run ["--generate-completion", "tcsh", "-o", "/tmp/x", "in.toit"] --cli=test-cli
  expect (not called)
  expect exception is TestAbort
  all-output := test-cli.ui.stdout + test-cli.ui.stderr
  expect (all-output.contains "Invalid value for option 'generate-completion'")

test-user-defined-option-not-overridden:
  // If the user already has a --generate-completion option, the bootstrap
  //   must leave it alone.
  user-called := false
  cmd := cli.Command "comp"
      --options=[
        cli.Option "generate-completion" --help="User's own option.",
      ]
      --rest=[
        cli.OptionPath "input" --required,
      ]
      --run=:: user-called = true
  cmd.run ["--generate-completion", "mine", "in.toit"]
  expect user-called

test-normal-invocation-still-works:
  called := false
  cmd := build-comp-app --on-run=:: called = true
  cmd.run ["-o", "/tmp/x", "in.toit"]
  expect called

test-runtime-completion-with-extensions:
  // This exercises the path the shell completion script calls back into:
  //   a __complete request at the rest-arg position should surface the
  //   ".toit" extension filter.
  cmd := build-comp-app --on-run=:: null
  result := complete_ cmd ["-o", "/tmp/x", ""]
  expect-equals DIRECTIVE-FILE-COMPLETION_ result.directive
  expect-not-null result.extensions
  expect (result.extensions.contains ".toit")
