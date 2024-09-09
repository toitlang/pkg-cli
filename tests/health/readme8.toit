// Copyright (C) 2024 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli show Cli

some-chatty-method cli/Cli:
  ui := cli.ui
  ui.debug "This is a debug message."
  ui.verbose "This is a verbose message."
  ui.inform "This is an information message."
  ui.warn "This is a warning message."
  ui.error "This is an error message."
  ui.interactive "This is an interactive message."
  ui.result "This is a result message."
