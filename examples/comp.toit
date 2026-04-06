// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import cli show *

/**
Demonstrates $OptionPath completion with extension filtering.

A tiny imaginary "compiler" that takes an input Toit file and an output
  path. The input rest argument uses $OptionPath with `--extensions=[".toit"]`,
  so shell completion only suggests `.toit` files (and directories for
  navigation).

Since this command has a `--run` callback (and therefore no subcommands),
  the library automatically adds a `--generate-completion` option instead
  of a `completion` subcommand.

To try it out:

```
# Compile:
toit compile -o /tmp/comp examples/comp.toit

# Enable completions (bash):
source <(/tmp/comp --generate-completion bash)

# Invoke:
/tmp/comp -o /tmp/foo in.toit
```

Then type `/tmp/comp -o /tmp/foo ` and press Tab — only `.toit` files
  and directories are suggested.
*/

main arguments:
  cmd := Command "comp"
      --help="An imaginary compiler that compiles a Toit file."
      --options=[
        OptionPath "output" --short-name="o"
            --help="The output path."
            --required,
      ]
      --rest=[
        OptionPath "input"
            --extensions=[".toit"]
            --help="The input Toit file."
            --required,
      ]
      --run=:: run-comp it

  cmd.run arguments

run-comp invocation/Invocation:
  input := invocation["input"]
  output := invocation["output"]
  print "Compiling '$input' to '$output'."
