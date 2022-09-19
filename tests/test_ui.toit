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

expect_abort expected/string [block]:
  ui := TestUi
  exception := catch:
    block.call ui
  expect_equals "abort" exception
  all_output := ui.messages.join "\n"
  if not all_output.starts_with "Error: $expected":
    print "Expected: $expected"
    print "Actual: $all_output"
    throw "Expected error message to start with 'Error: $expected'. Actual: $all_output"
