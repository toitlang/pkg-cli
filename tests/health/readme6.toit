// Copyright (C) 2024 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli show Cli Config

config-example cli/Cli:
  config := cli.config

  print "old value: $(config.get "my-key")"

  config["my-key"] = "my-value"
  config.write
