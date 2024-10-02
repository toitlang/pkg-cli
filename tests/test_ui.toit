// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli as cli
import cli.ui as cli
import cli.parser_ as cli-parser
import expect show *

class TestUi extends cli.Ui:
  messages := []

  constructor --level/int=cli.Ui.NORMAL-LEVEL:
    printer := TestPrinter
    super --level=level --printer=printer
    printer.ui_ = this
    cli-parser.test-ui_ = this

  abort:
    throw "abort"

class TestPrinter extends cli.HumanPrinterBase:
  ui_/TestUi? := null

  constructor:

  needs-structured --kind/int -> bool: return false

  print_ str/string:
    ui_.messages.add str

  emit-structured --kind/int structured/any:
    unreachable

expect-abort expected/string [block]:
  ui := TestUi
  cli := cli.Cli "test" --ui=ui
  exception := catch:
    block.call cli
  expect-equals "abort" exception
  all-output := ui.messages.join "\n"
  if not all-output.starts-with "Error: $expected":
    print "Expected: $expected"
    print "Actual: $all-output"
    throw "Expected error message to start with 'Error: $expected'. Actual: $all-output"
