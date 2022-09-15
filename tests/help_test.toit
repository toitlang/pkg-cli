// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli
import cli.help_generator_ show HelpGenerator
import expect show *

import .test_ui

main:
  test_combination
  test_usage
  test_aliases
  test_commands
  test_options
  test_examples

check_output expected/string [block]:
  ui := TestUi
  block.call ui
  all_output := ui.messages.join "\n"
  if expected != all_output and expected.size == all_output.size:
    for i := 0; i < expected.size; i++:
      if expected[i] != all_output[i]:
        print "Mismatch at index $i: '$(string.from_rune expected[i])' != '$(string.from_rune all_output[i])'"
        break
  expect_equals expected all_output

test_combination:
  create_root := : | subcommands/List |
    cli.Command "root"
        --aliases=["r"]  // Should not be visible.
        --long_help="""
          Root command.
          Two lines.
          """
        --short_help="Root command."  // Should not be visible.
        --examples= subcommands.is_empty ? [
          cli.Example "Example 1" --arguments="--option1 foo rest"
        ]: [
          cli.Example "Full example" --arguments="sub --option1 root"
        ]
        --options=[
          cli.OptionString "option1" --short_help="Option 1",
        ]
        --rest= subcommands.is_empty ? [
          cli.OptionString "rest1" --short_help="Rest 1" --type="rest_type" --required,
        ] : []
        --subcommands=subcommands
        --run= subcommands.is_empty? (:: null) : null

  cmd/cli.Command := create_root.call []

  cmd_help := """
    Root command.
    Two lines.

    Usage:
      root [<options>] [--] <rest1:rest_type>

    Options:
      -h, --help            Show help for this command
          --option1 string  Option 1

    Examples:
      # Example 1
      root --option1 foo rest
    """
  check_output cmd_help: | ui/cli.Ui |
    cmd.run ["--help"] --ui=ui --invoked_command="root"

  sub := cli.Command "sub"
      --aliases=["sss"]
      --long_help="Long sub"
      --short_help="Short sub"
      --examples=[
        cli.Example "Sub Example 1" --arguments="",
        cli.Example "Sub Example 2"
            --arguments="--option1 foo --option_sub1='xyz'"
            --global_priority=5,
      ]
      --options=[
        cli.OptionString "option_sub1" --short_help="Option 1",
        cli.OptionInt "option_sub2" --short_help="Option 2" --default=42,
      ]
      --run=:: null

  cmd = create_root.call [sub]

  // Changes to the previous test:
  // - there is now a `help` subcommand
  // - the example with global_priority from the sub is here.
  // The first example also changed, but that's because `create_root`
  //    needs to switch the example.
  cmd_help = """
    Root command.
    Two lines.

    Usage:
      root <command> [<options>]

    Commands:
      help  Show help for a command
      sub   Short sub

    Options:
      -h, --help            Show help for this command
          --option1 string  Option 1

    Examples:
      # Full example
      root --option1 root sub

      # Sub Example 2
      root --option1 foo sub --option_sub1='xyz'
    """
  check_output cmd_help: | ui/cli.Ui |
    cmd.run ["--help"] --ui=ui --invoked_command="root"

  sub_help := """
    Long sub

    Usage:
      root sub [<options>]

    Aliases:
      sss

    Options:
      -h, --help                Show help for this command
          --option_sub1 string  Option 1
          --option_sub2 int     Option 2 (default: 42)

    Global options:
          --option1 string  Option 1

    Examples:
      # Sub Example 1
      root sub

      # Sub Example 2
      root --option1 foo sub --option_sub1='xyz'
    """

  check_output sub_help: | ui/cli.Ui |
    cmd.run ["help", "sub"] --ui=ui --invoked_command="root"

test_usage:
  build_usage := : | path/List |
    help := HelpGenerator path --invoked_command="root"
    help.build_usage
    help.to_string

  cmd := cli.Command "root"
      --options=[
        cli.OptionString "option1" --short_help="Option 1" --required,
        cli.OptionEnum "option2" ["bar", "baz"] --short_help="Option 2" --required,
        cli.Flag "optional"
      ]
      --rest=[
        cli.OptionString "rest1" --short_help="Rest 1" --required,
        cli.OptionString "rest2" --short_help="Rest 2",
        cli.OptionString "rest3" --short_help="Rest 3" --multi,
      ]
      --run=:: unreachable

  expected_usage := """
    Usage:
      root --option1=<string> --option2=<bar|baz> [<options>] [--] <rest1> [<rest2>] [<rest3>...]
    """
  actual_usage := build_usage.call [cmd]
  expect_equals expected_usage actual_usage

  // Test different types.
  cmd = cli.Command "root"
      --options=[
        cli.OptionString "option7" --short_help="Option 7" --hidden,
        cli.OptionString "option6" --short_help="Option 6",
        cli.OptionString "option5" --short_help="Option 5" --required --type="my_type",
        cli.Flag "option4" --short_help="Option 4" --required,
        cli.OptionEnum "option3" ["bar", "baz"] --short_help="Option 3" --required,
        cli.OptionInt "option2" --short_help="Option 2" --required,
        cli.OptionString "option1" --short_help="Option 1" --required,
      ]
      --run=:: unreachable

  // Note that options that are not required are not shown in the usage line.
  // All options are ordered by name.
  // Since there are named options that aren't shown, there is a [<options>].
  expected_usage = """
    Usage:
      root --option1=<string> --option2=<int> --option3=<bar|baz> --option4 --option5=<my_type> [<options>]
    """
  actual_usage = build_usage.call [cmd]
  expect_equals expected_usage actual_usage

  cmd = cli.Command "root"
      --options=[
        cli.OptionString "option1" --short_help="Option 1" --required,
        cli.OptionString "option2" --short_help="Option 2" --required,
      ]
      --run=:: unreachable

  // If all options are required, there is no [<options>].
  expected_usage = """
    Usage:
      root --option1=<string> --option2=<string>
    """
  actual_usage = build_usage.call [cmd]
  expect_equals expected_usage actual_usage

  // Test the same options as rest arguments.
  cmd = cli.Command "root"
      --rest=[
        cli.OptionString "option9" --short_help="Option 9" --required,
        cli.OptionInt "option2" --short_help="Option 2" --required,
        cli.OptionEnum "option3" ["bar", "baz"] --short_help="Option 3" --required,
        cli.Flag "option4" --short_help="Option 4" --required,
        cli.OptionString "option5" --short_help="Option 5" --required --type="my_type",
        cli.OptionString "option6" --short_help="Option 6" --required,
        cli.OptionString "option7" --short_help="Option 7",
      ]
      --run=:: unreachable

  // Rest arguments must not be sorted.
  // Also, optional arguments are shown.
  expected_usage = """
    Usage:
      root [--] <option9> <option2:int> <option3:bar|baz> <option4:true|false> <option5:my_type> <option6> [<option7>]
    """
  actual_usage = build_usage.call [cmd]
  expect_equals expected_usage actual_usage

  cmd = cli.Command "root"
      --options=[
        cli.Flag "option3" --short_help="Option 3" --required,
        cli.OptionString "option2" --short_help="Option 2",
        cli.OptionString "option1" --short_help="Option 1" --required,
      ]
  sub := cli.Command "sub"
      --options=[
        cli.Flag "sub_option3" --short_help="Option 3" --required,
        cli.OptionString "sub_option2" --short_help="Option 2",
        cli.OptionString "sub_option1" --short_help="Option 1" --required,
      ]
      --run=:: unreachable
  cmd.add sub

  // Test that global options are correctly shown when they are required.
  // All options must still be sorted.
  expected_usage = """
    Usage:
      root --option1=<string> --option3 sub --sub_option1=<string> --sub_option3 [<options>]
    """
  actual_usage = build_usage.call [cmd, sub]
  expect_equals expected_usage actual_usage

  cmd = cli.Command "root"
      --use="overridden use line"
      --run=:: unreachable
  expected_usage = """
    Usage:
      overridden use line
    """
  actual_usage = build_usage.call [cmd]
  expect_equals expected_usage actual_usage

test_aliases:
  build_aliases := : | path/List |
    help := HelpGenerator path --invoked_command="root"
    help.build_aliases
    help.to_string

  cmd := cli.Command "root"
      --aliases=["alias1", "alias2"]
      --run=:: unreachable
  // The aliases for the root command are not shown.
  expect_equals "" (build_aliases.call [cmd])

  cmd = cli.Command "root"
  sub := cli.Command "sub"
      --aliases=["alias1"]
      --run=:: unreachable
  cmd.add sub

  expected := """
    Aliases:
      alias1
    """
  expect_equals expected (build_aliases.call [cmd, sub])

  cmd = cli.Command "root"
  sub = cli.Command "sub"
      --aliases=["alias1", "alias2"]
      --run=:: unreachable
  cmd.add sub

  expected = """
    Aliases:
      alias1, alias2
    """
  expect_equals expected (build_aliases.call [cmd, sub])

test_commands:
  build_commands := : | path/List |
    help := HelpGenerator path --invoked_command="root"
    help.build_commands
    help.to_string

  cmd := cli.Command "root"
      --run=:: unreachable
  // If the root command has a run function there is no subcommand section.
  expect_equals "" (build_commands.call [cmd])

  cmd = cli.Command "root"
  sub := cli.Command "sub"
      --run=:: unreachable
  cmd.add sub

  expected := """
    Commands:
      help  Show help for a command
      sub
    """
  expect_equals expected (build_commands.call [cmd])

  cmd = cli.Command "root"
  sub = cli.Command "sub"
      --short_help="Subcommand"
      --run=:: unreachable
  cmd.add sub

  expected = """
    Commands:
      help  Show help for a command
      sub   Subcommand
    """
  expect_equals expected (build_commands.call [cmd])

  sub2 := cli.Command "sub2"
      --short_help="Subcommand 2"
      --run=:: unreachable
  cmd.add sub2
  sub3 := cli.Command "asub3"
      --short_help="Subcommand 3"
      --run=:: unreachable
  cmd.add sub3

  // Commands are sorted.
  expected = """
    Commands:
      asub3  Subcommand 3
      help   Show help for a command
      sub    Subcommand
      sub2   Subcommand 2
    """
  expect_equals expected (build_commands.call [cmd])

  cmd = cli.Command "root"
  sub = cli.Command "sub"
      --long_help="""
        First
        paragraph

        Second
        paragraph
        """
      --run=:: unreachable
  cmd.add sub

  // If a command has only a long help text, show the first paragraph.
  expected = """
    Commands:
      help  Show help for a command
      sub   First
            paragraph
    """
  expect_equals expected (build_commands.call [cmd])

  cmd = cli.Command "root"
  sub = cli.Command "sub"
      --run=:: unreachable
  cmd.add sub
  sub2 = cli.Command "sub2"
      --long_help="unused"
      --short_help="""
      Long
      shorthelp
      """
      --run=:: unreachable
  cmd.add sub2
  sub3 = cli.Command "sub3"
      --long_help="unused"
      --short_help="Short help3"
      --run=:: unreachable
  cmd.add sub3

  expected = """
    Commands:
      help  Show help for a command
      sub
      sub2  Long
            shorthelp
      sub3  Short help3
    """
  expect_equals expected (build_commands.call [cmd])

  cmd = cli.Command "root"
  sub = cli.Command "help"
      --short_help="My own help"
      --run=:: unreachable
  cmd.add sub

  // The automatically added help command is not added.
  expected = """
    Commands:
      help  My own help
    """
  expect_equals expected (build_commands.call [cmd])

  cmd = cli.Command "root"
  sub = cli.Command "sub"
      --aliases=["help"]
      --short_help="Sub with 'help' alias"
      --run=:: unreachable
  cmd.add sub

  // The automatically added help command is not added.
  expected = """
    Commands:
      sub  Sub with 'help' alias
    """
  expect_equals expected (build_commands.call [cmd])

test_options:
  build_local_options := : | path/List |
    help := HelpGenerator path --invoked_command="root"
    help.build_local_options
    help.to_string

  build_global_options := : | path/List |
    help := HelpGenerator path --invoked_command="root"
    help.build_global_options
    help.to_string

  // Try different options of types: int, string, enum, booleans (flags).
  // Try different flags, like --required, --short_help, --type, --default, multi.
  cmd := cli.Command "root"
      --options=[
        cli.OptionInt "option1" --short_help="Option 1" --default=42,
        cli.OptionString "option2" --short_help="Option 2" --default="foo",
        cli.OptionEnum "option3" ["bar", "baz"] --short_name="x" --short_help="Option 3" --default="bar",
        cli.Flag "option4" --short_name="4" --short_help="Option 4" --default=false,
        cli.Flag "option5" --short_help="Option 5" --default=true,

        cli.OptionInt "option6" --short_help="Option 6" --required,
        cli.OptionString "option7" --short_help="Option 7" --required,
        cli.OptionEnum "option8" ["bar", "baz"] --short_help="Option 8" --required,
        cli.Flag "option9" --short_help="Option 9" --required,

        cli.OptionInt "option10" --short_help="Option 10" --multi,
        cli.OptionString "option11" --short_help="Option 11" --multi,
        cli.OptionEnum "option12" ["bar", "baz"] --short_help="Option 12" --multi,
        cli.Flag "option13" --short_help="Option 13" --multi,

        cli.OptionInt "option14" --short_help="Option 14" --multi --required,
        cli.OptionString "option15" --short_help="Option 15" --multi --required,
        cli.OptionEnum "option16" ["bar", "baz"] --short_help="Option 16" --multi --required,
        cli.Flag "option17" --short_help="Option 17" --multi --required,

        cli.OptionInt "option18" --short_help="Option 18" --type="my_int_type",
        cli.OptionString "option19" --short_help="Option 19" --short_name="y" --type="my_string_type",
        cli.OptionEnum "option20" ["bar", "baz"] --short_help="Option 20" --type="my_enum_type",

        cli.OptionInt "option21" --short_help="Option 21\nmulti_line_help",
      ]
  sub := cli.Command "sub" --run=:: unreachable
  cmd.add sub


  // Note that all required arguments are in the usage line.
  expected_options := """
    Options:
      -h, --help                     Show help for this command
          --option1 int              Option 1 (default: 42)
          --option10 int             Option 10 (multi)
          --option11 string          Option 11 (multi)
          --option12 bar|baz         Option 12 (multi)
          --option13                 Option 13 (multi)
          --option14 int             Option 14 (multi, required)
          --option15 string          Option 15 (multi, required)
          --option16 bar|baz         Option 16 (multi, required)
          --option17                 Option 17 (multi, required)
          --option18 my_int_type     Option 18
      -y, --option19 my_string_type  Option 19
          --option2 string           Option 2 (default: foo)
          --option20 my_enum_type    Option 20
          --option21 int             Option 21
                                     multi_line_help
      -x, --option3 bar|baz          Option 3 (default: bar)
      -4, --option4                  Option 4
          --option5                  Option 5 (default: true)
          --option6 int              Option 6 (required)
          --option7 string           Option 7 (required)
          --option8 bar|baz          Option 8 (required)
          --option9                  Option 9 (required)
    """
  actual_options := build_local_options.call [cmd]
  expect_equals expected_options actual_options

  expected_options = ""
  actual_options = build_global_options.call [cmd]
  expect_equals expected_options actual_options

  // Pretty much the same as the local options.
  // Title changes and the `--help` flag is gone.
  expected_options = """
    Global options:
          --option1 int              Option 1 (default: 42)
          --option10 int             Option 10 (multi)
          --option11 string          Option 11 (multi)
          --option12 bar|baz         Option 12 (multi)
          --option13                 Option 13 (multi)
          --option14 int             Option 14 (multi, required)
          --option15 string          Option 15 (multi, required)
          --option16 bar|baz         Option 16 (multi, required)
          --option17                 Option 17 (multi, required)
          --option18 my_int_type     Option 18
      -y, --option19 my_string_type  Option 19
          --option2 string           Option 2 (default: foo)
          --option20 my_enum_type    Option 20
          --option21 int             Option 21
                                     multi_line_help
      -x, --option3 bar|baz          Option 3 (default: bar)
      -4, --option4                  Option 4
          --option5                  Option 5 (default: true)
          --option6 int              Option 6 (required)
          --option7 string           Option 7 (required)
          --option8 bar|baz          Option 8 (required)
          --option9                  Option 9 (required)
    """
  actual_options = build_global_options.call [cmd, sub]
  expect_equals expected_options actual_options

  // Test global options.
  cmd = cli.Command "root"
      --options=[
        cli.OptionInt "option1" --short_help="Option 1" --default=42,
      ]

  sub = cli.Command "sub"
      --options=[
        cli.OptionInt "option_sub1" --short_help="Option 1" --default=42,
      ]
      --run=:: unreachable
  cmd.add sub

  sub_local_expected := """
    Options:
      -h, --help             Show help for this command
          --option_sub1 int  Option 1 (default: 42)
    """
  sub_global_expected := """
    Global options:
          --option1 int  Option 1 (default: 42)
    """
  sub_local_actual := build_local_options.call [cmd, sub]
  sub_global_actual := build_global_options.call [cmd, sub]
  expect_equals sub_local_expected sub_local_actual
  expect_equals sub_global_expected sub_global_actual

  cmd = cli.Command "root"
      --options=[
        cli.OptionInt "option1" --short_name="h" --short_help="Option 1" --default=42,
      ]
      --run=:: unreachable
  expected := """
    Options:
          --help         Show help for this command
      -h, --option1 int  Option 1 (default: 42)
    """
  actual := build_local_options.call [cmd]
  expect_equals expected actual

  cmd = cli.Command "root"
      --options=[
        cli.OptionInt "option1" --short_help="Option 1" --default=42,
        cli.OptionEnum "help" ["bar", "baz"] --short_help="Own help"
      ]
      --run=:: unreachable
  // No automatic help. Not even `-h`.
  expected = """
    Options:
          --help bar|baz  Own help
          --option1 int   Option 1 (default: 42)
    """
  actual = build_local_options.call [cmd]
  expect_equals expected actual

test_examples:
  build_examples := : | path/List |
    help := HelpGenerator path --invoked_command="root"
    help.build_examples
    help.to_string

  cmd := cli.Command "root"
      --options=[
        cli.OptionInt "option1" --short_help="Option 1" --default=42,
      ]
      --examples=[
        cli.Example "Example 1" --arguments="--option1=499",
        cli.Example """
            Example 2
            over multiple lines
            """
            --arguments="""
              --option1=1
              --option1=2
              """,
      ]
      --run=:: unreachable

  expected := """
    Examples:
      # Example 1
      root --option1=499

      # Example 2
      # over multiple lines
      root --option1=1
      root --option1=2
    """
  actual := build_examples.call [cmd]
  expect_equals expected actual

  // Example arguments are moved to the command that defines them.
  cmd = cli.Command "root"
      --options=[
        cli.OptionInt "option1" --short_name="x",
        cli.Flag "aa" --short_name="a",
      ]
  sub := cli.Command "sub"
      --options=[
        cli.OptionInt "option_sub1" --short_name="y",
        cli.Flag "bb" --short_name="b",
      ]
  sub2 := cli.Command "subsub"
      --options=[
        cli.OptionInt "option_subsub1" --short_name="z",
        cli.Flag "cc" --short_name="c",
      ]
      --rest=[
        cli.OptionString "rest" --multi
      ]
      --examples=[
        cli.Example "Example 1" --arguments="--option1=499",
        cli.Example "Example 2" --arguments="--option_sub1=499",
        cli.Example "Example 3" --arguments="--option_subsub1=499",
        cli.Example "Example 4"
            --arguments="--option_subsub1=499 --option_sub1=499 --option1=499",
        cli.Example "Example 5"
            --arguments="--option_subsub1 499 --option_sub1 499 --option1 499",
        cli.Example "Example 6 with rest"
            --arguments="--option_subsub1 499 --option_sub1 499 --option1 499 rest1 rest2",
        cli.Example "Clusters go to the first that accepts all"
            --arguments="""
              -ab -c
              -c -b -a
              -ca -b
              -bc -a
              """,
        cli.Example "short_names can also have additional params"
            --arguments="""
              -ay 33 -c
              -cx 42 -b
              -bz 55 -a
              """,

      ]
      --run=:: unreachable
  sub.add sub2
  cmd.add sub

  expected = """
    Examples:
      # Example 1
      root --option1=499 sub subsub

      # Example 2
      root sub --option_sub1=499 subsub

      # Example 3
      root sub subsub --option_subsub1=499

      # Example 4
      root --option1=499 sub --option_sub1=499 subsub --option_subsub1=499

      # Example 5
      root --option1 499 sub --option_sub1 499 subsub --option_subsub1 499

      # Example 6 with rest
      root --option1 499 sub --option_sub1 499 subsub --option_subsub1 499 rest1 rest2

      # Clusters go to the first that accepts all
      root sub -ab subsub -c
      root -a sub -b subsub -c
      root sub -b subsub -ca
      root -a sub subsub -bc

      # short_names can also have additional params
      root sub -ay 33 subsub -c
      root sub -b subsub -cx 42
      root -a sub subsub -bz 55
    """
  actual = build_examples.call [cmd, sub, sub2]
  expect_equals expected actual

  // Verify that examples of subcommands are used if they have a global_priority.
  // Also check that they are sorted by priority.

  cmd = cli.Command "root"
      --examples=[
        cli.Example "Root example 1" --arguments="sub",
        cli.Example "Root example 2" --arguments="sub2",
      ]
  sub = cli.Command "sub"
      --examples=[
        cli.Example "Example 1" --arguments="global3" --global_priority=3,
        cli.Example "Example 2" --arguments="no_global",
        cli.Example "Example 3" --arguments="global1" --global_priority=1,
      ]
      --rest=[
        cli.OptionString "rest"
      ]
      --run=:: unreachable
  cmd.add sub
  sub2 = cli.Command "sub2"
      --examples=[
        cli.Example "Example 4" --arguments="no_global",
        cli.Example "Example 5" --arguments="global5" --global_priority=5,
        cli.Example "Example 6" --arguments="global1" --global_priority=1,
      ]
      --rest=[
        cli.OptionString "rest"
      ]
      --run=:: unreachable
  cmd.add sub2

  expected = """
    Examples:
      # Root example 1
      root sub

      # Root example 2
      root sub2

      # Example 3
      root sub global1

      # Example 6
      root sub2 global1

      # Example 1
      root sub global3

      # Example 5
      root sub2 global5
    """
  actual = build_examples.call [cmd]
  expect_equals expected actual
