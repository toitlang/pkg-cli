// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli.ui show *
import encoding.json
import expect show *

class TestHumanPrinter extends HumanPrinterBase:
  stdout/string := ""
  structured/List := []

  reset:
    stdout = ""
    structured.clear

  needs-structured_/bool

  constructor --needs-structured/bool:
    needs-structured_ = needs-structured

  needs-structured --kind/int -> bool:
    return needs-structured_

  print_ str/string:
    stdout += "$str\n"

  emit-structured --kind/int o:
    structured.add o


class TestPlainPrinter extends PlainPrinterBase:
  needs-structured_/bool

  stdout/string := ""
  stderr/string := ""

  constructor --needs-structured/bool:
    needs-structured_ = needs-structured

  needs-structured --kind/int -> bool:
    return needs-structured_

  reset:
    stdout = ""
    stderr = ""

  print_ str/string:
    stdout += "$str\n"

  emit-structured --kind/int structured:
    stdout += (json.stringify structured)


class TestJsonPrinter extends JsonPrinter:
  stdout/string := ""
  stderr/string := ""

  reset:
    stdout = ""
    stderr = ""

  print_ str/string:
    stderr += "$str\n"

  emit-structured --kind/int structured:
    stdout += (json.stringify structured)

main:
  test-human
  test-plain
  test-structured
  test-json

test-human:
  printer := TestHumanPrinter --no-needs-structured
  ui := Ui --printer=printer

  ui.emit --info "hello"
  expect-equals "hello\n" printer.stdout
  printer.reset

  ui.emit --info ["hello", "world"]
  expect-equals "[hello, world]\n" printer.stdout
  printer.reset

  ui.emit-list --result ["hello", "world"]
  expect-equals "hello\nworld\n" printer.stdout
  printer.reset

  ui.emit-list --result --title="French" ["bonjour", "monde"]
  expect-equals "French:\n  bonjour\n  monde\n" printer.stdout
  printer.reset

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
  """ printer.stdout
  printer.reset

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
  """ printer.stdout
  printer.reset

  ui.emit-table --result --header={"left": "no", "right": "rows"} []
  expect-equals """
  ┌────┬──────┐
  │ no   rows │
  ├────┼──────┤
  └────┴──────┘
  """ printer.stdout
  printer.reset

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
  """ printer.stdout
  printer.reset

  ui.emit --info {
    "a": "b",
    "c": "d",
  }
  expect-equals "{a: b, c: d}\n" printer.stdout
  printer.reset

  ui.emit-map --result {
    "a": "b",
    "c": "d",
  }
  expect-equals """
  a: b
  c: d
  """ printer.stdout
  printer.reset

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
  """ printer.stdout
  printer.reset

  ui.emit --info "foo"
  expect-equals "foo\n" printer.stdout
  printer.reset

  ui.emit --warning "foo"
  expect-equals "Warning: foo\n" printer.stdout
  printer.reset

  ui.emit --error "foo"
  expect-equals "Error: foo\n" printer.stdout
  printer.reset

  ui.emit-map --result {
    "entry with int": 499,
  }
  expect-equals """
  entry with int: 499
  """ printer.stdout
  printer.reset

test-plain:
    printer := TestPlainPrinter --no-needs-structured
    ui := Ui --printer=printer

    ui.emit --info "hello"
    expect-equals "hello\n" printer.stdout
    printer.reset

    ui.emit --info ["hello", "world"]
    expect-equals "[hello, world]\n" printer.stdout
    printer.reset

    ui.emit-list --result ["hello", "world"]
    expect-equals "hello\nworld\n" printer.stdout
    printer.reset

    ui.emit-list --result --title="French" ["bonjour", "monde"]
    expect-equals "bonjour\nmonde\n" printer.stdout
    printer.reset

    ui.emit-table --result --header={"x": "x", "y": "y"} [
      { "x": "a", "y": "b" },
      { "x": "c", "y": "d" },
    ]
    expect-equals """
    a b
    c d
    """ printer.stdout
    printer.reset

    ui.emit-table --result --header={ "left": "long", "right": "even longer" } [
      { "left": "a",      "right": "short" },
      { "left": "longer", "right": "d" },
    ]
    expect-equals """
    a      short
    longer d
    """ printer.stdout
    printer.reset

    ui.emit-table --result --header={"left": "no", "right": "rows"} []
    expect-equals "" printer.stdout
    printer.reset

    ui.emit-table --result --header={"left": "with", "right": "ints"} [
      { "left": 1, "right": 2, },
      { "left": 3, "right": 4, },
    ]
    expect-equals """
    1 2
    3 4
    """ printer.stdout
    printer.reset

    ui.emit --info {
      "a": "b",
      "c": "d",
    }
    expect-equals "{a: b, c: d}\n" printer.stdout
    printer.reset

    ui.emit-map --result {
      "a": "b",
      "c": "d",
    }
    expect-equals """
    a: b
    c: d
    """ printer.stdout
    printer.reset

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
    """ printer.stdout
    printer.reset

    ui.emit --info "foo"
    expect-equals "foo\n" printer.stdout
    printer.reset

    ui.emit --warning "foo"
    expect-equals "foo\n" printer.stdout
    printer.reset

    ui.emit --error "foo"
    expect-equals "foo\n" printer.stdout
    printer.reset

    ui.emit-map --result {
      "entry with int": 499,
    }
    expect-equals """
    entry with int: 499
    """ printer.stdout
    printer.reset

test-structured:
  printer := TestHumanPrinter --needs-structured
  ui := Ui --printer=printer

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
  ui := Ui --printer=printer

  // Anything that isn't a result is emitted on stderr as if it was
  // a human Ui.
  ui.emit --info "hello"
  expect-equals "hello\n" printer.stderr
  printer.reset

  // Results are emitted on stdout as JSON.
  ui.emit --result "hello"
  expect-equals "\"hello\"" printer.stdout
  printer.reset

  ui.emit-map --result {
    "foo": 1,
    "bar": 2,
  }
  expect-equals "{\"foo\":1,\"bar\":2}" printer.stdout

  ui.emit --warning "some warning"
  expect-equals "Warning: some warning\n" printer.stderr
  printer.reset

  ui.emit --error "some error"
  expect-equals "Error: some error\n" printer.stderr
  printer.reset
