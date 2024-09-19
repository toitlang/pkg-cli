// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli show *

main args/List:
  command := Command "my-app"
    --help="My app does something."
    --options=[
      Option "some-option"
        --help="This is an option."
        --required,
      Flag "some-flag"
        --short-name="f"
        --help="This is a flag.",
    ]
    --rest=[
      Option "rest-arg"
        --help="This is a rest argument."
        --multi,
    ]
    --examples=[
      Example "Do something with the flag:"
          --arguments="--some-option=foo --no-some-flag rest1 rest1",
    ]
    --run=:: | invocation/Invocation |
      print invocation["some-option"]
      print invocation["some-flag"]
      print invocation["rest-arg"]  // A list.
      invocation.cli.ui.result "Computed result"

  command.run args
