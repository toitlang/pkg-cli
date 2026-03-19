// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli show *

create-command -> Command:
  return Command "deploy"
      --options=[
        Option "device"
            --help="The device to deploy to."
            --completion=:: | context/CompletionContext |
              [
                CompletionCandidate "device-001" --description="Living Room Sensor",
                CompletionCandidate "device-002" --description="Garden Monitor",
              ]
      ]
      --run=:: | invocation/Invocation |
        print "Deploying to $(invocation["device"])"
