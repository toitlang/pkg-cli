// Copyright (C) 2024 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import cli show *

config-example cli/Cli:
  config := cli.config

  print "old value: $(config.get "my-key")"

  config["my-key"] = "my-value"
  config.write

dotted-example cli/Cli:
  config := cli.config

  print "old value: $(config.get "super-key.sub-key")"

  config["super-key.sub-key"] = "my-value"
  config.write

main args:
  // Uses the application name "cli-example" which will be used
  // to compute the path of the config file.
  root-cmd := Command "cli-example"
      --help="""
          An example application demonstrating configurations.
          """
      --run=:: run it
  root-cmd.run args

run invocation/Invocation:
  config-example invocation.cli
  dotted-example invocation.cli
