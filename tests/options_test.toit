// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli
import expect show *
import uuid

main:
  test-string
  test-enum
  test-patterns
  test-int
  test-uuid
  test-flag
  test-bad-combos

test-string:
  option := cli.Option "foo"
  expect-equals option.name "foo"
  expect-null option.default
  expect-equals "string" option.type
  expect-null option.short-name
  expect-null option.help
  expect-not option.is-required
  expect-not option.is-hidden
  expect-not option.is-multi
  expect-not option.should-split-commas
  expect-not option.is-flag

  option = cli.Option "foo" --default="some_default"
  expect-equals "some_default" option.default

  option = cli.Option "foo" --short-name="f"
  expect-equals "f" option.short-name

  option = cli.Option "foo" --short-name="foo"
  expect-equals "foo" option.short-name

  option = cli.Option "foo" --help="Some_help."
  expect-equals "Some_help." option.help

  option = cli.Option "foo" --required
  expect option.is-required

  option = cli.Option "foo" --hidden
  expect option.is-hidden

  option = cli.Option "foo" --multi
  expect option.is-multi

  option = cli.Option "foo" --multi --split-commas
  expect option.should-split-commas

  option = cli.Option "foo" --short-name="f" \
      --help="Baz." --required --multi \
      --split-commas --type="some_type"
  expect-equals option.name "foo"
  expect-equals "some_type" option.type
  expect-equals option.short-name "f"
  expect-equals option.help "Baz."
  expect option.is-required
  expect-not option.is-hidden
  expect option.is-multi
  expect option.should-split-commas
  expect-not option.is-flag

  value := option.parse "foo"
  expect-equals "foo" value

test-enum:
  option := cli.OptionEnum "enum" ["foo", "bar"]
  expect-equals option.name "enum"
  expect-null option.default
  expect-equals "foo|bar" option.type

  option = cli.OptionEnum "enum" ["foo", "bar"] --default="bar"
  expect-equals "bar" option.default

  value := option.parse "foo"
  expect-equals "foo" value

  value = option.parse "bar"
  expect-equals "bar" value

  expect-throw "Invalid value for option 'enum': 'baz'. Valid values are: foo, bar.":
    option.parse "baz"

test-patterns:
  option := cli.OptionPatterns "pattern" ["foo", "bar:<duration>", "baz=<address>"]
  expect-equals option.name "pattern"
  expect-null option.default
  expect-equals "foo|bar:<duration>|baz=<address>" option.type

  option = cli.OptionPatterns "pattern" ["foo", "bar:<duration>", "baz=<address>"] --default="bar:1h"
  expect-equals "bar:1h" option.default

  value := option.parse "foo"
  expect-equals "foo" value

  value = option.parse "bar:1h"
  expect-structural-equals { "bar": "1h" } value

  value = option.parse "baz=neverland"
  expect-structural-equals { "baz": "neverland" } value

  expect-throw "Invalid value for option 'pattern': 'baz'. Valid values are: foo, bar:<duration>, baz=<address>.":
    option.parse "baz"

  expect-throw "Invalid value for option 'pattern': 'not-there'. Valid values are: foo, bar:<duration>, baz=<address>.":
    option.parse "not-there"

test-int:
  option := cli.OptionInt "int"
  expect-equals option.name "int"
  expect-null option.default
  expect-equals "int" option.type

  option = cli.OptionInt "int" --default=42
  expect-equals 42 option.default

  value := option.parse "42"
  expect-equals 42 value

  expect-throw "Invalid integer value for option 'int': 'foo'.":
    option.parse "foo"

test-uuid:
  option := cli.OptionUuid "uuid"
  expect-equals option.name "uuid"
  expect-null option.default
  expect-equals "uuid" option.type

  option = cli.OptionUuid "uuid" --default=uuid.NIL
  expect-equals uuid.NIL option.default

  value := option.parse "00000000-0000-0000-0000-000000000000"
  expect-equals uuid.NIL value

  value = option.parse "00000000-0000-0000-0000-000000000001"
  expect-equals (uuid.parse "00000000-0000-0000-0000-000000000001") value

  expect-throw "Invalid value for option 'uuid': 'foo'. Expected a UUID.":
    option.parse "foo"

  expect-throw "Invalid value for option 'uuid': '00000000-0000-0000-0000-00000000000'. Expected a UUID.":
    option.parse "00000000-0000-0000-0000-00000000000"

test-flag:
  flag := cli.Flag "flag" --default=false
  expect-equals flag.name "flag"
  expect-identical false flag.default

  flag = cli.Flag "flag" --default=true
  expect-identical true flag.default

  value := flag.parse "true"
  expect-identical true value

  value = flag.parse "false"
  expect-identical false value

  expect-throw "Invalid value for boolean flag 'flag': 'foo'. Valid values are: true, false.":
    flag.parse "foo"

test-bad-combos:
  expect-throw "--split-commas is only valid for multi options.":
    cli.Option "foo" --split-commas

  expect-throw "Invalid short option name: '@'":
    cli.Option "bar" --short-name="@"

  expect-throw "Option can't be hidden and required.":
    cli.Option "foo" --hidden --required

  expect-throw "Option can't have default value and be required.":
    cli.Option "foo" --default="bar" --required

  expect-throw "Option can't have default value and be required.":
    cli.OptionInt "foo" --default=42 --required

  expect-throw "Option can't have default value and be required.":
    cli.Flag "foo" --default=false --required

  expect-throw "Multi option can't have default value.":
    cli.Option "foo" --default="bar" --multi

  expect-throw "Multi option can't have default value.":
    cli.OptionInt "foo" --default=42 --multi

  expect-throw "Multi option can't have default value.":
    cli.Flag "foo" --default=false --multi
