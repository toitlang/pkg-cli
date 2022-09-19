# CLI

Tools to create command-line applications.

This package makes it easier to create powerful command-line applications in Toit.

It provides:
* Composable subcommands: `myapp subcommand`
* Type options/flags that parse arguments: `myapp --int-flag=49 enum_rest_arg`
* Automatic help generation
* Command aliases

## Concepts
A command is an object that either has subcommands or a `run` callback. It can
define options/flags and rest arguments.

An `Option` is a parameter to the command. It can be a flag (boolean), an option, or
a rest argument. Options are typed and will automatically parse the argument that is
assigned to them.

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/toitlang/pkg-cli/issues
