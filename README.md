# CLI

Tools to create command-line applications.

This package makes it easier to create powerful command-line applications in Toit.

It provides:
* Composable subcommands: `myapp subcommand`
* Type options/flags that parse arguments: `myapp --int-flag=49 enum_rest_arg`
* Automatic help generation
* Command aliases
* Functionality to cache data between runs
* Functionality to store configurations
* A UI class to support output at different verbosity levels and different output formats

## Command

The `Command` class is the main class of this package. Even programs without sub-commands
contain at least one root-command.

A command declares
- the parameters it takes (options and rest)
- help
- examples
- a lambda to execute if the command is called

For example:

``` toit
import cli

main args/List:
  command := cli.Command "my-app"
    --help="My app does something."
    --options=[
      cli.Option "some-option"
        --help="This is an option."
        --required,
      cli.Flag "some-flag"
        --short-name="f"
        --help="This is a flag.",
    ]
    --rest=[
      cli.Option "rest-arg"
        --help="This is a rest argument."
        --multi,
    ]
    --examples=[
      cli.Example "Do something with the flag:"
          --arguments="--some-option=foo --no-some-flag rest1 rest1",
    ]
    --run=:: | app/cli.Applicationlication parsed/cli.Parsed |
      print parsed["some-option"]
      print parsed["some-flag"]
      print parsed["rest-arg"]  // A list.
      app.ui.result "Computed result"

  command.run args
```

In this example, the command is called "my-app". It takes an option `some-option` and a
flag `some-flag`. It also takes multiple rest arguments `rest-arg`.

The name of the root command is used to compute the location of the cache and config
paths. For example, if the command is called `my-app`, the cache will be stored in
`~/.cache/my-app` and the config will be stored in `~/.config/my-app/config`. See
the cache/config section, for more details.

## Subcommands

Commands can have subcommands. For example, the `git` command has subcommands like
`git commit` and `git push`.

Typically, subcommands are defined if the options/rest arguments of different actions
are different. For example, `git commit` takes a message, but `git push` does not.

Subcommands are defined by adding a `Command` object as child to another command object.
For example:

``` toit
import cli

main args/List:
  command := cli.Command "my-app"
    --help="My app does something."

  sub := cli.Command "subcommand"
    --help="This is a subcommand."
    --run=:: | app/cli.Application parsed/cli.Parsed |
      print "This is a subcommand."
  command.add sub

  command.run args
```

## Options

Options are parameters that are passed to the command. This package comes with
several classes to simplify validation and conversion of common types.

### Typed options

Typed options are options that take a value of a specific type. For example, an
option that takes an integer value.

Here is an incomplete list of the available typed options. See the documentation
of the library for a complete list.

- `cli.OptionInt`: An option that takes an integer value. If the value is not an
  integer, an error is returned.
- `cli.OptionString`: An option that takes a string value. The `cli.Option` constructor
  is an alias for this class.
- `cli.Flag`: An option that takes a boolean value. Flags are treated specially, in
  that they can be negated with a `no-` prefix. For example, if a flag is called
  `some-flag`, it can be negated with `--no-some-flag`.
- `cli.OptionEnum`: An option that takes a value from a set of allowed values.

Users are encouraged to extend the `cli.Option` class and create their own typed options.

## Application

A call to `command.run` parses the given arguments and then executes the
appropriate lambda. The lambda receives two arguments: an `Application` object and a
`Parsed` object.

The `Application` object contains getters for the cache, config, and UI objects.

### Cache

The cache is a simple key-value store that persists between runs. It is typically
stored in `~/.cache/<command-name>`. Environment variables, such as `$XDG_CACHE_HOME`, or
`$APP_CACHE_DIR` (where `APP` is the capitalized name) can be used to change the
location of the cache. See the documentation of the `cache` library for more details.

The cache can either store bytes, or handle paths to cached folders.

#### Bytes

The cache can store bytes. For example:

``` toit
import cli
import cli.cache as cli

store-bytes app/cli.Application:
  cache := app.cache

  data := cache.get "my-key": | store/cli.FileStore |
    // Block that is called when the key is not found.
    // The returned data is stored in the cache.
    print "Data is not cached. Computing it."
    store.save #[0x01, 0x02, 0x03]

  print data  // Prints #[0x01, 0x02, 0x03].
```

The `FileStore` class provides convenience methods to store data. For example, it
allows to store (either copy or move) existing files:

``` toit
import cli
import cli.cache as cli
import host.file

store-from-file app/cli.Application:
  cache := app.cache

  data := cache.get "my-file-key": | store/cli.FileStore |
    // Block that is called when the key is not found.
    print "Data is not cached. Computing it."
    store.with-tmp-directory: | tmp-dir |
      data-path := "$tmp-dir/data.txt"
      // Create a file with some data.
      file.write-content --path=data-path "Hello world"
      store.move data-path

  print data  // Prints the binary representation of "Hello world".
```

#### Paths

When caching multiple files, it's more convenient to just get access to a
directory in the cache structure. The cache class has the
`get-directory-path` method for this use case:

``` toit
import cli
import cli.cache as cli

store-directory app/cli.Application:
  cache := app.cache

  directory := cache.get-directory-path "my-dir-key": | store/cli.DirectoryStore |
    // Block that is called when the key is not found.
    // The returned directory is stored in the cache.
    print "Directory is not cached. Computing it."
    store.with-tmp-directory: | tmp-dir |
      // Create a few files with some data.
      file.write-content --path="$tmp-dir/data1.txt" "Hello world"
      file.write-content --path="$tmp-dir/data2.txt" "Bonjour monde"
      store.move tmp-dir

  print directory  // Prints the path to the directory.
```

### Config

The config is a simple key-value store that persists between runs. It is typically
stored in `~/.config/<command-name>/config`. Environment variables, such as `$XDG_CONFIG_HOME`, or
`$APP_CONFIG_DIR` (where `APP` is the capitalized name) can be used to change the
location of the config. See the documentation of the `config` library for more details.

The `Config` class behaves very similar to a `Map` object. The keys must be
strings, and the values can be any json-serializable object.

When modifying a configuration it is necessary to `write` the changes back to disk.

``` toit
import cli
import cli.config as cli

config-example app/cli.Application:
  config := app.config

  print "old value: $(config.get "my-key")"

  config["my-key"] = "my-value"
  config.write
```

Keys are split at "." to allow for nested values. For example:

``` toit
dotted-example app/cli.Application:
  config := app.config

  print "old value: $(config.get "super-key.sub-key")"

  config["super-key.sub-key"] = "my-value"
  config.write
```

In the config file, `super-key` is implemented as a map that contains a key `sub-key`.

After running the two examples, the config file will contain (edited for readability):

``` json
{
  "my-key": "my-value",
  "super-key": {
    "sub-key": "my-value"
  }
}
```

### UI

The UI class provides a way to output information to the user. It supports different
verbosity levels and different output formats.

Unless the `run` method is called with a `UI` object, the CLI parser will automatically
add the following options to the root command:
```
  --output-format text|json                          Specify the format used when printing to the console. (default: text)
  --verbose                                          Enable verbose output. Shorthand for --verbosity-level=verbose.
  --verbosity-level debug|info|verbose|quiet|silent  Specify the verbosity level. (default: info)
```

A corresponding UI object is then available in the `Application` object. Whenever the
program wants to output something, it should use the `ui` object.

``` toit
import cli

some-chatty-method app/cli.Application:
  ui := app.ui
  ui.debug "This is a debug message."
  ui.verbose "This is a verbose message."
  ui.info "This is an info message."
  ui.warning "This is a warning message."
  ui.error "This is an error message."
  ui.interactive "This is an interactive message."
  ui.result "This is a result message."
```

Depending on the verbosity-level some of these messages will be ignored. If the
verbosity level is:
- `debug`: all messages are printed
- `verbose`: all messages except `debug` are printed
- `info`: all messages except `debug` and `verbose` are printed
- `quiet`: only `interactive`, `error` and `result` messages are printed
- `silent`: only `result` messages are printed

The "result" message is special, in that it is always printed. There should only
be one result message per command (if it makes sense).

The output-format allows the user to change the format of the output. At the moment
'text' and 'json' are supported. The default is 'text'. When the output-format is
'json', then all non-result messages are printed on stderr, and the result message
is printed as a structured object on stdout.

Developers are encouraged to use the `ui.emit --structured` method to emit structured
data. This is especially true for the result message.

``` toit
import cli
import cli.ui as cli

main args:
  cmd := cli.Command "my-app"
    --help="My app does something."
    --run=:: | app/cli.Application parsed/cli.Parsed |
      run-app app parsed

run-app app/cli.Application parsed/cli.Parsed:
  ui := app.ui
  ui.emit
      // Block that is invoked if structured data is needed.
      --structured=: {
        "result": "Computed result"
      }
      --text=: "Computed result as text message."
```

The `Ui` class has furthermore convenience methods to print tables, maps and lists:
- `emit-table`: Prints a table.
- `emit-map`: Prints a map.
- `emit-list`: Prints a list.

Typically, these methods are used for result messages, but they can be used for
other messages as well.

See the documentation of the `ui` library for more details.

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/toitlang/pkg-cli/issues
