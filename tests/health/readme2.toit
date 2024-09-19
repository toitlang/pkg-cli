// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli show *

main args/List:
  command := Command "my-app"
    --help="My app does something."

  sub := Command "subcommand"
    --help="This is a subcommand."
    --run=:: | invocation/Invocation |
      print "This is a subcommand."
  command.add sub

  command.run args
