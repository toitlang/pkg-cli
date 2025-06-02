// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import encoding.json
import expect show *

import ..cli
import ..parser_ show test-ui_
import ..ui

/**
A library that can be used to test CLI applications.

A typical pattern for applications is to have two 'main' functions:
- one that takes the command line arguments, and
- one that takes the arguments and a `Cli` object:

```
main arguments/List:
  main arguments --cli=null

main arguments/List --cli/Cli?:
  cmd := Command "app"
    ...
  cmd.run arguments --cli=cli
```

The test can then run the `main` function with a `TestCli` object, which will
  capture the output of the application.

```
import cli.test show *
import expect show *
import my-app

main:
  cli := TestCli
  my-app.main ["arg1", "arg2"] --cli=cli
  expect-equals "..." cli.stdout
```
*/

class TestAbort:

interface TestPrinter extends Printer:
  set-test-ui_ test-ui/TestUi?

class TestHumanPrinter extends HumanPrinter implements TestPrinter:
  test-ui_/TestUi? := null

  print_ str/string:
    if not test-ui_.quiet_: super str
    test-ui_.stdout-messages.add "$str\n"

  set-test-ui_ test-ui/TestUi:
    test-ui_ = test-ui

class TestPlainPrinter extends PlainPrinter implements TestPrinter:
  test-ui_/TestUi? := null
  needs-structured_/bool

  constructor --needs-structured/bool:
    needs-structured_ = needs-structured

  needs-structured --kind/int -> bool:
    return needs-structured_

  print_ str/string:
    if not test-ui_.quiet_: super str
    test-ui_.stdout-messages.add "$str\n"

  emit-structured --kind/int data:
    test-ui_.stdout-messages.add (json.stringify data)

  set-test-ui_ test-ui/TestUi:
    test-ui_ = test-ui

class TestJsonPrinter extends JsonPrinter implements TestPrinter:
  test-ui_/TestUi? := null

  print_ str/string:
    if not test-ui_.quiet_: super str
    test-ui_.stderr-messages.add "$str\n"

  emit-structured --kind/int data:
    test-ui_.stdout-messages.add (json.stringify data)

  set-test-ui_ test-ui/TestUi:
    test-ui_ = test-ui

class TestUi extends Ui:
  stdout-messages/List ::= []
  stderr-messages/List ::= []
  quiet_/bool

  constructor --level/int=Ui.NORMAL-LEVEL --quiet/bool=true --json/bool=false:
    printer := create-printer_ --json=json
    return TestUi --printer=printer --level=level --quiet=quiet

  constructor --level/int=Ui.NORMAL-LEVEL --quiet/bool=true --printer/TestPrinter:
    quiet_ = quiet
    super --printer=printer --level=level
    (printer as TestPrinter).set-test-ui_ this
    test-ui_ = this

  static create-printer_ --json/bool -> TestPrinter:
    if json: return TestJsonPrinter
    return TestHumanPrinter

  stdout -> string:
    return stdout-messages.join ""

  stdout= str/string:
    stdout-messages.clear
    if str != "":
      stdout-messages.add str

  stderr -> string:
    return stderr-messages.join ""

  stderr= str/string:
    stderr-messages.clear
    if str != "":
      stderr-messages.add str

  reset -> none:
    stdout-messages.clear
    stderr-messages.clear

  abort:
    throw TestAbort

class TestCli implements Cli:
  name/string
  ui/TestUi

  constructor --.name/string="test" --quiet/bool=true:
    ui=(TestUi --quiet=quiet)

  cache -> Cache:
    unreachable

  config -> Config:
    unreachable

  with --name=null --cache=null --config=null --ui=null:
    unreachable

expect-abort expected/string [block]:
  ui := TestUi
  cli := Cli "test" --ui=ui
  exception := catch:
    block.call cli
  expect exception is TestAbort
  all-output := ui.stdout + ui.stderr
  if not all-output.starts-with "Error: $expected":
    print "Expected: $expected"
    print "Actual: $all-output"
    throw "Expected error message to start with 'Error: $expected'. Actual: $all-output"
