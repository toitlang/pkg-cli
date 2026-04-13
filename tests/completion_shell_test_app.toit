// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

// Minimal CLI app used by completion_shell_test.toit to exercise
// shell completion end-to-end via tmux.

import cli show *
import host.file

KNOWN-DEVICES ::= {
  "d3b07384-d113-4ec6-a7d2-8c6b2ab3e8f5": "Living Room Sensor",
  "6f1ed002-ab5d-42e0-868f-9e0c30e5a295": "Garden Monitor",
}

main arguments:
  root := Command "fleet"
      --help="Test fleet manager."

  root.add
      Command "deploy"
          --help="Deploy firmware."
          --options=[
            Option "device" --short-name="d"
                --help="Target device."
                --completion=:: | ctx/CompletionContext |
                  result := []
                  KNOWN-DEVICES.do: | uuid/string name/string |
                    if uuid.starts-with ctx.prefix:
                      result.add (CompletionCandidate uuid --description=name)
                  result,
            OptionEnum "channel" ["stable", "beta", "dev"]
                --help="Release channel.",
            OptionPath "firmware" --help="Firmware file to deploy.",
            OptionPath "config" --extensions=[".toml", ".yaml"] --help="Config file.",
            OptionPath "output-dir" --directory --help="Output directory.",
          ]
          --run=:: null

  root.add
      Command "status"
          --help="Show status."
          --options=[
            Option "device" --short-name="d"
                --help="Device to show."
                --completion=:: | ctx/CompletionContext |
                  result := []
                  KNOWN-DEVICES.do: | uuid/string name/string |
                    if uuid.starts-with ctx.prefix:
                      result.add (CompletionCandidate uuid --description=name)
                  result,
          ]
          --run=:: null

  // "lookup" command: opens a file (first rest arg) and, if successful,
  //   offers fixed completion candidates for the second rest arg. This
  //   exercises tilde expansion: the shell must expand ~/... before the
  //   program tries to open the file.
  root.add
      Command "lookup"
          --help="Look up an entry in a file."
          --rest=[
            OptionPath "file" --help="Input file." --required,
            Option "entry"
                --help="Entry to look up."
                --completion=:: | ctx/CompletionContext |
                  file-values := ctx.seen-options.get "file"
                  if not file-values or file-values.is-empty:
                    []
                  else:
                    opened := false
                    catch:
                      file.read-contents file-values.first
                      opened = true
                    if not opened:
                      []
                    else:
                      result := []
                      candidates := ["tilde-ok-alpha", "tilde-ok-bravo", "tilde-ok-charlie"]
                      candidates.do: | c/string |
                        if c.starts-with ctx.prefix:
                          result.add (CompletionCandidate c)
                      result,
          ]
          --run=:: null

  root.run arguments
