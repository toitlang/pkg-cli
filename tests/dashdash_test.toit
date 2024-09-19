// Copyright (C) 2024 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli
import expect show *

main:
  root := cli.Command "root"
    --rest=[
      cli.Option "first" --required,
      cli.Option "arg" --multi
    ]
    --run=:: test-dashdash it
  root.run ["--", "prog", "arg1", "arg2", "arg3"]

test-dashdash invocation/cli.Invocation:
  first := invocation["first"]
  rest := invocation["arg"]
  expect-equals "prog" first
  expect-list-equals ["arg1", "arg2", "arg3"] rest
