// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

// Minimal CLI app used by completion_shell_test.toit to exercise
// shell completion end-to-end via tmux.

import cli show *

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

  root.run arguments
