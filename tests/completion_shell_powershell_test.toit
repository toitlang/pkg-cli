// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import expect show *
import host.pipe
import .completion_shell

main:
  if not has-command_ "pwsh":
    print ""
    print "=== Skipping powershell tests (pwsh not installed) ==="
    return

  with-tmp-dir: | tmpdir |
    binary := setup-test-binary_ tmpdir
    test-powershell binary tmpdir

  print ""
  print "All powershell completion tests passed!"

/**
Invokes the registered PowerShell completer for the given $input string and
returns the raw output (one completion per line, value TAB tooltip).
The completer is sourced from the binary and TabExpansion2 is used to trigger it.
The working directory is set to $tmpdir so relative path completions resolve correctly.
*/
pwsh-complete_ binary/string tmpdir/string input/string -> string:
  cursor-col := input.size
  script := """
    \$env:PATH = "\$env:PATH\$([System.IO.Path]::PathSeparator)$tmpdir"
    Set-Location '$tmpdir'
    Invoke-Expression (& '$binary' completion powershell | Out-String)
    \$r = TabExpansion2 -inputScript '$input' -cursorColumn $cursor-col
    \$r.CompletionMatches | ForEach-Object { \$_.CompletionText + \"`t\" + \$_.ToolTip }
    """
  return pipe.backticks ["pwsh", "-NoProfile", "-Command", script]

test-powershell binary/string tmpdir/string:
  print ""
  print "=== Testing powershell completion ==="

  // Unique prefix auto-completes to subcommand.
  output := pwsh-complete_ binary tmpdir "fleet dep"
  expect (output.contains "deploy")
  print "  prefix completion: ok"

  // Empty word after space lists all subcommands (exercises Bug 1: trailing-space).
  output = pwsh-complete_ binary tmpdir "fleet "
  expect (output.contains "deploy")
  expect (output.contains "status")
  expect (output.contains "help")
  expect (output.contains "completion")
  print "  empty-word subcommand listing: ok"

  // Enum value completion with trailing space (exercises Bug 1 again).
  output = pwsh-complete_ binary tmpdir "fleet deploy --channel "
  expect (output.contains "stable")
  expect (output.contains "beta")
  expect (output.contains "dev")
  print "  enum completion: ok"

  // Enum prefix filters results.
  output = pwsh-complete_ binary tmpdir "fleet deploy --channel st"
  expect (output.contains "stable")
  expect (not (output.contains "beta"))
  print "  enum prefix filtering: ok"

  // Custom completion returns values and descriptions.
  output = pwsh-complete_ binary tmpdir "fleet deploy --device "
  expect (output.contains "d3b07384")
  expect (output.contains "Living Room Sensor")
  print "  custom completion with descriptions: ok"

  // OptionPath: file completion (directive 4).
  output = pwsh-complete_ binary tmpdir "fleet deploy --firmware xfirm"
  expect (output.contains "xfirmware.bin")
  print "  file path completion: ok"

  // OptionPath: directory-only completion (directive 8).
  output = pwsh-complete_ binary tmpdir "fleet deploy --output-dir xrel"
  expect (output.contains "xreleases")
  print "  directory path completion: ok"

  // OptionPath --extensions: only .toml and .yaml files should complete.
  output = pwsh-complete_ binary tmpdir "fleet deploy --config xconfig."
  expect (output.contains "xconfig.toml")
  expect (output.contains "xconfig.yaml")
  expect (not (output.contains "xconfig.txt"))
  print "  extension-filtered completion: ok"

  print "  All powershell tests passed."
