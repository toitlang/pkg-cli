// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli
import expect show *

main:
  test_string
  test_enum
  test_int
  test_flag
  test_bad_combos

test_string:
  option := cli.Option "foo"
  expect_equals option.name "foo"
  expect_null option.default
  expect_equals "string" option.type
  expect_null option.short_name
  expect_null option.short_help
  expect_not option.is_required
  expect_not option.is_hidden
  expect_not option.is_multi
  expect_not option.should_split_commas
  expect_not option.is_flag

  option = cli.Option "foo" --default="some_default"
  expect_equals "some_default" option.default

  option = cli.Option "foo" --short_name="f"
  expect_equals "f" option.short_name

  option = cli.Option "foo" --short_name="foo"
  expect_equals "foo" option.short_name

  option = cli.Option "foo" --short_help="Some_help."
  expect_equals "Some_help." option.short_help

  option = cli.Option "foo" --required
  expect option.is_required

  option = cli.Option "foo" --hidden
  expect option.is_hidden

  option = cli.Option "foo" --multi
  expect option.is_multi

  option = cli.Option "foo" --multi --split_commas
  expect option.should_split_commas

  option = cli.Option "foo" --short_name="f" \
      --short_help="Baz." --required --multi \
      --split_commas --type="some_type"
  expect_equals option.name "foo"
  expect_equals "some_type" option.type
  expect_equals option.short_name "f"
  expect_equals option.short_help "Baz."
  expect option.is_required
  expect_not option.is_hidden
  expect option.is_multi
  expect option.should_split_commas
  expect_not option.is_flag

  value := option.parse "foo"
  expect_equals "foo" value

test_enum:
  option := cli.OptionEnum "enum" ["foo", "bar"]
  expect_equals option.name "enum"
  expect_null option.default
  expect_equals "foo|bar" option.type

  option = cli.OptionEnum "enum" ["foo", "bar"] --default="bar"
  expect_equals "bar" option.default

  value := option.parse "foo"
  expect_equals "foo" value

  value = option.parse "bar"
  expect_equals "bar" value

  expect_throw "Invalid value for option 'enum': 'baz'. Valid values are: foo, bar.":
    option.parse "baz"

test_int:
  option := cli.OptionInt "int"
  expect_equals option.name "int"
  expect_null option.default
  expect_equals "int" option.type

  option = cli.OptionInt "int" --default=42
  expect_equals 42 option.default

  value := option.parse "42"
  expect_equals 42 value

  expect_throw "Invalid integer value for option 'int': 'foo'.":
    option.parse "foo"

test_flag:
  flag := cli.Flag "flag" --default=false
  expect_equals flag.name "flag"
  expect_identical false flag.default

  flag = cli.Flag "flag" --default=true
  expect_identical true flag.default

  value := flag.parse "true"
  expect_identical true value

  value = flag.parse "false"
  expect_identical false value

  expect_throw "Invalid value for boolean flag 'flag': 'foo'. Valid values are: true, false.":
    flag.parse "foo"

test_bad_combos:
  expect_throw "--split_commas is only valid for multi options.":
    cli.Option "foo" --split_commas

  expect_throw "Invalid short option name: '@'":
    cli.Option "bar" --short_name="@"

  expect_throw "Option can't be hidden and required.":
    cli.Option "foo" --hidden --required

  expect_throw "Option can't have default value and be required.":
    cli.Option "foo" --default="bar" --required

  expect_throw "Option can't have default value and be required.":
    cli.OptionInt "foo" --default=42 --required

  expect_throw "Option can't have default value and be required.":
    cli.Flag "foo" --default=false --required

  expect_throw "Multi option can't have default value.":
    cli.Option "foo" --default="bar" --multi

  expect_throw "Multi option can't have default value.":
    cli.OptionInt "foo" --default=42 --multi

  expect_throw "Multi option can't have default value.":
    cli.Flag "foo" --default=false --multi
