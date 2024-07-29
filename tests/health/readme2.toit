// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli

main args/List:
  command := cli.Command "my-app"
    --help="My app does something."

  sub := cli.Command "subcommand"
    --help="This is a subcommand."
    --run=:: | app/cli.Application parsed/cli.Invocation |
      print "This is a subcommand."
  command.add sub

  command.run args
