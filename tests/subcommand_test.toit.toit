// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli
import expect show *

check_arguments expected/Map parsed/cli.Parsed:
  expected.do: | key value |
    expect_equals value parsed[key]

main:
  cmd := cli.Command "root"
      --options=[
        cli.Option "global_string" --short_name="g" --short_help="Global string." --required,
        cli.Option "global_string2" --short_help="Global string2.",
      ]

  expected := {:}

  executed_sub := false
  sub := cli.Command "sub1"
      --options=[
        cli.Option "sub_string" --short_name="s" --short_help="Sub string." --required,
      ]
      --run=:: | arguments |
        executed_sub = true
        check_arguments expected arguments

  cmd.add sub

  expected = {
    "global_string": "global",
    "global_string2": null,
    "sub_string": "sub1",
  }
  cmd.run ["--global_string=global", "sub1", "-s", "sub1"]
  cmd.run ["sub1", "--global_string=global", "-s", "sub1"]
