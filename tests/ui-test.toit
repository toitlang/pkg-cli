// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli.ui show *
import cli.test show TestUi TestHumanPrinter TestPlainPrinter TestJsonPrinter TestPrinter
import encoding.json
import expect show *

class TestStructuredPrinter extends HumanPrinterBase implements TestPrinter:
  test-ui_/TestUi? := null
  structured/List ::= []

  needs-structured --kind/int -> bool: return true

  print_ str/string:
    if not test-ui_.quiet_: print "str"
    test-ui_.stdout-messages.add "$str\n"

  emit-structured --kind/int data:
    structured.add data
    if not test-ui_.quiet_:
      test-ui_.stdout-messages.add (json.stringify data)

  set-test-ui_ test-ui/TestUi:
    test-ui_ = test-ui

  reset -> none:
    structured.clear

main:
  test-human
  test-plain
  test-structured
  test-json

test-human:
  printer := TestHumanPrinter
  ui := TestUi --printer=printer

  ui.emit --info "hello"
  expect-equals "hello\n" ui.stdout
  ui.reset

  ui.emit --info ["hello", "world"]
  expect-equals "[hello, world]\n" ui.stdout
  ui.reset

  ui.emit-list --result ["hello", "world"]
  expect-equals "hello\nworld\n" ui.stdout
  ui.reset

  ui.emit-list --result --title="French" ["bonjour", "monde"]
  expect-equals "French:\n  bonjour\n  monde\n" ui.stdout
  ui.reset

  ui.emit-table --result --header={"x": "x", "y": "y"} [
    { "x": "a", "y": "b" },
    { "x": "c", "y": "d" },
  ]
  expect-equals """
  ┌───┬───┐
  │ x   y │
  ├───┼───┤
  │ a   b │
  │ c   d │
  └───┴───┘
  """ ui.stdout
  ui.reset

  ui.emit-table --result --header={ "left": "long", "right": "even longer" } [
    { "left": "a",      "right": "short" },
    { "left": "longer", "right": "d" },
  ]
  expect-equals """
  ┌────────┬─────────────┐
  │ long     even longer │
  ├────────┼─────────────┤
  │ a        short       │
  │ longer   d           │
  └────────┴─────────────┘
  """ ui.stdout
  ui.reset

  ui.emit-table --result --header={"left": "no", "right": "rows"} []
  expect-equals """
  ┌────┬──────┐
  │ no   rows │
  ├────┼──────┤
  └────┴──────┘
  """ ui.stdout
  ui.reset

  ui.emit-table --result --header={"left": "with", "right": "ints"} [
    { "left": 1, "right": 2, },
    { "left": 3, "right": 4, },
  ]
  expect-equals """
  ┌──────┬──────┐
  │ with   ints │
  ├──────┼──────┤
  │ 1      2    │
  │ 3      4    │
  └──────┴──────┘
  """ ui.stdout
  ui.reset

  ui.emit --info {
    "a": "b",
    "c": "d",
  }
  expect-equals "{a: b, c: d}\n" ui.stdout
  ui.reset

  ui.emit-map --result {
    "a": "b",
    "c": "d",
  }
  expect-equals """
  a: b
  c: d
  """ ui.stdout
  ui.reset

  // Nested maps.
  ui.emit-map --result {
    "a": {
      "b": "c",
      "d": "e",
    },
    "f": "g",
  }
  expect-equals """
  a:
    b: c
    d: e
  f: g
  """ ui.stdout
  ui.reset

  ui.emit --info "foo"
  expect-equals "foo\n" ui.stdout
  ui.reset

  ui.emit --warning "foo"
  expect-equals "Warning: foo\n" ui.stdout
  ui.reset

  ui.emit --error "foo"
  expect-equals "Error: foo\n" ui.stdout
  ui.reset

  ui.emit-map --result {
    "entry with int": 499,
  }
  expect-equals """
  entry with int: 499
  """ ui.stdout
  ui.reset

test-plain:
    printer := TestPlainPrinter --no-needs-structured
    ui := TestUi --printer=printer

    ui.emit --info "hello"
    expect-equals "hello\n" ui.stdout
    ui.reset

    ui.emit --info ["hello", "world"]
    expect-equals "[hello, world]\n" ui.stdout
    ui.reset

    ui.emit-list --result ["hello", "world"]
    expect-equals "hello\nworld\n" ui.stdout
    ui.reset

    ui.emit-list --result --title="French" ["bonjour", "monde"]
    expect-equals "bonjour\nmonde\n" ui.stdout
    ui.reset

    ui.emit-table --result --header={"x": "x", "y": "y"} [
      { "x": "a", "y": "b" },
      { "x": "c", "y": "d" },
    ]
    expect-equals """
    a b
    c d
    """ ui.stdout
    ui.reset

    ui.emit-table --result --header={ "left": "long", "right": "even longer" } [
      { "left": "a",      "right": "short" },
      { "left": "longer", "right": "d" },
    ]
    expect-equals """
    a      short
    longer d
    """ ui.stdout
    ui.reset

    ui.emit-table --result --header={"left": "no", "right": "rows"} []
    expect-equals "" ui.stdout
    ui.reset

    ui.emit-table --result --header={"left": "with", "right": "ints"} [
      { "left": 1, "right": 2, },
      { "left": 3, "right": 4, },
    ]
    expect-equals """
    1 2
    3 4
    """ ui.stdout
    ui.reset

    ui.emit --info {
      "a": "b",
      "c": "d",
    }
    expect-equals "{a: b, c: d}\n" ui.stdout
    ui.reset

    ui.emit-map --result {
      "a": "b",
      "c": "d",
    }
    expect-equals """
    a: b
    c: d
    """ ui.stdout
    ui.reset

    // Nested maps.
    ui.emit-map --result {
      "a": {
        "b": "c",
        "d": "e",
      },
      "f": "g",
    }
    expect-equals """
    a.b: c
    a.d: e
    f: g
    """ ui.stdout
    ui.reset

    ui.emit --info "foo"
    expect-equals "foo\n" ui.stdout
    ui.reset

    ui.emit --warning "foo"
    expect-equals "foo\n" ui.stdout
    ui.reset

    ui.emit --error "foo"
    expect-equals "foo\n" ui.stdout
    ui.reset

    ui.emit-map --result {
      "entry with int": 499,
    }
    expect-equals """
    entry with int: 499
    """ ui.stdout
    ui.reset

test-structured:
  printer := TestStructuredPrinter
  ui := TestUi --printer=printer

  ui.emit --info "hello"
  expect-equals ["hello"] printer.structured
  printer.reset

  map := {
    "foo": 1,
    "bar": 2,
  }
  ui.emit --result --structured=(: map) --text=(: "$map")
  expect-equals 1 printer.structured.size
  expect-identical map printer.structured[0]
  printer.reset

  list := [
    "foo",
    "bar",
  ]
  ui.emit --info list
  expect-equals 1 printer.structured.size
  expect-identical list printer.structured[0]
  printer.reset

  ui.emit-list --result --title="French" ["bonjour", "monde"]
  expect-equals 1 printer.structured.size
  expect-equals ["bonjour", "monde"] printer.structured[0]
  printer.reset

  data := [
    { "x": "a", "y": "b" },
    { "x": "c", "y": "d" },
  ]
  ui.emit-table --result --header={"x": "x", "y": "y"} data
  expect-equals 1 printer.structured.size
  expect-structural-equals data printer.structured[0]
  printer.reset

test-json:
  printer := TestJsonPrinter
  ui := TestUi --printer=printer

  // Anything that isn't a result is emitted on stderr as if it was
  // a human Ui.
  ui.emit --info "hello"
  expect-equals "hello\n" ui.stderr
  ui.reset

  // Results are emitted on stdout as JSON.
  ui.emit --result "hello"
  expect-equals "\"hello\"" ui.stdout
  ui.reset

  ui.emit-map --result {
    "foo": 1,
    "bar": 2,
  }
  expect-equals "{\"foo\":1,\"bar\":2}" ui.stdout

  ui.emit --warning "some warning"
  expect-equals "Warning: some warning\n" ui.stderr
  ui.reset

  ui.emit --error "some error"
  expect-equals "Error: some error\n" ui.stderr
  ui.reset

  expect ui.wants-structured  // By default the kind is "Ui.RESULT".
  expect (ui.wants-structured --kind=Ui.RESULT)
  expect-not (ui.wants-structured --kind=Ui.INFO)
  expect-not ui.wants-human  // By default the kind is "Ui.RESULT".
  expect-not (ui.wants-human --kind=Ui.RESULT)
  expect (ui.wants-human --kind=Ui.INFO)
