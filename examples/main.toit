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

It can not be used to manage the fleet, for example by adding or removing devices.

Usage:
  examples/main.toit <command>

Commands:
  device  Manage a particular device.
  help    Show help for a command
  status  Shows the status of the fleet

Options:
  -h, --help  Show help for this command

Examples:
  # Do a soft-reset of device 'foo'.
  fleet_manager device --device=foo reset -m soft

  # Show a detailed status of the fleet
  fleet_manager status --verbose
```

The help for the `reset` command looks as follows:
```
Resets the device.

Other useful information here.

Usage:
  examples/main.toit device reset --mode=<hard|soft> [<options>]

Options:
  -f, --force           Force the reset even if the device is active
  -h, --help            Show help for this command
  -m, --mode hard|soft  The reset mode to use (required)

Global options:
  -d, --device string  The device to operate on

Examples:
  # Do a soft-reset of device 'foo'.
  fleet_manager device --device=foo reset -m soft

  # Do a hard-reset
  fleet_manager device reset --mode=hard
```
*/

main arguments:
  // Creates a root command.
  // The name of the root command is not used.
  root_cmd := cli.Command "fleet_manager"
      --long_help="""
        This is an imaginary fleet manager for a fleet of Toit devices.

        It can not be used to manage the fleet, for example by adding or removing devices.
        """

  root_cmd.add create_status_command
  root_cmd.add create_device_command

  root_cmd.run arguments

// ============= Could be in a separate file status.toit. =============

create_status_command -> cli.Command:
  return cli.Command "status"
      --short_help="Shows the status of the fleet"
      --options=[
        cli.Flag "verbose" --short_name="v" --short_help="Show more details." --multi,
        cli.OptionInt "max-lines" --short_help="Maximum number of lines to show." --default=10,
      ]
      --examples=[
        cli.Example "Show the status of the fleet" --arguments="",
        cli.Example "Show a detailed status of the fleet" --arguments="--verbose"
            --global_priority=7,  // Show this example for the root command.
      ]
      --run=:: fleet_status it

fleet_status parsed/cli.Parsed:
  verbose_list := parsed["verbose"]
  trues := (verbose_list.filter: it).size
  falses := verbose_list.size - trues
  verbose_level := trues - falses
  max_lines := parsed["max-lines"]

  print "Max $max_lines of status with verbosity-level $verbose_level."


// ============= Could be in a separate file device.toit. =============

create_device_command -> cli.Command:
  device_cmd := cli.Command "device"
      // Aliases can be used to invoke this command.
      --aliases=[
        "dev",
        "thingy",
      ]
      --long_help="""
        Manage a particular device.

        Use the '--device' option to specify a specific device. Otherwise, the
          last used device is used.
        """
      --options=[
        cli.OptionString "device" --short_name="d"
            --short_help="The device to operate on"
      ]
  device_cmd.add create_reset_command
  return device_cmd

create_reset_command -> cli.Command:
  return cli.Command "reset"
      --long_help="""
        Resets the device.

        Other useful information here.
        """
      --options=[
        cli.OptionEnum "mode" ["hard", "soft"]
            --short_help="The reset mode to use"
            --short_name="m"
            --required,
        cli.Flag "force" --short_name="f"
            --short_help="Force the reset even if the device is active",
      ]
      --examples=[
        cli.Example
            "Do a soft-reset of device 'foo'."
            --arguments="--device=foo -m soft"
            --global_priority=5,  // Include this example for super commands.
        cli.Example
            "Do a hard-reset"
            --arguments="--mode=hard",
      ]
      --run=:: reset_device it

reset_device parsed/cli.Parsed:
  device := parsed["device"]
  mode := parsed["mode"]
  force := parsed["force"]

  print "Resetting device '$device' in $mode-mode."
  if force: print "Using the force if necessary."
