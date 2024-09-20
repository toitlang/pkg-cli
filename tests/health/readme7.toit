// Copyright (C) 2024 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli show Cli Config

dotted-example cli/Cli:
  config := cli.config

  print "old value: $(config.get "super-key.sub-key")"

  config["super-key.sub-key"] = "my-value"
  config.write
