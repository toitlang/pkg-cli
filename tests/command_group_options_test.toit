// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli
import expect show *

/**
Reproduces a bug where options on the commands_ wrapper of a CommandGroup
  are not available to subcommands.

When a subcommand is found on a CommandGroup, the parser goes directly
  from the CommandGroup to the subcommand, skipping the commands_ wrapper.
  Options defined on the wrapper (like --sdk-dir) are therefore never
  registered, causing "No option named 'sdk-dir'" at runtime.
*/

main:
  test-commands-option-accessible-from-subcommand
  test-commands-option-accessible-with-value

test-commands-option-accessible-from-subcommand:
  sub-invoked := false

  commands-cmd := cli.Command "commands"
      --options=[
        cli.Option "sdk-dir" --help="Path to the SDK.",
      ]

  sub := cli.Command "run"
      --help="Run a file."
      --run=:: | invocation/cli.Invocation |
        sub-invoked = true
        // This line throws "No option named 'sdk-dir'".
        sdk-dir := invocation["sdk-dir"]
        expect-null sdk-dir
  commands-cmd.add sub

  root := cli.CommandGroup "app"
      --default=(cli.Command "default"
          --rest=[cli.Option "source" --required]
          --run=:: unreachable)
      --commands=commands-cmd

  root.run ["run"]
  expect sub-invoked

test-commands-option-accessible-with-value:
  captured-value := null

  commands-cmd := cli.Command "commands"
      --options=[
        cli.Option "sdk-dir" --help="Path to the SDK.",
      ]

  sub := cli.Command "run"
      --help="Run a file."
      --run=:: | invocation/cli.Invocation |
        captured-value = invocation["sdk-dir"]
  commands-cmd.add sub

  root := cli.CommandGroup "app"
      --default=(cli.Command "default"
          --rest=[cli.Option "source" --required]
          --run=:: unreachable)
      --commands=commands-cmd

  root.run ["--sdk-dir", "/my/sdk", "run"]
  expect-equals "/my/sdk" captured-value
