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
    --run=:: | _ parsed| test-dashdash parsed
  root.run ["--", "prog", "arg1", "arg2", "arg3"]

test-dashdash parsed/cli.Parsed:
  first := parsed["first"]
  rest := parsed["arg"]
  expect-equals "prog" first
  expect-list-equals ["arg1", "arg2", "arg3"] rest
