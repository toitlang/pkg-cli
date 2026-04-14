// Copyright (C) 2024 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli
import expect show *

main:
  test-dashdash-separator
  test-no-allow-dashdash
  test-no-allow-dashdash-with-options

test-dashdash-separator:
  root := cli.Command "root"
      --rest=[
        cli.Option "first" --required,
        cli.Option "arg" --multi,
      ]
      --run=:: | invocation/cli.Invocation |
        expect-equals "prog" invocation["first"]
        expect-list-equals ["arg1", "arg2", "arg3"] invocation["arg"]
  root.run ["--", "prog", "arg1", "arg2", "arg3"]

test-no-allow-dashdash:
  // When --allow-dash-dash is false, "--" becomes a regular rest argument.
  root := cli.Command "root"
      --dash-dash-is-rest
      --rest=[
        cli.Option "arg" --multi,
      ]
      --run=:: | invocation/cli.Invocation |
        expect-list-equals ["--", "foo", "bar"] invocation["arg"]
  root.run ["--", "foo", "bar"]

test-no-allow-dashdash-with-options:
  // Options after "--" are still parsed when allow-dash-dash is false.
  root := cli.Command "root"
      --dash-dash-is-rest
      --options=[
        cli.Flag "verbose" --short-name="v",
      ]
      --rest=[
        cli.Option "arg" --multi,
      ]
      --run=:: | invocation/cli.Invocation |
        expect invocation["verbose"]
        expect-list-equals ["--", "foo"] invocation["arg"]
  root.run ["--", "foo", "--verbose"]
