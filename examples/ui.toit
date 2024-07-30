// Copyright (C) 2024 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import cli show *

some-chatty-method cli/Cli:
  ui := cli.ui
  ui.debug "This is a debug message."
  ui.verbose "This is a verbose message."
  ui.info "This is an info message."
  ui.warning "This is a warning message."
  ui.error "This is an error message."
  ui.interactive "This is an interactive message."
  // By convention, 'result' calls should only happen in the method that
  // initially received the Invocation object.
  // For demonstration purposes, we call it here.
  ui.result "This is a result message."

emit-structured cli/Cli:
  ui := cli.ui
  ui.emit-list --kind=Ui.INFO --title="A list" [1, 2, 3]
  ui.emit-map --kind=Ui.INFO --title="A map" {
    "key": "value",
    "key2": "value2",
  }
  ui.emit-table
      --kind=Ui.INFO
      --title="A table"
      --header={"name": "Name", "age": "Age"}
      [
        { "name": "Alice", "age": 25 },
        { "name": "Bob", "age": 30},
      ]

main args:
  // Uses the application name "cli-example" which will be used
  // to compute the path of the config file.
  root-cmd := Command "cli-example"
      --help="""
          An example application demonstrating UI usage.

          Run with --verbosity-level={debug, info, verbose, quiet, silent}, or
            --output-format={text, json} to see different output.
          Note that '--output-format=json' redirects some output to stderr.
          """
      --options=[
        Flag "chatty" --help="Run the chatty method" --default=false,
        Flag "structured" --help="Output structured data" --default=false,
      ]
      --run=:: run it
  root-cmd.run args

run invocation/Invocation:
  if invocation["chatty"]:
    some-chatty-method invocation.cli
    return

  if invocation["structured"]:
    emit-structured invocation.cli
    return

  ui := invocation.cli.ui
  ui.emit --kind=Ui.RESULT
      // Block that is invoked if structured data is needed.
      --structured=: {
        "result": "Computed result"
      }
      // Block that is invoked if text data is needed.
      --text=: "Computed result as text message."
