// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import expect show *
import cli.config as cfg
import cli.utils_ show with-tmp-directory

main:
  with-tmp-directory: | tmp-dir |
    config-file := "$tmp-dir/config"
    config := cfg.Config --app-name="test" --path=config-file --data={:}

    // All `get` commands return 'null' if the value doesn't exist yet.
    expect-null (config.get "foo")
    expect-null (config.get "foo.bar")
    expect-null (config.get "foo.bar.baz")

    // Initial a non existing value with the `--init` function.
    // Note that the key is split on dots, and intermediate maps
    // are created.
    initial := config.get "foo.bar.baz" --init=: "qux"
    expect-equals "qux" initial
    expect (config.get "foo") is Map
    expect (config.get "foo.bar") is Map
    expect-equals "qux" (config.get "foo.bar.baz")

    // Overwrite the value with an operator.
    config["foo.bar.baz"] = "quux"
    expect-equals "quux" (config.get "foo.bar.baz")

    // Create a new value with the operator.
    config["foo.bar.gee"] = 499
    expect-equals 499 (config.get "foo.bar.gee")

    config["foo.bar.gee"] = 500

    config.write

    // Read the config back in.
    config2 := cfg.Config --app-name="test" --path=config-file --init=: unreachable

    expect-structural-equals config.data config2.data
