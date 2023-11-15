// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli
import expect show *

class TestUi implements cli.Ui:
  messages := []

  print str/string:
    messages.add str

  abort:
    throw "abort"

expect-abort expected/string [block]:
  ui := TestUi
  exception := catch:
    block.call ui
  expect-equals "abort" exception
  all-output := ui.messages.join "\n"
  if not all-output.starts-with "Error: $expected":
    print "Expected: $expected"
    print "Actual: $all-output"
    throw "Expected error message to start with 'Error: $expected'. Actual: $all-output"
