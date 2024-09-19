// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli
import expect show *

main:
  missing-run
  ambiguous-option
  ambiguous-command
  rest-and-command
  run-and-command
  rest
  hidden-rest
  snake-kebab

missing-run:
  root := cli.Command "root"
  expect-throw "Command 'root' has no subcommands and no run callback.": root.check --invoked-command="root"

  sub := cli.Command "sub"
  root.add sub
  expect-throw "Command 'root sub' has no subcommands and no run callback.": root.check --invoked-command="root"

  subsub1 := cli.Command "subsub1" --run=(:: null)
  sub.add subsub1
  subsub2 := cli.Command "subsub2"
  sub.add subsub2
  expect-throw "Command 'root sub subsub2' has no subcommands and no run callback.": root.check --invoked-command="root"

  // Note that hidden subcommands are fine, though.
  root = cli.Command "root"
  sub-hidden := cli.Command "sub" --hidden --run=(:: null)
  root.add sub-hidden
  root.run ["sub"]


ambiguous-option:
  root := cli.Command "root"
      --options=[
        cli.Option "foo" --short-name="a",
        cli.Option "foo" --short-name="b",
      ]
      --run=(:: null)

  expect-throw "Ambiguous option of 'root': --foo.": root.check --invoked-command="root"

  root = cli.Command "root"
      --options=[
        cli.Option "foo" --short-name="a",
        cli.Option "bar" --short-name="a",
      ]
      --run=(:: null)
  expect-throw "Ambiguous option of 'root': -a.": root.check --invoked-command="root"

  root = cli.Command "root"
      --options=[
        cli.Option "foo" --short-name="a",
        cli.Option "bar" --short-name="ab",
      ]
      --run=(:: null)
  expect-throw "Ambiguous option of 'root': -ab.": root.check --invoked-command="root"

  root = cli.Command "root"
      --options=[
        cli.Option "foo" --short-name="a",
      ]

  sub := cli.Command "sub"
      --options=[
        cli.Option "foo" --short-name="b",
      ]
      --run=(:: null)
  root.add sub
  expect-throw "Ambiguous option of 'root sub': --foo conflicts with global option.":
    root.check --invoked-command="root"

  root = cli.Command "root"
      --options=[
        cli.Option "foo" --short-name="a",
      ]
  sub = cli.Command "sub"
      --options=[
        cli.Option "bar" --short-name="a",
      ]
      --run=(:: null)
  root.add sub
  expect-throw "Ambiguous option of 'root sub': -a conflicts with global option.":
    root.check --invoked-command="root"

  root = cli.Command "root"
      --options=[
        cli.Option "foo" --short-name="a",
      ]
  sub = cli.Command "sub"
      --options=[
        cli.Option "bar" --short-name="ab",
      ]
      --run=(:: null)
  root.add sub
  expect-throw "Ambiguous option of 'root sub': -ab conflicts with global option.":
    root.check --invoked-command="root"

  root = cli.Command "root"
      --options=[
        cli.Option "machine_32" --short-name="m32",
      ]
  sub = cli.Command "sub"
      --options=[
        cli.Option "machine_64" --short-name="m64",
      ]
      --run=(:: null)
  root.add sub
  root.check --invoked-command="root"

  root = cli.Command "root"
  sub1 := cli.Command "sub1"
      --options=[
        cli.Option "foo" --short-name="a",
      ]
      --run=(:: null)
  root.add sub1
  sub2 := cli.Command "sub2"
      --options=[
        cli.Option "foo" --short-name="a",
      ]
      --run=(:: null)
  root.add sub2
  root.run ["sub1"]  // No error.

ambiguous-command:
  root := cli.Command "root"
  sub1 := cli.Command "sub"
      --run=(:: null)
  root.add sub1
  sub2 := cli.Command "sub"
      --run=(:: null)
  root.add sub2

  expect-throw "Ambiguous subcommand of 'root': 'sub'.":
    root.check --invoked-command="root"

rest-and-command:
  root := cli.Command "root"
      --rest=[
        cli.Option "rest" --multi,
      ]
  sub := cli.Command "sub"
      --run=(:: null)
  expect-throw "Cannot add subcommands to a command with rest arguments.":
    root.add sub

  expect-throw "Cannot have both subcommands and rest arguments.":
    root = cli.Command "root"
        --rest=[
          cli.Option "rest" --multi,
        ]
        --subcommands=[
          cli.Command "sub" --run=(:: null),
        ]
        --run=(:: null)

run-and-command:
  root := cli.Command "root"
      --run=(:: null)
  sub := cli.Command "sub"
      --run=(:: null)
  expect-throw "Cannot add subcommands to a command with a run callback.":
    root.add sub

  expect-throw "Cannot have both a run callback and subcommands.":
    root = cli.Command "root"
        --subcommands=[
          cli.Command "sub" --run=(:: null),
        ]
        --run=(:: null)

rest:
  root := cli.Command "root"
      --rest=[
        cli.Option "rest" --multi,
        cli.Option "other",
      ]
      --run=(:: null)
  expect-throw "Multi-option 'rest' of 'root' must be the last rest argument.":
    root.check --invoked-command="root"

  root = cli.Command "root"
      --rest=[
        cli.Option "foo",
        cli.Option "bar" --required,
      ]
      --run=(:: null)
  expect-throw "Required rest argument 'bar' of 'root' cannot follow optional rest argument.":
    root.check --invoked-command="root"

  root = cli.Command "root"
      --options=[
        cli.Option "foo",
      ]
      --rest=[
        cli.Option "foo",
      ]
      --run=(:: null)
  expect-throw "Rest name 'foo' of 'root' already used.": root.check --invoked-command="root"

  root = cli.Command "root"
      --rest=[
        cli.Option "foo",
        cli.Option "foo",
      ]
      --run=(:: null)
  expect-throw "Rest name 'foo' of 'root' already used.": root.check --invoked-command="root"

  root = cli.Command "root"
      --options=[
        cli.Option "foo",
      ]
  sub := cli.Command "sub"
      --rest=[
        cli.Option "foo",
      ]
      --run=(:: null)
  root.add sub
  expect-throw "Rest name 'foo' of 'root sub' already a global option.":
    root.check --invoked-command="root"

hidden-rest:
  root := cli.Command "root"
      --rest=[
        cli.Option "foo" --hidden,
      ]
      --run=(:: null)
  expect-throw "Rest argument 'foo' of 'root' cannot be hidden.":
    root.check --invoked-command="root"

snake-kebab:
  // Test that kebab and snake case lead to ambiguous options.
  root := cli.Command "root"
      --options=[
        cli.Option "foo-bar",
        cli.Option "foo_bar"
      ]
      --run=:: | parsed/cli.Invocation |
        unreachable
  expect-throw "Ambiguous option of 'root': --foo-bar.":
    root.check --invoked-command="root"
