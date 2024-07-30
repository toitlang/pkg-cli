// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli
import expect show *

import .test-ui

check-arguments expected/Map invocation/cli.Invocation:
  expected.do: | key value |
    expect-equals value invocation[key]

main:
  test-options
  test-multi
  test-rest
  test-no-option
  test-invert-flag
  test-invert-non-flag
  test-value-for-flag
  test-missing-args
  test-missing-subcommand
  test-dash-arg
  test-mixed-rest-named
  test-snake-kebab

test-options:
  expected /Map? := null
  cmd := cli.Command "test"
      --options=[
        cli.Option "foo" --short-name="f" --default="default_foo",
        cli.Option "bar" --short-name="b",
        cli.OptionInt "gee" --short-name="g",
      ]
      --run=:: check-arguments expected it

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
        cli.Option "foo" --short-name="f" --default="default_foo",
        cli.Flag "bar" --short-name="b",
        cli.Option "fizz" --short-name="iz" --default="default_fizz",
      ]
      --run=:: check-arguments expected it

  expected = {"foo": "default_foo", "bar": true, "fizz": "default_fizz"}
  cmd.run ["-b"]
  cmd.run ["--bar"]

  expected = {"foo": "default_foo", "bar": null, "fizz": "default_fizz"}
  cmd.run []

  expected = {"foo": "default_foo", "bar": false, "fizz": "default_fizz"}
  cmd.run ["--no-bar"]

  expected = {"foo": "foo_value", "bar": true, "fizz": "default_fizz"}
  cmd.run ["-ffoo_value", "-b"]
  cmd.run ["-f", "foo_value", "-b"]
  cmd.run ["-bf", "foo_value"]

  expected = {"foo": "foo_value", "bar": true, "fizz": "fizz_value"}
  cmd.run ["-ffoo_value", "-b", "-izfizz_value"]
  cmd.run ["-f", "foo_value", "-b", "-iz", "fizz_value"]

  expected = {"foo": "foo_value", "bar": true, "fizz": "default_fizz"}
  cmd.run ["-f", "foo_value", "-b"]
  cmd.run ["-bf", "foo_value"]

  cmd = cli.Command "test"
      --options=[
        cli.Flag "foo" --short-name="f" --default=false,
      ]
      --run=:: check-arguments expected it

  expected = {"foo": false}
  cmd.run []

  expected = {"foo": true}
  cmd.run ["-f"]

  expected = {"foo": false}
  cmd.run ["--no-foo"]

  cmd = cli.Command "test"
      --options=[
        cli.Flag "foo" --short-name="f" --default=true,
      ]
      --run=:: check-arguments expected it

  expected = {"foo": true
  }
  cmd.run []

test-multi:
  expected/Map? := null
  cmd := cli.Command "test"
      --options=[
        cli.Option "foo" --short-name="f" --multi,
        cli.Option "bar" --short-name="b" --multi --split-commas,
      ]
      --run=:: check-arguments expected it

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
        cli.OptionInt "foo" --short-name="f" --multi --split-commas,
      ]
      --run=:: check-arguments expected it

  expected = {"foo": [1, 2, 3]}
  cmd.run ["-f", "1", "-f", "2", "-f", "3"]
  cmd.run ["--foo", "1,2,3"]

  cmd = cli.Command "test"
      --options=[
        cli.Flag "foo" --short-name="f" --multi,
      ]
      --run=:: check-arguments expected it

  expected = {"foo": [true, true, true]}
  cmd.run ["-f", "-f", "-f"]
  cmd.run ["--foo", "--foo", "--foo"]
  cmd.run ["-fff"]

  cmd = cli.Command "test"
      --options=[
        cli.OptionEnum "foo" ["a", "b"] --short-name="f" --multi,
      ]
      --run=:: check-arguments expected it

  expected = {"foo": ["a", "b", "a"]}
  cmd.run ["-f", "a", "-f", "b", "-f", "a"]

test-rest:
  expected/Map? := null
  cmd := cli.Command "test"
      --rest=[
        cli.Option "foo",
        cli.OptionInt "bar",
      ]
      --run=:: check-arguments expected it

  expected = {"foo": "foo_value", "bar": 42}
  cmd.run ["foo_value", "42"]

  expected = {"foo": "foo_value", "bar": null}
  cmd.run ["foo_value"]

  expected = {"foo": null, "bar": null}
  cmd.run []

  cmd = cli.Command "test"
      --rest=[
        cli.Option "foo" --required,
        cli.OptionInt "bar" --default=42,
      ]
      --run=:: check-arguments expected it

  expected = {"foo": "foo_value", "bar": 42}
  cmd.run ["foo_value"]

  expected = {"foo": "foo_value", "bar": 43}
  cmd.run ["foo_value", "43"]

  expect-abort "Missing required rest argument: 'foo'.": | app/cli.Cli |
    cmd.run [] --cli=app

  cmd = cli.Command "test"
      --rest=[
        cli.Option "foo" --required,
        cli.Option "bar" --required --multi,
      ]
      --run=:: check-arguments expected it

  expected = {"foo": "foo_value", "bar": ["bar_value"]}
  cmd.run ["foo_value", "bar_value"]

  expected = {"foo": "foo_value", "bar": ["bar_value", "bar_value2"]}
  cmd.run ["foo_value", "bar_value", "bar_value2"]

  expect-abort "Missing required rest argument: 'bar'.": | app/cli.Cli |
    cmd.run ["foo_value"] --cli=app

  cmd = cli.Command "test"
      --run=:: null
  expect-abort "Unexpected rest argument: 'baz'.": | app/cli.Cli |
    cmd.run ["baz"] --cli=app

test-subcommands:
  expected/Map? := null
  cmd := cli.Command "test"
      --subcommands=[
        cli.Command "sub1"
            --options=[
              cli.Option "foo" --short-name="f",
            ]
            --run=:: check-arguments expected it,
        cli.Command "sub2"
            --options=[
              cli.Option "bar" --short-name="b",
            ]
            --run=:: check-arguments expected it
      ]
      --run=:: check-arguments expected it

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

test-no-option:
  cmd := cli.Command "test"
      --run=:: | invocation/cli.Invocation |
        expect-throw "No option named 'foo'": invocation["foo"]
  cmd.run []

  cmd = cli.Command "test"
      --options=[
        cli.Option "foo" --short-name="f",
      ]
      --subcommands=[
        cli.Command "sub1"
            --options=[
              cli.Option "bar" --short-name="b",
            ]
            --run=:: | invocation/cli.Invocation |
              expect-throw "No option named 'gee'": invocation["gee"],
      ]

  cmd.run ["sub1", "-b", "bar_value"]
  cmd.run ["sub1"]

test-invert-flag:
  expected/Map? := null
  cmd := cli.Command "test"
      --options=[
        cli.Flag "foo" --short-name="f",
      ]
      --run=:: check-arguments expected it

  expected = {"foo": null}
  cmd.run []

  expected = {"foo": true}
  cmd.run ["-f"]

  expected = {"foo": false}
  cmd.run ["--no-foo"]

  cmd = cli.Command "test"
      --options=[
        cli.Flag "foo" --short-name="f" --default=true,
      ]
      --run=:: check-arguments expected it

  expected = {"foo": true}
  cmd.run []

  expected = {"foo": false}
  cmd.run ["--no-foo"]

test-invert-non-flag:
  cmd := cli.Command "test"
      --options=[
        cli.Option "foo" --short-name="f",
      ]
      --run=:: | invocation/cli.Invocation |
        unreachable

  expect-abort "Cannot invert non-boolean flag --foo.": | app/cli.Cli |
    cmd.run ["--no-foo"] --cli=app

test-value-for-flag:
  cmd := cli.Command "test"
      --options=[
        cli.Flag "foo" --short-name="f",
      ]
      --run=:: | invocation/cli.Invocation |
        unreachable

  expect-abort "Cannot specify value for boolean flag --foo.": | app/cli.Cli |
    cmd.run ["--foo=bar"] --cli=app

test-missing-args:
  cmd := cli.Command "test"
      --options=[
        cli.Option "foo" --short-name="f",
      ]
      --run=:: | invocation/cli.Invocation |
        unreachable

  expect-abort "Option --foo requires an argument.": | app/cli.Cli |
    cmd.run ["--foo"] --cli=app

  expect-abort "Option -f requires an argument.": | app/cli.Cli |
    cmd.run ["-f"] --cli=app

test-missing-subcommand:
  cmd := cli.Command "test"
      --subcommands=[
        cli.Command "sub1"
            --run=:: unreachable
      ]

  expect-abort "Missing subcommand.": | app/cli.Cli |
    cmd.run [] --cli=app

test-dash-arg:
  cmd := cli.Command "test"
      --options=[
        cli.Option "foo" --short-name="f",
      ]
      --run=:: | invocation/cli.Invocation |
        check-arguments {"foo": "-"} invocation

  cmd.run ["-f", "-"]

test-mixed-rest-named:
  // Rest arguments can be mixed with named arguments as long as there isn't a '--'.

  cmd := cli.Command "test"
      --options=[
        cli.Option "foo" --required,
        cli.Option "bar" --required,
      ]
      --rest=[
        cli.Option "baz" --required,
      ]
      --run=:: | invocation/cli.Invocation |
        check-arguments {"foo": "foo_value", "bar": "bar_value", "baz": "baz_value"} invocation

  cmd.run ["--foo", "foo_value", "--bar", "bar_value", "baz_value"]
  cmd.run ["baz_value", "--foo", "foo_value", "--bar", "bar_value"]
  cmd.run ["--foo", "foo_value", "baz_value", "--bar", "bar_value"]

  cmd = cli.Command "test"
      --options=[
        cli.Option "foo" --required,
        cli.Option "bar" --required,
      ]
      --rest=[
        cli.Option "baz" --required,
      ]
      --run=:: | invocation/cli.Invocation |
        check-arguments {"foo": "foo_value", "bar": "bar_value", "baz": "--foo"} invocation

  // Because of the '--', the rest argument is not interpreted as a named argument.
  cmd.run ["--foo", "foo_value", "--bar", "bar_value", "--", "--foo"]

test-snake-kebab:
  cmd := cli.Command "test"
      --options=[
        cli.Option "foo-bar" --short-name="f",
        cli.Option "toto_titi"
      ]
      --run=:: | invocation/cli.Invocation |
        check-arguments {"foo-bar": "foo_value", "toto-titi": "toto_value" } invocation
        check-arguments {"foo_bar": "foo_value", "toto_titi": "toto_value" } invocation

  cmd.run ["--foo-bar", "foo_value", "--toto-titi", "toto_value"]
  cmd.run ["--foo_bar", "foo_value", "--toto_titi", "toto_value"]
  cmd.run ["--foo-bar", "foo_value", "--toto_titi", "toto_value"]
