// Copyright (C) 2024 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli show *

main args:
  cmd := Command "my-app"
    --help="My app does something."
    --run=:: run it

run invocation/Invocation:
  ui := invocation.cli.ui
  ui.emit
      // Block that is invoked if structured data is needed.
      --structured=: {
        "result": "Computed result"
      }
      // Block that is invoked if text data is needed.
      --text=: "Computed result as text message."
