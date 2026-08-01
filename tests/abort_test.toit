// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/TESTS_LICENSE file.

import cli
import expect show *

main:
  test-success
  test-abort
  test-parser-abort
  test-other-exception

test-success:
  command := cli.Command "app" --run=:: null
  expect-equals 0 (command.run-for-exit-code [])

test-abort:
  finalized := false
  ui := cli.Ui.human --level=cli.Ui.SILENT-LEVEL
  command := cli.Command "app"
      --run=:: | invocation/cli.Invocation |
        try:
          invocation.cli.ui.abort "Stop."
        finally:
          finalized = true

  exit-code := command.run-for-exit-code []
      --cli=(cli.Cli "app" --ui=ui)
  expect-equals 1 exit-code
  expect finalized

test-parser-abort:
  command := cli.Command "app"
      --rest=[cli.Option "argument" --required]
      --run=:: unreachable
  expect-equals 1 (command.run-for-exit-code [])

test-other-exception:
  command := cli.Command "app" --run=:: throw "OTHER"
  exception := catch: command.run-for-exit-code []
  expect-equals "OTHER" exception
