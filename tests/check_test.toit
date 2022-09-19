// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli
import expect show *

main:
  missing_run
  ambiguous_option
  ambiguous_command
  rest_and_command
  run_and_command
  rest
  hidden_rest

missing_run:
  root := cli.Command "root"
  expect_throw "Command 'root' has no subcommands and no run callback.": root.check --invoked_command="root"

  sub := cli.Command "sub"
  root.add sub
  expect_throw "Command 'root sub' has no subcommands and no run callback.": root.check --invoked_command="root"

  subsub1 := cli.Command "subsub1" --run=(:: null)
  sub.add subsub1
  subsub2 := cli.Command "subsub2"
  sub.add subsub2
  expect_throw "Command 'root sub subsub2' has no subcommands and no run callback.": root.check --invoked_command="root"

  // Note that hidden subcommands are fine, though.
  root = cli.Command "root"
  sub_hidden := cli.Command "sub" --hidden --run=(:: null)
  root.add sub_hidden
  root.run ["sub"]


ambiguous_option:
  root := cli.Command "root"
      --options=[
        cli.OptionString "foo" --short_name="a",
        cli.OptionString "foo" --short_name="b",
      ]
      --run=(:: null)

  expect_throw "Ambiguous option of 'root': --foo.": root.check --invoked_command="root"

  root = cli.Command "root"
      --options=[
        cli.OptionString "foo" --short_name="a",
        cli.OptionString "bar" --short_name="a",
      ]
      --run=(:: null)
  expect_throw "Ambiguous option of 'root': -a.": root.check --invoked_command="root"

  root = cli.Command "root"
      --options=[
        cli.OptionString "foo" --short_name="a",
      ]

  sub := cli.Command "sub"
      --options=[
        cli.OptionString "foo" --short_name="b",
      ]
      --run=(:: null)
  root.add sub
  expect_throw "Ambiguous option of 'root sub': --foo conflicts with global option.":
    root.check --invoked_command="root"

  root = cli.Command "root"
      --options=[
        cli.OptionString "foo" --short_name="a",
      ]
  sub = cli.Command "sub"
      --options=[
        cli.OptionString "bar" --short_name="a",
      ]
      --run=(:: null)
  root.add sub
  expect_throw "Ambiguous option of 'root sub': -a conflicts with global option.":
    root.check --invoked_command="root"

  root = cli.Command "root"
  sub1 := cli.Command "sub1"
      --options=[
        cli.OptionString "foo" --short_name="a",
      ]
      --run=(:: null)
  root.add sub1
  sub2 := cli.Command "sub2"
      --options=[
        cli.OptionString "foo" --short_name="a",
      ]
      --run=(:: null)
  root.add sub2
  root.run ["sub1"]  // No error.

ambiguous_command:
  root := cli.Command "root"
  sub1 := cli.Command "sub"
      --run=(:: null)
  root.add sub1
  sub2 := cli.Command "sub"
      --run=(:: null)
  root.add sub2

  expect_throw "Ambiguous subcommand of 'root': 'sub'.":
    root.check --invoked_command="root"

rest_and_command:
  root := cli.Command "root"
      --rest=[
        cli.OptionString "rest" --multi,
      ]
  sub := cli.Command "sub"
      --run=(:: null)
  expect_throw "Cannot add subcommands to a command with rest arguments.":
    root.add sub

  expect_throw "Cannot have both subcommands and rest arguments.":
    root = cli.Command "root"
        --rest=[
          cli.OptionString "rest" --multi,
        ]
        --subcommands=[
          cli.Command "sub" --run=(:: null),
        ]
        --run=(:: null)

run_and_command:
  root := cli.Command "root"
      --run=(:: null)
  sub := cli.Command "sub"
      --run=(:: null)
  expect_throw "Cannot add subcommands to a command with a run callback.":
    root.add sub

  expect_throw "Cannot have both a run callback and subcommands.":
    root = cli.Command "root"
        --subcommands=[
          cli.Command "sub" --run=(:: null),
        ]
        --run=(:: null)

rest:
  root := cli.Command "root"
      --rest=[
        cli.OptionString "rest" --multi,
        cli.OptionString "other",
      ]
      --run=(:: null)
  expect_throw "Multi-option 'rest' of 'root' must be the last rest argument.":
    root.check --invoked_command="root"

  root = cli.Command "root"
      --rest=[
        cli.OptionString "foo",
        cli.OptionString "bar" --required,
      ]
      --run=(:: null)
  expect_throw "Required rest argument 'bar' of 'root' cannot follow optional rest argument.":
    root.check --invoked_command="root"

  root = cli.Command "root"
      --options=[
        cli.OptionString "foo",
      ]
      --rest=[
        cli.OptionString "foo",
      ]
      --run=(:: null)
  expect_throw "Rest name 'foo' of 'root' already used.": root.check --invoked_command="root"

  root = cli.Command "root"
      --rest=[
        cli.OptionString "foo",
        cli.OptionString "foo",
      ]
      --run=(:: null)
  expect_throw "Rest name 'foo' of 'root' already used.": root.check --invoked_command="root"

  root = cli.Command "root"
      --options=[
        cli.OptionString "foo",
      ]
  sub := cli.Command "sub"
      --rest=[
        cli.OptionString "foo",
      ]
      --run=(:: null)
  root.add sub
  expect_throw "Rest name 'foo' of 'root sub' already a global option.":
    root.check --invoked_command="root"

hidden_rest:
  root := cli.Command "root"
      --rest=[
        cli.OptionString "foo" --hidden,
      ]
      --run=(:: null)
  expect_throw "Rest argument 'foo' of 'root' cannot be hidden.":
    root.check --invoked_command="root"
