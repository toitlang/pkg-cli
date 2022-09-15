// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli
import expect show *

import .test_ui

check_arguments expected/Map parsed/cli.Parsed:
  expected.do: | key value |
    expect_equals value parsed[key]

main:
  test_options
  test_multi
  test_rest
  test_no_option
  test_invert_flag
  test_invert_non_flag
  test_value_for_flag
  test_missing_args
  test_missing_subcommand
  test_dash_arg

test_options:
  expected /Map? := null
  cmd := cli.Command "test"
      --options=[
        cli.OptionString "foo" --short_name="f" --default="default_foo",
        cli.OptionString "bar" --short_name="b",
        cli.OptionInt "gee" --short_name="g",
      ]
      --run=:: | parsed/cli.Parsed |
        check_arguments expected parsed

  expected = {"foo": "foo_value", "bar": "bar_value", "gee": null}
  cmd.run ["-f", "foo_value", "-b", "bar_value"]
  cmd.run ["--foo", "foo_value", "--bar", "bar_value"]
  cmd.run ["-ffoo_value", "-bbar_value"]
  cmd.run ["--foo=foo_value", "--bar=bar_value"]

  expected = {"foo": "foo_value", "bar": null, "gee": null}
  cmd.run ["-f", "foo_value"]

  expected = {"foo": "default_foo", "bar": "bar_value", "gee": null}
  cmd.run ["-b", "bar_value"]

  expected = {"foo": "default_foo", "bar": null, "gee": 42}
  cmd.run ["-g", "42"]

  cmd = cli.Command "test"
      --options=[
        cli.OptionString "foo" --short_name="f" --default="default_foo",
        cli.Flag "bar" --short_name="b",
      ]
      --run=:: | parsed/cli.Parsed |
        check_arguments expected parsed

  expected = {"foo": "default_foo", "bar": true}
  cmd.run ["-b"]
  cmd.run ["--bar"]

  expected = {"foo": "default_foo", "bar": null}
  cmd.run []

  expected = {"foo": "default_foo", "bar": false}
  cmd.run ["--no-bar"]

  expected = {"foo": "foo_value", "bar": true}
  cmd.run ["-f", "foo_value", "-b"]
  cmd.run ["-bf", "foo_value"]

  cmd = cli.Command "test"
      --options=[
        cli.Flag "foo" --short_name="f" --default=false,
      ]
      --run=:: | parsed/cli.Parsed |
        check_arguments expected parsed

  expected = {"foo": false}
  cmd.run []

  expected = {"foo": true}
  cmd.run ["-f"]

  expected = {"foo": false}
  cmd.run ["--no-foo"]

  cmd = cli.Command "test"
      --options=[
        cli.Flag "foo" --short_name="f" --default=true,
      ]
      --run=:: | parsed/cli.Parsed |
        check_arguments expected parsed

  expected = {"foo": true
  }
  cmd.run []

test_multi:
  expected/Map? := null
  cmd := cli.Command "test"
      --options=[
        cli.OptionString "foo" --short_name="f" --multi,
        cli.OptionString "bar" --short_name="b" --multi --split_commas,
      ]
      --run=:: | parsed/cli.Parsed |
        check_arguments expected parsed

  expected = {"foo": ["foo_value"], "bar": ["bar_value"]}
  cmd.run ["-f", "foo_value", "-b", "bar_value"]
  cmd.run ["--foo", "foo_value", "--bar", "bar_value"]
  cmd.run ["-ffoo_value", "-bbar_value"]
  cmd.run ["--foo=foo_value", "--bar=bar_value"]

  expected = {"foo": ["foo_value"], "bar": ["bar_value", "bar_value2"]}
  cmd.run ["-f", "foo_value", "-b", "bar_value,bar_value2"]
  cmd.run ["--foo", "foo_value", "--bar", "bar_value,bar_value2"]
  cmd.run ["--foo", "foo_value", "--bar", "bar_value", "--bar", "bar_value2"]
  cmd.run ["-ffoo_value", "-bbar_value,bar_value2"]
  cmd.run ["--foo=foo_value", "--bar=bar_value,bar_value2"]

  expected = {"foo": ["foo_value", "foo_value2"], "bar": ["bar_value"]}
  cmd.run ["-f", "foo_value", "-f", "foo_value2", "-b", "bar_value"]
  cmd.run ["--foo", "foo_value", "--foo", "foo_value2", "--bar", "bar_value"]
  cmd.run ["-ffoo_value", "-ffoo_value2", "-bbar_value"]
  cmd.run ["--foo=foo_value", "-ffoo_value2", "--bar=bar_value"]

  expected = {"foo": ["foo_value,foo_value2"], "bar": ["bar_value", "bar_value2"]}
  cmd.run ["-f", "foo_value,foo_value2", "-b", "bar_value,bar_value2"]
  cmd.run ["--foo", "foo_value,foo_value2", "--bar", "bar_value,bar_value2"]

  cmd = cli.Command "test"
      --options=[
        cli.OptionInt "foo" --short_name="f" --multi --split_commas,
      ]
      --run=:: | parsed/cli.Parsed |
        check_arguments expected parsed

  expected = {"foo": [1, 2, 3]}
  cmd.run ["-f", "1", "-f", "2", "-f", "3"]
  cmd.run ["--foo", "1,2,3"]

  cmd = cli.Command "test"
      --options=[
        cli.Flag "foo" --short_name="f" --multi,
      ]
      --run=:: | parsed/cli.Parsed |
        check_arguments expected parsed

  expected = {"foo": [true, true, true]}
  cmd.run ["-f", "-f", "-f"]
  cmd.run ["--foo", "--foo", "--foo"]
  cmd.run ["-fff"]

  cmd = cli.Command "test"
      --options=[
        cli.OptionEnum "foo" ["a", "b"] --short_name="f" --multi,
      ]
      --run=:: | parsed/cli.Parsed |
        check_arguments expected parsed

  expected = {"foo": ["a", "b", "a"]}
  cmd.run ["-f", "a", "-f", "b", "-f", "a"]

test_rest:
  expected/Map? := null
  cmd := cli.Command "test"
      --rest=[
        cli.OptionString "foo",
        cli.OptionInt "bar",
      ]
      --run=:: | parsed/cli.Parsed |
        check_arguments expected parsed

  expected = {"foo": "foo_value", "bar": 42}
  cmd.run ["foo_value", "42"]

  expected = {"foo": "foo_value", "bar": null}
  cmd.run ["foo_value"]

  expected = {"foo": null, "bar": null}
  cmd.run []

  cmd = cli.Command "test"
      --rest=[
        cli.OptionString "foo" --required,
        cli.OptionInt "bar" --default=42,
      ]
      --run=:: | parsed/cli.Parsed |
        check_arguments expected parsed

  expected = {"foo": "foo_value", "bar": 42}
  cmd.run ["foo_value"]

  expected = {"foo": "foo_value", "bar": 43}
  cmd.run ["foo_value", "43"]

  expect_abort "Missing required rest argument: 'foo'.": | ui/cli.Ui |
    cmd.run [] --ui=ui

  cmd = cli.Command "test"
      --rest=[
        cli.OptionString "foo" --required,
        cli.OptionString "bar" --required --multi,
      ]
      --run=:: | parsed/cli.Parsed |
        check_arguments expected parsed

  expected = {"foo": "foo_value", "bar": ["bar_value"]}
  cmd.run ["foo_value", "bar_value"]

  expected = {"foo": "foo_value", "bar": ["bar_value", "bar_value2"]}
  cmd.run ["foo_value", "bar_value", "bar_value2"]

  expect_abort "Missing required rest argument: 'bar'.": | ui/cli.Ui |
    cmd.run ["foo_value"] --ui=ui

  cmd = cli.Command "test"
      --run=:: null
  expect_abort "Unexpected rest argument: 'baz'.": | ui/cli.Ui |
    cmd.run ["baz"] --ui=ui

test_subcommands:
  expected/Map? := null
  cmd := cli.Command "test"
      --subcommands=[
        cli.Command "sub1"
            --options=[
              cli.OptionString "foo" --short_name="f",
            ]
            --run=:: | parsed/cli.Parsed |
              check_arguments expected parsed,
        cli.Command "sub2"
            --options=[
              cli.OptionString "bar" --short_name="b",
            ]
            --run=:: | parsed/cli.Parsed |
              check_arguments expected parsed,
      ]
      --run=:: | parsed/cli.Parsed |
        check_arguments expected parsed

  expected = {"foo": "foo_value"}
  cmd.run ["sub1", "-f", "foo_value"]
  cmd.run ["sub1", "--foo", "foo_value"]

  expected = {"bar": "bar_value"}
  cmd.run ["sub2", "-b", "bar_value"]
  cmd.run ["sub2", "--bar", "bar_value"]

  expected = {"foo": null}
  cmd.run ["sub1"]

  expected = {"bar": null}
  cmd.run ["sub2"]

test_no_option:
  cmd := cli.Command "test"
      --run=:: | parsed/cli.Parsed |
        expect_throw "No option named 'foo'": parsed["foo"]
  cmd.run []

  cmd = cli.Command "test"
      --options=[
        cli.OptionString "foo" --short_name="f",
      ]
      --subcommands=[
        cli.Command "sub1"
            --options=[
              cli.OptionString "bar" --short_name="b",
            ]
            --run=:: | parsed/cli.Parsed |
              expect_throw "No option named 'gee'": parsed["gee"],
      ]

  cmd.run ["sub1", "-b", "bar_value"]
  cmd.run ["sub1"]

test_invert_flag:
  expected/Map? := null
  cmd := cli.Command "test"
      --options=[
        cli.Flag "foo" --short_name="f",
      ]
      --run=:: | parsed/cli.Parsed |
        check_arguments expected parsed

  expected = {"foo": null}
  cmd.run []

  expected = {"foo": true}
  cmd.run ["-f"]

  expected = {"foo": false}
  cmd.run ["--no-foo"]

  cmd = cli.Command "test"
      --options=[
        cli.Flag "foo" --short_name="f" --default=true,
      ]
      --run=:: | parsed/cli.Parsed |
        check_arguments expected parsed

  expected = {"foo": true}
  cmd.run []

  expected = {"foo": false}
  cmd.run ["--no-foo"]

test_invert_non_flag:
  cmd := cli.Command "test"
      --options=[
        cli.OptionString "foo" --short_name="f",
      ]
      --run=:: | parsed/cli.Parsed |
        unreachable

  expect_abort "Cannot invert non-boolean flag --foo.": | ui/cli.Ui |
    cmd.run ["--no-foo"] --ui=ui

test_value_for_flag:
  cmd := cli.Command "test"
      --options=[
        cli.Flag "foo" --short_name="f",
      ]
      --run=:: | parsed/cli.Parsed |
        unreachable

  expect_abort "Cannot specify value for boolean flag --foo.": | ui/cli.Ui |
    cmd.run ["--foo=bar"] --ui=ui

test_missing_args:
  cmd := cli.Command "test"
      --options=[
        cli.OptionString "foo" --short_name="f",
      ]
      --run=:: | parsed/cli.Parsed |
        unreachable

  expect_abort "Option --foo requires an argument.": | ui/cli.Ui |
    cmd.run ["--foo"] --ui=ui

  expect_abort "Option -f requires an argument.": | ui/cli.Ui |
    cmd.run ["-f"] --ui=ui

test_missing_subcommand:
  cmd := cli.Command "test"
      --subcommands=[
        cli.Command "sub1"
            --run=:: unreachable
      ]

  expect_abort "Missing subcommand.": | ui/cli.Ui |
    cmd.run [] --ui=ui

test_dash_arg:
  cmd := cli.Command "test"
      --options=[
        cli.OptionString "foo" --short_name="f",
      ]
      --run=:: | parsed/cli.Parsed |
        check_arguments {"foo": "-"} parsed

  cmd.run ["-f", "-"]
