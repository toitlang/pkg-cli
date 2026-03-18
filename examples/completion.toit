// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import cli show *

/**
Demonstrates shell completion support.

To try it out, compile to a binary and source the completion script:

```
# Compile:
toit compile -o /tmp/fleet examples/completion.toit

# Enable completions (bash):
source <(/tmp/fleet completion bash)

# Enable completions (zsh):
source <(/tmp/fleet completion zsh)

# Enable completions (fish):
/tmp/fleet completion fish | source
```

Then type `/tmp/fleet ` and press Tab to see suggestions.
*/

main arguments:
  root := Command "fleet"
      --help="""
        An imaginary fleet manager for Toit devices.

        Manages a fleet of devices, allowing you to deploy firmware,
          monitor status, and configure devices.
        """

  root.add create-deploy-command
  root.add create-status-command

  root.run arguments

KNOWN-DEVICES ::= {
  "d3b07384-d113-4ec6-a7d2-8c6b2ab3e8f5": "Living Room Sensor",
  "6f1ed002-ab5d-42e0-868f-9e0c30e5a295": "Garden Monitor",
  "1f3870be-2748-4c9a-81e4-1b3b5e5a5c7f": "Front Door Lock",
}

/**
Completion callback that returns device UUIDs with human-readable descriptions.
*/
complete-device context/CompletionContext -> List:
  result := []
  KNOWN-DEVICES.do: | uuid/string name/string |
    if uuid.starts-with context.prefix:
      result.add (CompletionCandidate uuid --description=name)
  return result

create-deploy-command -> Command:
  return Command "deploy"
      --help="""
        Deploys firmware to a device.

        Uploads and installs the specified firmware file on the target device.
        """
      --options=[
        Option "device" --short-name="d"
            --help="The device to deploy to."
            --completion=:: complete-device it
            --required,
        OptionEnum "channel" ["stable", "beta", "dev"]
            --help="The release channel."
            --default="stable",
      ]
      --rest=[
        Option "firmware"
            --type="file"
            --help="Path to the firmware file."
            --required,
      ]
      --run=:: run-deploy it

create-status-command -> Command:
  return Command "status"
      --help="Shows live status of devices."
      --options=[
        Option "device" --short-name="d"
            --help="The device to show. Shows all if omitted."
            --completion=:: complete-device it,
        OptionEnum "format" ["table", "json", "sparkline"]
            --help="Output format."
            --default="table",
      ]
      --run=:: run-status it

run-deploy invocation/Invocation:
  device := invocation["device"]
  channel := invocation["channel"]
  firmware := invocation["firmware"]
  name := KNOWN-DEVICES.get device --if-absent=: "unknown"
  print "Deploying '$firmware' to '$name' on $channel channel."

run-status invocation/Invocation:
  device := invocation["device"]
  format := invocation["format"]
  if device:
    name := KNOWN-DEVICES.get device --if-absent=: "unknown"
    print "Status of '$name' (format: $format)."
  else:
    print "Status of all devices (format: $format)."
