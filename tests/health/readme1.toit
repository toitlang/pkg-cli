// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli

main args/List:
  command := cli.Command "my-app"
    --help="My app does something."
    --options=[
      cli.Option "some-option"
        --help="This is an option."
        --required,
      cli.Flag "some-flag"
        --short-name="f"
        --help="This is a flag.",
    ]
    --rest=[
      cli.Option "rest-arg"
        --help="This is a rest argument."
        --multi,
    ]
    --examples=[
      cli.Example "Do something with the flag:"
          --arguments="--some-option=foo --no-some-flag rest1 rest1",
    ]
    --run=:: | app/cli.App parsed/cli.Parsed |
      print parsed["some-option"]
      print parsed["some-flag"]
      print parsed["rest-arg"]  // A list.
      app.ui.result "Computed result"

  command.run args
