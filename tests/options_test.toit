// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli
import cli.utils_ show with-tmp-directory
import expect show *
import host.directory
import host.file
import uuid show Uuid

main:
  test-string
  test-enum
  test-patterns
  test-int
  test-uuid
  test-flag
  test-path
  test-in-file
  test-out-file
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

  value := option.parse "foo" --if-error=: throw it
  expect-equals "foo" value

test-enum:
  option := cli.OptionEnum "enum" ["foo", "bar"]
  expect-equals option.name "enum"
  expect-null option.default
  expect-equals "foo|bar" option.type

  option = cli.OptionEnum "enum" ["foo", "bar"] --default="bar"
  expect-equals "bar" option.default

  value := option.parse "foo" --if-error=: throw it
  expect-equals "foo" value

  value = option.parse "bar" --if-error=: throw it
  expect-equals "bar" value

  expect-throw "Invalid value for option 'enum': 'baz'. Valid values are: foo, bar.":
    option.parse "baz" --if-error=: throw it

test-patterns:
  option := cli.OptionPatterns "pattern" ["foo", "bar:<duration>", "baz=<address>"]
  expect-equals option.name "pattern"
  expect-null option.default
  expect-equals "foo|bar:<duration>|baz=<address>" option.type

  option = cli.OptionPatterns "pattern" ["foo", "bar:<duration>", "baz=<address>"] --default="bar:1h"
  expect-equals "bar:1h" option.default

  value := option.parse "foo" --if-error=: throw it
  expect-equals "foo" value

  value = option.parse "bar:1h" --if-error=: throw it
  expect-structural-equals { "bar": "1h" } value

  value = option.parse "baz=neverland" --if-error=: throw it
  expect-structural-equals { "baz": "neverland" } value

  expect-throw "Invalid value for option 'pattern': 'baz'. Valid values are: foo, bar:<duration>, baz=<address>.":
    option.parse "baz" --if-error=: throw it

  expect-throw "Invalid value for option 'pattern': 'not-there'. Valid values are: foo, bar:<duration>, baz=<address>.":
    option.parse "not-there" --if-error=: throw it

test-int:
  option := cli.OptionInt "int"
  expect-equals option.name "int"
  expect-null option.default
  expect-equals "int" option.type

  option = cli.OptionInt "int" --default=42
  expect-equals 42 option.default

  value := option.parse "42" --if-error=: throw it
  expect-equals 42 value

  expect-throw "Invalid integer value for option 'int': 'foo'.":
    option.parse "foo" --if-error=: throw it

test-uuid:
  option := cli.OptionUuid "uuid"
  expect-equals option.name "uuid"
  expect-null option.default
  expect-equals "uuid" option.type

  option = cli.OptionUuid "uuid" --default=Uuid.NIL
  expect-equals Uuid.NIL option.default

  value := option.parse "00000000-0000-0000-0000-000000000000" --if-error=: throw it
  expect-equals Uuid.NIL value

  value = option.parse "00000000-0000-0000-0000-000000000001" --if-error=: throw it
  expect-equals (Uuid.parse "00000000-0000-0000-0000-000000000001") value

  expect-throw "Invalid value for option 'uuid': 'foo'. Expected a UUID.":
    option.parse "foo" --if-error=: throw it

  expect-throw "Invalid value for option 'uuid': '00000000-0000-0000-0000-00000000000'. Expected a UUID.":
    option.parse "00000000-0000-0000-0000-00000000000" --if-error=: throw it

test-flag:
  flag := cli.Flag "flag" --default=false
  expect-equals flag.name "flag"
  expect-identical false flag.default

  flag = cli.Flag "flag" --default=true
  expect-identical true flag.default

  value := flag.parse "true" --if-error=: throw it
  expect-identical true value

  value = flag.parse "false" --if-error=: throw it
  expect-identical false value

  expect-throw "Invalid value for boolean flag 'flag': 'foo'. Valid values are: true, false.":
    flag.parse "foo" --if-error=: throw it

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

test-path:
  option := cli.OptionPath "config" --help="Config file."
  expect-equals "config" option.name
  expect-null option.default
  expect-equals "path" option.type
  expect-not option.is-flag
  expect-not option.is-directory

  option = cli.OptionPath "output" --directory --help="Output dir."
  expect-equals "directory" option.type
  expect option.is-directory

  option = cli.OptionPath "input" --default="/tmp/foo" --help="Input."
  expect-equals "/tmp/foo" option.default

  value := option.parse "/some/path" --if-error=: throw it
  expect-equals "/some/path" value

  // OptionPath supports the same combos as other options.
  option = cli.OptionPath "files" --multi --help="Files."
  expect option.is-multi

  expect-throw "Multi option can't have default value.":
    cli.OptionPath "foo" --default="bar" --multi

test-in-file:
  option := cli.OptionInFile "input" --help="Input file."
  expect-equals "input" option.name
  expect-null option.default
  expect-equals "file" option.type
  expect-not option.is-flag
  expect option.allow-dash
  expect option.check-exists

  // Test with custom options.
  option = cli.OptionInFile "input" --no-allow-dash --no-check-exists
  expect-not option.allow-dash
  expect-not option.check-exists

  // Test parse returns InFile for a path.
  in-file/cli.InFile := option.parse "/some/path" --if-error=: throw it
  expect-equals "/some/path" in-file.path
  expect-not in-file.is-stdin

  // Test parse returns InFile for "-" when allow-dash is true.
  option = cli.OptionInFile "input"
  in-file = option.parse "-" --if-error=: throw it
  expect-null in-file.path
  expect in-file.is-stdin

  // Test "-" is treated as literal when allow-dash is false.
  option = cli.OptionInFile "input" --no-allow-dash --no-check-exists
  in-file = option.parse "-" --if-error=: throw it
  expect-equals "-" in-file.path
  expect-not in-file.is-stdin

  // Test check-exists fails for missing files.
  option = cli.OptionInFile "input" --check-exists
  expect-throw "File not found for option 'input': '/nonexistent/file.txt'.":
    option.parse "/nonexistent/file.txt" --if-error=: throw it

  // Test check on InFile directly.
  option = cli.OptionInFile "input" --no-check-exists
  in-file = option.parse "/nonexistent/file.txt" --if-error=: throw it
  expect-throw "File not found for option 'input': '/nonexistent/file.txt'.":
    in-file.check

  // Test check-exists is skipped for "-".
  in-file = option.parse "-" --if-error=: throw it
  expect in-file.is-stdin

  // Test check-exists is skipped for help examples.
  in-file = option.parse "/nonexistent/file.txt" --if-error=(: throw it) --for-help-example
  expect-equals "/nonexistent/file.txt" in-file.path

  // Test reading from a real file.
  with-tmp-directory: | tmpdir |
    test-path := "$tmpdir/test.txt"
    file.write-contents --path=test-path "hello world"
    option = cli.OptionInFile "input"
    in-file = option.parse test-path --if-error=: throw it
    expect-equals test-path in-file.path

    // Test do [block].
    in-file.do: | reader |
      data := reader.read
      expect-equals "hello world" data.to-string

    // Test read-contents.
    in-file = option.parse test-path --if-error=: throw it
    contents := in-file.read-contents
    expect-equals "hello world" contents.to-string

  // Test bad combos.
  expect-throw "Multi option can't have default value.":
    cli.OptionInFile "foo" --default="bar" --multi

test-out-file:
  option := cli.OptionOutFile "output" --help="Output file."
  expect-equals "output" option.name
  expect-null option.default
  expect-equals "file" option.type
  expect-not option.is-flag
  expect option.allow-dash
  expect-not option.create-directories

  // Test with custom options.
  option = cli.OptionOutFile "output" --no-allow-dash --create-directories
  expect-not option.allow-dash
  expect option.create-directories

  // Test parse returns OutFile for a path.
  out-file/cli.OutFile := option.parse "/some/path" --if-error=: throw it
  expect-equals "/some/path" out-file.path
  expect-not out-file.is-stdout

  // Test parse returns OutFile for "-" when allow-dash is true.
  option = cli.OptionOutFile "output"
  out-file = option.parse "-" --if-error=: throw it
  expect-null out-file.path
  expect out-file.is-stdout

  // Test "-" is treated as literal when allow-dash is false.
  option = cli.OptionOutFile "output" --no-allow-dash
  out-file = option.parse "-" --if-error=: throw it
  expect-equals "-" out-file.path
  expect-not out-file.is-stdout

  // Test writing to a real file.
  with-tmp-directory: | tmpdir |
    test-path := "$tmpdir/output.txt"
    option = cli.OptionOutFile "output"
    out-file = option.parse test-path --if-error=: throw it

    // Test do [block].
    out-file.do: | writer |
      writer.write "hello output"

    contents := file.read-contents test-path
    expect-equals "hello output" contents.to-string

    // Test write-contents.
    out-file.write-contents "written directly"
    contents = file.read-contents test-path
    expect-equals "written directly" contents.to-string

    // Test create-directories.
    nested-path := "$tmpdir/a/b/c/output.txt"
    option = cli.OptionOutFile "output" --create-directories
    out-file = option.parse nested-path --if-error=: throw it

    out-file.do: | writer |
      writer.write "nested"

    contents = file.read-contents nested-path
    expect-equals "nested" contents.to-string

    // Test write-contents with create-directories.
    nested-path2 := "$tmpdir/d/e/f/output.txt"
    out-file = option.parse nested-path2 --if-error=: throw it
    out-file.write-contents "nested-written"
    contents = file.read-contents nested-path2
    expect-equals "nested-written" contents.to-string

    // Test create-directories=false fails for missing parent dirs.
    missing-path := "$tmpdir/x/y/z/output.txt"
    option = cli.OptionOutFile "output"
    out-file = option.parse missing-path --if-error=: throw it
    expect-throw "FILE_NOT_FOUND: \"$missing-path\"":
      out-file.open

  // Test bad combos.
  expect-throw "Multi option can't have default value.":
    cli.OptionOutFile "foo" --default="bar" --multi
