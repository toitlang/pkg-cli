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

interface TestPrinter:
  set-test-ui_ test-ui/TestUi?

class TestHumanPrinter extends HumanPrinter implements TestPrinter:
  test-ui_/TestUi? := null

  print_ str/string:
    if not test-ui_.quiet_: super str
    test-ui_.stdout += "$str\n"

  set-test-ui_ test-ui/TestUi:
    test-ui_ = test-ui

class TestJsonPrinter extends JsonPrinter implements TestPrinter:
  test-ui_/TestUi? := null

  print_ str/string:
    if not test-ui_.quiet_: super str
    test-ui_.stderr += "$str\n"

  emit-structured --kind/int data:
    test-ui_.stdout += json.stringify data

  set-test-ui_ test-ui/TestUi:
    test-ui_ = test-ui

class TestUi extends Ui:
  stdout/string := ""
  stderr/string := ""
  quiet_/bool
  json_/bool

  constructor --level/int=Ui.NORMAL-LEVEL --quiet/bool=true --json/bool=false:
    quiet_ = quiet
    json_ = json
    printer := create-printer_ --json=json
    super --printer=printer --level=level
    (printer as TestPrinter).set-test-ui_ this
    test-ui_ = this

  static create-printer_ --json/bool -> Printer:
    if json: return TestJsonPrinter
    return TestHumanPrinter

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
