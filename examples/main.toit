// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import cli

/**
Creates a command-line executable that parses the command-line arguments and
  invokes the callbacks that are registered for the chosen arguments.

The command will have the following help:

```
This is an imaginary fleet manager for a fleet of Toit devices.

It can not be used to manage the fleet, for example
  by adding or removing devices.

Usage:
  examples/main.toit <command>

Commands:
  device  Manage a particular device.
  help    Show help for a command.
  status  Shows the status of the fleet.

Options:
  -h, --help  Show help for this command.

Examples:
  # Do a soft-reset of device 'foo':
  fleet_manager device --device=foo reset -m soft

  # Show a detailed status of the fleet:
  fleet_manager status --verbose

  # Uploads the file 'foo.data' to the device 'foo':
  fleet_manager device --device=foo upload foo.data
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
  -d, --device string  The device to operate on.

Examples:
  # Do a soft-reset of device 'foo':
  fleet_manager device --device=foo reset -m soft

  # Do a hard-reset:
  fleet_manager device reset --mode=hard
```
*/

main arguments:
  // Creates a root command.
  // The name of the root command is not used.
  root-cmd := cli.Command "fleet_manager"
      --long-help="""
        This is an imaginary fleet manager for a fleet of Toit devices.

        It can not be used to manage the fleet, for example
          by adding or removing devices.
        """

  root-cmd.add create-status-command
  root-cmd.add create-device-command

  root-cmd.run arguments

// ============= Could be in a separate file status.toit. =============

create-status-command -> cli.Command:
  return cli.Command "status"
      --short-help="Shows the status of the fleet:"
      --options=[
        cli.Flag "verbose" --short-name="v" --short-help="Show more details." --multi,
        cli.OptionInt "max-lines" --short-help="Maximum number of lines to show." --default=10,
      ]
      --examples=[
        cli.Example "Show the status of the fleet:" --arguments="",
        cli.Example "Show a detailed status of the fleet:" --arguments="--verbose"
            --global-priority=7,  // Show this example for the root command.
      ]
      --run=:: fleet-status it

fleet-status parsed/cli.Parsed:
  verbose-list := parsed["verbose"]
  trues := (verbose-list.filter: it).size
  falses := verbose-list.size - trues
  verbose-level := trues - falses
  max-lines := parsed["max-lines"]

  print "Max $max-lines of status with verbosity-level $verbose-level."


// ============= Could be in a separate file device.toit. =============

create-device-command -> cli.Command:
  device-cmd := cli.Command "device"
      // Aliases can be used to invoke this command.
      --aliases=[
        "dev",
        "thingy",
      ]
      --long-help="""
        Manage a particular device.

        Use the '--device' option to specify a specific device. Otherwise, the
          last used device is used.
        """
      --options=[
        cli.Option "device" --short-name="d"
            --short-help="The device to operate on."
      ]
  device-cmd.add create-reset-command
  device-cmd.add create-upload-command
  return device-cmd

create-upload-command -> cli.Command:
  return cli.Command "upload"
      --long-help="""
        Uploads the given file to the device.

        Other useful information here.
        """
      --rest=[
        cli.OptionString "data"
            --type="file"
            --short-help="The data to upload."
            --required,
      ]
      --examples=[
        cli.Example
            "Uploads the file 'foo.data' to the device 'foo':"
            --arguments="--device=foo foo.data"
            --global-priority=8,  // Include this example for super commands.
      ]
      --run=:: upload-to-device it

upload-to-device parsed/cli.Parsed:
  device := parsed["device"]
  data := parsed["data"]

  print "Uploading file '$data' to device '$device'."

create-reset-command -> cli.Command:
  return cli.Command "reset"
      --long-help="""
        Resets the device.

        Other useful information here.
        """
      --options=[
        cli.OptionEnum "mode" ["hard", "soft"]
            --short-help="The reset mode to use."
            --short-name="m"
            --required,
        cli.Flag "force" --short-name="f"
            --short-help="Force the reset even if the device is active.",
      ]
      --examples=[
        cli.Example
            "Do a soft-reset of device 'foo':"
            --arguments="--device=foo -m soft"
            --global-priority=5,  // Include this example for super commands.
        cli.Example
            "Do a hard-reset:"
            --arguments="--mode=hard",
      ]
      --run=:: reset-device it

reset-device parsed/cli.Parsed:
  device := parsed["device"]
  mode := parsed["mode"]
  force := parsed["force"]

  print "Resetting device '$device' in $mode-mode."
  if force: print "Using the force if necessary."
