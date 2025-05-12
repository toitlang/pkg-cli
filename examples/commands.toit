// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import cli show *

/**
Creates a command-line executable that parses the command-line arguments and
  invokes the callbacks that are registered for the chosen arguments.

The command will have the following help:

```
This is an imaginary fleet manager for a fleet of Toit devices.

It can not be used to manage the fleet, for example
  by adding or removing devices.

Usage:
  examples/main.toit <command> [<options>]

Commands:
  device  Manage a particular device.
  help    Show help for a command.
  status  Shows the status of the fleet.

Options:
  -h, --help                                             Show help for this command.
      --output-format text|json                          Specify the format used when printing to the console. (default: text)
      --verbose                                          Enable verbose output. Shorthand for --verbosity-level=verbose.
      --verbosity-level debug|info|verbose|quiet|silent  Specify the verbosity level. (default: info)

Examples:
  # Uploads the file 'foo.data' to the device 'foo':
  main.toit device --device=foo upload foo.data

  # Show a detailed status of the fleet:
  main.toit --verbose status

  # Do a soft-reset of device 'foo':
  main.toit device --device=foo reset -m soft
```

The help for the `reset` command looks as follows:
```
Resets the device.

Other useful information here.

Usage:
  examples/main.toit device reset --mode=<hard|soft> [<options>]

Options:
  -f, --force           Force the reset even if the device is active.
  -h, --help            Show help for this command.
  -m, --mode hard|soft  The reset mode to use. (required)

Global options:
  -d, --device string                                    The device to operate on.
      --output-format text|json                          Specify the format used when printing to the console. (default: text)
      --verbose                                          Enable verbose output. Shorthand for --verbosity-level=verbose.
      --verbosity-level debug|info|verbose|quiet|silent  Specify the verbosity level. (default: info)

Examples:
  # Do a soft-reset of device 'foo':
  main.toit device --device=foo reset -m soft

  # Do a hard-reset:
  main.toit device reset --mode=hard
```
*/

main arguments:
  // Creates a root command.
  // The name of the root command is not used.
  root-cmd := Command "fleet_manager"
      --help="""
        This is an imaginary fleet manager for a fleet of Toit devices.

        It can not be used to manage the fleet, for example
          by adding or removing devices.
        """

  root-cmd.add create-status-command
  root-cmd.add create-device-command

  root-cmd.run arguments

// ============= Could be in a separate file status.toit. =============

create-status-command -> Command:
  return Command "status"
      --help="Shows the status of the fleet."
      --options=[
        OptionInt "max-lines" --help="Maximum number of lines to show." --default=10,
      ]
      --examples=[
        Example "Show the status of the fleet:" --arguments="",
        Example "Show a detailed status of the fleet:" --arguments="--verbose"
            --global-priority=7,  // Show this example for the root command.
      ]
      --run=:: fleet-status it

fleet-status invocation/Invocation:
  max-lines := invocation["max-lines"]
  cli := invocation.cli
  verbose := cli.ui.level >= Ui.VERBOSE-LEVEL

  cli.ui.emit --kind=Ui.RESULT
      --structured=: {
          "some": "json",
          "info": "about the status",
        }
      --text=:
        "Printing max $max-lines of status. (verbose: $(verbose ? "yes" : "no"))"


// ============= Could be in a separate file device.toit. =============

create-device-command -> Command:
  device-cmd := Command "device"
      // Aliases can be used to invoke this command.
      --aliases=[
        "dev",
        "thingy",
      ]
      --help="""
        Manage a particular device.

        Use the '--device' option to specify a specific device. Otherwise, the
          last used device is used.
        """
      --options=[
        Option "device" --short-name="d"
            --help="The device to operate on."
      ]
  device-cmd.add create-upload-command
  device-cmd.add create-reset-command
  return device-cmd

create-upload-command -> Command:
  return Command "upload"
      --help="""
        Uploads the given file to the device.

        Other useful information here.
        """
      --rest=[
        OptionString "data"
            --type="file"
            --help="The data to upload."
            --required,
      ]
      --examples=[
        Example
            "Uploads the file 'foo.data' to the device 'foo':"
            --arguments="--device=foo foo.data"
            --global-priority=8,  // Include this example for super commands.
      ]
      --run=:: upload-to-device it

create-reset-command -> Command:
  return Command "reset"
      --help="""
        Resets the device.

        Other useful information here.
        """
      --options=[
        OptionEnum "mode" ["hard", "soft"]
            --help="The reset mode to use."
            --short-name="m"
            --required,
        Flag "force" --short-name="f"
            --help="Force the reset even if the device is active.",
      ]
      --examples=[
        Example
            "Do a soft-reset of device 'foo':"
            --arguments="--device=foo -m soft"
            --global-priority=5,  // Include this example for super commands.
        Example
            "Do a hard-reset:"
            --arguments="--mode=hard",
      ]
      --run=:: reset-device it

with-device invocation/Invocation [block]:
  cli := invocation.cli

  device := invocation["device"]
  if not device:
    device = cli.config.get "default-device"

  if not device:
    cli.ui.abort "No device specified and no default device set."

  block.call device

upload-to-device invocation/Invocation:
  data := invocation["data"]

  with-device invocation: | device |
    print "Uploading file '$data' to device '$device'."

reset-device invocation/Invocation:
  cli := invocation.cli

  mode := invocation["mode"]
  force := invocation["force"]

  with-device invocation: | device |
    cli.ui.emit --info "Resetting device '$device' in $(mode)-mode."
    if force: cli.ui.emit --debug "Using the force if necessary."
