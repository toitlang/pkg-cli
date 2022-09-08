// Copyright (C) 2018 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import expect show *

import arguments show ArgumentParser UNLIMITED

main:
  test_empty
  test_command
  test_rest
  test_option
  test_option_alias
  test_multi_option
  test_rest_usage

test_empty:
  parser := ArgumentParser
  expect_error_parsing "Unknown option -f" parser ["-f"]
  expect_error_parsing "Unknown option --foo" parser ["--foo"]
  expect_error_parsing "Unknown option --foo" parser ["--foo=value"]
  expect_error_parsing "Unknown option --foo" parser ["--foo", "value"]
  expect_equals "Usage:\nargument_parser_test" (parser.usage --invoked_command="argument_parser_test")

test_command:
  parser := ArgumentParser
  sub1 := parser.add_command "sub1"
  sub2 := parser.add_command "sub2"

  // Usage for whole parser.
  expect_equals """
      Usage:
      argument_parser_test sub1
      argument_parser_test sub2""" (parser.usage --invoked_command="argument_parser_test")
  // Usage for sub1 subcommand.
  expect_equals """
      Usage:
      argument_parser_test sub1""" (parser.usage ["sub1"] --invoked_command="argument_parser_test")
  // Usage for sub2 subcommand.
  expect_equals """
      Usage:
      argument_parser_test sub2""" (parser.usage ["sub2"] --invoked_command="argument_parser_test")

  r := parser.parse ["sub1"]
  expect_equals "sub1" r.command
  expect r.rest.is_empty

  r = parser.parse ["sub2"]
  expect_equals "sub2" r.command
  expect r.rest.is_empty

  r = parser.parse ["foo"]
  expect_null r.command
  expect_equals 1 r.rest.size
  expect_equals "foo" r.rest[0]

  sub1.add_flag "foo" --short="f"
  expect_error_parsing "Unknown option --foo" parser ["--foo"]
  expect_error_parsing "Unknown option -f" parser ["-f"]
  expect_error_parsing "Unknown option --foo" parser ["sub2", "--foo"]
  expect_error_parsing "Unknown option -f" parser ["sub2", "-f"]

  r = parser.parse ["sub1"]
  expect (not r["foo"])
  r = parser.parse ["sub1", "--foo"]
  expect r["foo"]
  r = parser.parse ["sub1", "-f"]
  expect r["foo"]

test_rest:
  parser := ArgumentParser
  parser.add_option "foo"
  parser.add_option "bar"

  expect_equals """
      Usage:
      argument_parser_test [--foo=<foo>] [--bar=<bar>]""" (parser.usage [] --invoked_command="argument_parser_test")

  r := parser.parse []
  expect_equals 0 r.rest.size

  r = parser.parse ["x"]
  expect_equals 1 r.rest.size
  expect_equals "x" r.rest[0]

  r = parser.parse ["--foo", "0", "x"]
  expect_equals 1 r.rest.size
  expect_equals "x" r.rest[0]

  r = parser.parse ["--foo=0", "x"]
  expect_equals 1 r.rest.size
  expect_equals "x" r.rest[0]

  r = parser.parse ["x", "--foo", "0"]
  expect_equals 1 r.rest.size
  expect_equals "x" r.rest[0]

  r = parser.parse ["x", "--foo=0"]
  expect_equals 1 r.rest.size
  expect_equals "x" r.rest[0]

  r = parser.parse ["x", "--foo", "0", "--bar=1", "y"]
  expect_equals 2 r.rest.size
  expect_equals "x" r.rest[0]
  expect_equals "y" r.rest[1]

  r = parser.parse ["--", "--bar"]
  expect_equals 1 r.rest.size
  expect_equals "--bar" r.rest[0]

  r = parser.parse ["--foo=0", "--", "--bar"]
  expect_equals 1 r.rest.size
  expect_equals "--bar" r.rest[0]

  r = parser.parse ["x", "--foo=0", "--", "--bar"]
  expect_equals 2 r.rest.size
  expect_equals "x" r.rest[0]
  expect_equals "--bar" r.rest[1]

test_option:
  parser := ArgumentParser
  parser.add_option "x"
  parser.add_option "xy"
  parser.add_option "a" --default="da"
  parser.add_option "ab" --default="dab"
  parser.add_flag "verbose" --short="v"
  parser.add_flag "foobar" --short="foo"

  expect_equals """
      Usage:
      argument_parser_test [--x=<x>] [--xy=<xy>] [--a=<a>] [--ab=<ab>] [--verbose|-v] [--foobar|-foo]""" (parser.usage --invoked_command="argument_parser_test")

  r := parser.parse []
  expect_null r["x"]
  expect_null r["xy"]
  expect_equals "da" r["a"]
  expect_equals "dab" r["ab"]
  expect (not r["verbose"])
  expect_error "No option named 'v'": r["v"]
  expect (not r["foobar"])
  expect_error "No option named 'foo'": r["foo"]

  r = parser.parse ["--x=1234"]
  expect_equals "1234" r["x"]
  expect_null r["xy"]
  r = parser.parse ["--x", "2345"]
  expect_equals "2345" r["x"]
  expect_null r["xy"]
  r = parser.parse ["--xy=1234"]
  expect_null r["x"]
  expect_equals "1234" r["xy"]
  r = parser.parse ["--xy", "2345"]
  expect_null r["x"]
  expect_equals "2345" r["xy"]

  r = parser.parse ["--a=1234"]
  expect_equals "1234" r["a"]
  expect_equals "dab" r["ab"]
  r = parser.parse ["--a", "2345"]
  expect_equals "2345" r["a"]
  expect_equals "dab" r["ab"]
  r = parser.parse ["--ab=1234"]
  expect_equals "da" r["a"]
  expect_equals "1234" r["ab"]
  r = parser.parse ["--ab", "2345"]
  expect_equals "da" r["a"]
  expect_equals "2345" r["ab"]

  r = parser.parse ["--verbose"]
  expect r["verbose"]
  expect (not r["foobar"])
  r = parser.parse ["-v"]
  expect r["verbose"]
  expect (not r["foobar"])
  r = parser.parse ["--foobar"]
  expect (not r["verbose"])
  expect r["foobar"]
  r = parser.parse ["-foo"]
  expect (not r["verbose"])
  expect r["foobar"]

  expect_error_parsing "No value provided for option --x" parser ["--x"]
  expect_error_parsing "No value provided for option --xy" parser ["--xy"]
  expect_error_parsing "No value provided for option --a" parser ["--a"]
  expect_error_parsing "No value provided for option --ab" parser ["--ab"]

  expect_error_parsing "Option was provided multiple times: --ab=2" parser ["--ab=0", "--ab=2"]

test_option_alias:
  parser := ArgumentParser
  parser.add_flag "flag" --short="f"
  parser.add_option "evaluate"
  parser.add_alias "evaluate" "e"

  expect_equals
      "Usage:\nargument_parser_test [--flag|-f] [--evaluate|-e=<evaluate>]"
      parser.usage [] --invoked_command="argument_parser_test"

  r := parser.parse ["--evaluate", "123"]
  expect_equals "123" r["evaluate"]
  r = parser.parse ["--evaluate=123"]
  expect_equals "123" r["evaluate"]
  expect_error_parsing "Unknown option --evaluate123" parser ["--evaluate123"]

  expect_error_parsing "No value provided for option -e" parser ["-e"]
  expect_error_parsing "Unknown option --e234" parser ["--e234"]

  r = parser.parse ["-e", "234"]
  expect_equals "234" r["evaluate"]
  r = parser.parse ["-e234"]
  expect_equals "234" r["evaluate"]
  r = parser.parse ["-e234"]
  expect_equals "234" r["evaluate"]
  r = parser.parse ["-e345", "-f"]
  expect_equals "345" r["evaluate"]
  expect r["flag"]
  r = parser.parse ["-e" ,"456"]
  expect_equals "456" r["evaluate"]
  r = parser.parse ["-e" ,"456", "--flag"]
  expect_equals "456" r["evaluate"]
  expect r["flag"]

  r = parser.parse ["-e", "234 + 345"]
  expect_equals "234 + 345" r["evaluate"]
  r = parser.parse ["-e234 + 345"]
  expect_equals "234 + 345" r["evaluate"]

test_multi_option:
  parser := ArgumentParser
  parser.add_multi_option "option"
  parser.add_multi_option "multi" --no-split_commas

  expect_equals
      "Usage:\nargument_parser_test [--option=<option>]* [--multi=<multi>]*"
      parser.usage [] --invoked_command="argument_parser_test"

  r := parser.parse []
  expect_list_equals [] r["option"]
  expect_list_equals [] r["multi"]

  r = parser.parse ["--option", "123"]
  expect_list_equals ["123"] r["option"]
  r = parser.parse ["--option=123"]
  expect_list_equals ["123"] r["option"]
  expect_error_parsing "Unknown option --option123" parser ["--option123"]

  r = parser.parse ["--option", "123", "--option=456"]
  expect_list_equals ["123", "456"] r["option"]
  r = parser.parse ["--option=123,456"]
  expect_list_equals ["123", "456"] r["option"]

  r = parser.parse ["--multi", "123"]
  expect_list_equals ["123"] r["multi"]
  r = parser.parse ["--multi=123"]
  expect_list_equals ["123"] r["multi"]
  expect_error_parsing "Unknown option --multi123" parser ["--multi123"]

  r = parser.parse ["--multi", "123", "--multi=456"]
  expect_list_equals ["123", "456"] r["multi"]
  r = parser.parse ["--multi=123,456"]
  expect_list_equals ["123,456"] r["multi"]

test_rest_usage:
  two_argument_usage
  two_argument_plus_usage
  glob_file_usage
  test_subcommand_usage

two_argument_usage:
  parser := ArgumentParser
  parser.describe_rest ["foo", "bar"]
  parser.add_flag "flag"

  expect_equals
      "Usage:\nargument_parser_test [--flag] [--] <foo> <bar>"
      parser.usage [] --invoked_command="argument_parser_test"

  expect_error_parsing "Too few arguments" parser []
  expect_error_parsing "Too few arguments" parser ["--flag"]
  expect_error_parsing "Too few arguments" parser ["--flag", "foo"]
  expect_error_parsing "Too many arguments" parser ["--flag", "foo", "bar", "fizz"]

two_argument_plus_usage:
  parser := ArgumentParser
  parser.describe_rest ["foo", "bar", "..."]
  parser.add_flag "flag"

  expect_equals
      "Usage:\nargument_parser_test [--flag] [--] <foo> <bar> ..."
      parser.usage [] --invoked_command="argument_parser_test"

  expect_error_parsing "Too few arguments" parser []
  expect_error_parsing "Too few arguments" parser ["--flag"]
  expect_error_parsing "Too few arguments" parser ["--flag", "foo"]
  r := parser.parse ["f", "b"]
  expect_equals 2 r.rest.size
  r = parser.parse ["f", "b", "fizz"]
  expect_equals 3 r.rest.size
  r = parser.parse ["f", "b", "fizz", "fizz", "fizz"]
  expect_equals 5 r.rest.size

glob_file_usage:
  // At least one file, either with dots or explicit maximum.
  parser1 := ArgumentParser
  parser2 := ArgumentParser
  parser1.describe_rest ["file", "..."]
  parser2.describe_rest ["file"] --max=UNLIMITED
  expect_equals 1         parser1.rest_minimum
  expect_equals 1         parser2.rest_minimum
  expect_equals UNLIMITED parser1.rest_maximum
  expect_equals UNLIMITED parser2.rest_maximum

  parser1_usage := parser1.usage --invoked_command="argument_parser_test"
  parser2_usage := parser2.usage --invoked_command="argument_parser_test"
  expect_equals
      "Usage:\nargument_parser_test [--] <file> ..."
      parser1_usage
  expect_equals parser1_usage parser2_usage

  // Zero or more files:
  parser1 = ArgumentParser
  parser2 = ArgumentParser
  parser1.describe_rest ["[files]", "..."]
  parser2.describe_rest ["[files]"] --max=UNLIMITED
  expect_equals 0         parser1.rest_minimum
  expect_equals 0         parser2.rest_minimum
  expect_equals UNLIMITED parser1.rest_maximum
  expect_equals UNLIMITED parser2.rest_maximum

  parser1_usage = parser1.usage --invoked_command="argument_parser_test"
  parser2_usage = parser2.usage --invoked_command="argument_parser_test"
  expect_equals
      "Usage:\nargument_parser_test [--] [files] ..."
      parser1_usage
  expect_equals parser1_usage parser2_usage

  // Just ... as a rest argument name:
  parser1 = ArgumentParser
  parser2 = ArgumentParser
  parser3 := ArgumentParser
  parser1.describe_rest ["..."]
  parser3.describe_rest --max=UNLIMITED
  expect_equals 0         parser1.rest_minimum
  expect_equals 0         parser2.rest_minimum
  expect_equals 0         parser3.rest_minimum
  expect_equals UNLIMITED parser1.rest_maximum
  expect_equals UNLIMITED parser2.rest_maximum
  expect_equals UNLIMITED parser3.rest_maximum

  parser1_usage = parser1.usage --invoked_command="argument_parser_test"
  parser2_usage = parser2.usage --invoked_command="argument_parser_test"
  parser3_usage := parser3.usage --invoked_command="argument_parser_test"
  expect_equals
      "Usage:\nargument_parser_test [--] ..."
      parser1_usage
  expect_equals parser1_usage parser3_usage

  // For backwards compatibility if you say nothing about the rest arguments we don't
  // pretend to know what they might look like in the usage message.
  expect_equals
      "Usage:\nargument_parser_test"
      parser2.usage [] --invoked_command="argument_parser_test"

  // Output-input files, at least one input file.
  parser1 = ArgumentParser
  parser2 = ArgumentParser
  parser1.describe_rest ["output-file", "input-files", "..."]
  parser2.describe_rest ["output-file", "input-files"] --max=UNLIMITED
  expect_equals 2         parser1.rest_minimum
  expect_equals 2         parser2.rest_minimum
  expect_equals UNLIMITED parser1.rest_maximum
  expect_equals UNLIMITED parser2.rest_maximum

  parser1_usage = parser1.usage --invoked_command="argument_parser_test"
  parser2_usage = parser2.usage --invoked_command="argument_parser_test"
  expect_equals
      "Usage:\nargument_parser_test [--] <output-file> <input-files> ..."
      parser1_usage
  expect_equals parser1_usage parser2_usage

  // Unnamed optional arguments just get called [argument].
  parser1 = ArgumentParser
  parser1.describe_rest --max=3

  expect_equals
      "Usage:\ndig [--] [argument] [argument] [argument]"
      parser1.usage --invoked_command="dig"

  // Unnamed mandatory arguments just get called <argument>.
  parser1 = ArgumentParser
  parser1.describe_rest --min=1 --max=3

  expect_equals
      "Usage:\ndig [--] <argument> [argument] [argument]"
      parser1.usage --invoked_command="dig"

test_subcommand_usage:
  parser := ArgumentParser

  parser.add_flag "flag"

  frob := parser.add_command "frobinate"
  frob.describe_rest ["in", "out", "[err]"]
  munge := parser.add_command "munge"
  whack := parser.add_command "whack"
  whack.describe_rest ["implement"]
  munge.add_flag "bite"
  whack.add_flag "with_extreme_prejudice"

  GADGET_USAGE ::= """
      Usage:
      gadget [--flag] frobinate [--] <in> <out> [err]
      gadget [--flag] munge [--bite]
      gadget [--flag] whack [--with_extreme_prejudice] [--] <implement>"""

  expect_equals
      GADGET_USAGE
      parser.usage --invoked_command="gadget"

  // If we pass the argument list "frobinate" then the usage concentrates on
  // the frobinate-specific parts of the help message.  The top level options
  // are not spelled out.
  FROBINATE_USAGE ::= "Usage:\ngadget [options] frobinate [--] <in> <out> [err]"
  expect_equals
      FROBINATE_USAGE
      parser.usage ["frobinate"] --invoked_command="gadget"
  expect_equals
      FROBINATE_USAGE
      parser.usage ["frobinate", "--no_such_flag"] --invoked_command="gadget"
  expect_equals
      FROBINATE_USAGE
      parser.usage ["--flag", "frobinate", "--no_such_flag"] --invoked_command="gadget"

  // If the flag is invalid we'll give the full usage message though.
  expect_equals
      GADGET_USAGE
      parser.usage ["--nosuchflag", "frobinate", "--no_such_flag"] --invoked_command="gadget"


  expect_equals """
      Usage:
      gadget [options] munge [--bite]""" (parser.usage ["munge"] --invoked_command="gadget")

expect_error name [code]:
  expect_equals
    name
    catch code

expect_error_parsing name parser arguments:
  error := false
  exception := catch:
    parser.parse arguments: | message usage |
      expect_equals
        name
        message
      error = true
  if exception == null:
    throw "Expected exception '$name', but didn't get an exception"
  expect_equals name exception
  expect_equals true error
