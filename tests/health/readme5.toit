// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli
import cli.config as cli

config-example app/cli.App:
  config := app.config

  print "old value: $(config.get "my-key")"

  config["my-key"] = "my-value"
  config.write

dotted-example app/cli.App:
  config := app.config

  print "old value: $(config.get "super-key.sub-key")"

  config["super-key.sub-key"] = "my-value"
  config.write

main args:
  cmd := cli.Command "my-app"
      --run=:: | app/cli.App parsed/cli.Parsed |
        print "Configuration is stored in $app.config.path"
        config-example app
        dotted-example app

  cmd.run args
