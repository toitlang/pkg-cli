// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli
import cli.help-generator_ show HelpGenerator
import cli.path_ show Path
import expect show *

import .test-ui

main:
  test-combination
  test-usage
  test-aliases
  test-commands
  test-options
  test-examples
  test-short-help

check-output expected/string [block]:
  ui := TestUi
  cli := cli.Cli "test" --ui=ui
  block.call cli
  all-output := ui.messages.join "\n"
  if expected != all-output and expected.size == all-output.size:
    for i := 0; i < expected.size; i++:
      if expected[i] != all-output[i]:
        print "Mismatch at index $i: '$(string.from-rune expected[i])' != '$(string.from-rune all-output[i])'"
        break
  expect-equals expected all-output

test-combination:
  create-root := : | subcommands/List |
    cli.Command "root"
        --aliases=["r"]  // Should not be visible.
        --help="""
          Root command.
          Two lines.
          """
        --examples= subcommands.is-empty ? [
          cli.Example "Example 1:" --arguments="--option1 foo rest"
        ]: [
          cli.Example "Full example:" --arguments="sub --option1 root"
        ]
        --options=[
          cli.Option "option1" --help="Option 1.",
        ]
        --rest= subcommands.is-empty ? [
          cli.Option "rest1" --help="Rest 1" --type="rest_type" --required,
        ] : []
        --subcommands=subcommands
        --run= subcommands.is-empty? (:: null) : null

  cmd/cli.Command := create-root.call []

  cmd-help := """
    Root command.
    Two lines.

    Usage:
      bin/app [<options>] [--] <rest1:rest_type>

    Options:
      -h, --help            Show help for this command.
          --option1 string  Option 1.

    Rest:
      rest1 rest_type  Rest 1 (required)

    Examples:
      # Example 1:
      app --option1 foo rest
    """
  check-output cmd-help: | cli/cli.Cli |
    cmd.run ["--help"] --cli=cli --invoked-command="bin/app"
  expect-equals cmd-help (cmd.help --invoked-command="bin/app")

  sub := cli.Command "sub"
      --aliases=["sss"]
      --help="Long sub."
      --examples=[
        cli.Example "Sub Example 1:" --arguments="",
        cli.Example "Sub Example 2:"
            --arguments="--option1 foo --option_sub1='xyz'"
            --global-priority=5,
      ]
      --options=[
        cli.Option "option_sub1" --help="Option 1.",
        cli.OptionInt "option_sub2" --help="Option 2." --default=42,
      ]
      --run=:: null

  cmd = create-root.call [sub]

  // Changes to the previous test:
  // - there is now a `help` subcommand
  // - the example with global_priority from the sub is here.
  // The first example also changed, but that's because `create_root`
  //    needs to switch the example.
  cmd-help = """
    Root command.
    Two lines.

    Usage:
      bin/app <command> [<options>]

    Commands:
      help  Show help for a command.
      sub   Long sub.

    Options:
      -h, --help            Show help for this command.
          --option1 string  Option 1.

    Examples:
      # Full example:
      app --option1 root sub

      # Sub Example 2:
      app --option1 foo sub --option_sub1='xyz'
    """
  check-output cmd-help: | cli/cli.Cli |
    cmd.run ["--help"] --cli=cli --invoked-command="bin/app"

  expect-equals cmd-help (cmd.help --invoked-command="bin/app")

  sub-help := """
    Long sub.

    Usage:
      bin/app sub [<options>]

    Aliases:
      sss

    Options:
      -h, --help                Show help for this command.
          --option-sub1 string  Option 1.
          --option-sub2 int     Option 2. (default: 42)

    Global options:
          --option1 string  Option 1.

    Examples:
      # Sub Example 1:
      app sub

      # Sub Example 2:
      app --option1 foo sub --option_sub1='xyz'
    """

  check-output sub-help: | cli/cli.Cli |
    cmd.run ["help", "sub"] --cli=cli --invoked-command="bin/app"

test-usage:
  build-usage := : | commands/List |
    path := Path.private_ commands --invoked-command="bin/app"
    help := HelpGenerator path
    help.build-usage
    help.to-string

  cmd := cli.Command "root"
      --options=[
        cli.Option "option1" --help="Option 1." --required,
        cli.OptionEnum "option2" ["bar", "baz"] --help="Option 2." --required,
        cli.Flag "optional"
      ]
      --rest=[
        cli.Option "rest1" --help="Rest 1." --required,
        cli.Option "rest2" --help="Rest 2.",
        cli.Option "rest3" --help="Rest 3." --multi,
      ]
      --run=:: unreachable

  expected-usage := """
    Usage:
      bin/app --option1=<string> --option2=<bar|baz> [<options>] [--] <rest1> [<rest2>] [<rest3>...]
    """
  actual-usage := build-usage.call [cmd]
  expect-equals expected-usage actual-usage
  expect-equals expected-usage "Usage:\n  $(cmd.usage --invoked-command="bin/app")\n"

  // Test different types.
  cmd = cli.Command "root"
      --options=[
        cli.Option "option7" --help="Option 7." --hidden,
        cli.Option "option6" --help="Option 6.",
        cli.Option "option5" --help="Option 5." --required --type="my_type",
        cli.Flag "option4" --help="Option 4." --required,
        cli.OptionEnum "option3" ["bar", "baz"] --help="Option 3." --required,
        cli.OptionInt "option2" --help="Option 2." --required,
        cli.Option "option1" --help="Option 1." --required,
      ]
      --run=:: unreachable

  // Note that options that are not required are not shown in the usage line.
  // All options are ordered by name.
  // Since there are named options that aren't shown, there is a [<options>].
  expected-usage = """
    Usage:
      bin/app --option1=<string> --option2=<int> --option3=<bar|baz> --option4 --option5=<my_type> [<options>]
    """
  actual-usage = build-usage.call [cmd]
  expect-equals expected-usage actual-usage
  expect-equals expected-usage "Usage:\n  $(cmd.usage --invoked-command="bin/app")\n"

  cmd = cli.Command "root"
      --options=[
        cli.Option "option1" --help="Option 1." --required,
        cli.Option "option2" --help="Option 2." --required,
      ]
      --run=:: unreachable

  // If all options are required, there is no [<options>].
  expected-usage = """
    Usage:
      bin/app --option1=<string> --option2=<string>
    """
  actual-usage = build-usage.call [cmd]
  expect-equals expected-usage actual-usage
  expect-equals expected-usage "Usage:\n  $(cmd.usage --invoked-command="bin/app")\n"

  // Test the same options as rest arguments.
  cmd = cli.Command "root"
      --rest=[
        cli.Option "option9" --help="Option 9." --required,
        cli.OptionInt "option2" --help="Option 2." --required,
        cli.OptionEnum "option3" ["bar", "baz"] --help="Option 3." --required,
        cli.Flag "option4" --help="Option 4." --required,
        cli.Option "option5" --help="Option 5." --required --type="my_type",
        cli.Option "option6" --help="Option 6." --required,
        cli.Option "option7" --help="Option 7.",
      ]
      --run=:: unreachable

  // Rest arguments must not be sorted.
  // Also, optional arguments are shown.
  expected-usage = """
    Usage:
      bin/app [--] <option9> <option2:int> <option3:bar|baz> <option4:true|false> <option5:my_type> <option6> [<option7>]
    """
  actual-usage = build-usage.call [cmd]
  expect-equals expected-usage actual-usage
  expect-equals expected-usage "Usage:\n  $(cmd.usage --invoked-command="bin/app")\n"

  cmd = cli.Command "root"
      --options=[
        cli.Flag "option3" --help="Option 3." --required,
        cli.Option "option2" --help="Option 2.",
        cli.Option "option1" --help="Option 1." --required,
      ]
  sub := cli.Command "sub"
      --options=[
        cli.Flag "sub_option3" --help="Option 3." --required,
        cli.Option "sub_option2" --help="Option 2.",
        cli.Option "sub_option1" --help="Option 1." --required,
      ]
      --run=:: unreachable
  cmd.add sub

  // Test that global options are correctly shown when they are required.
  // All options must still be sorted.
  expected-usage = """
    Usage:
      bin/app --option1=<string> --option3 sub --sub-option1=<string> --sub-option3 [<options>]
    """
  actual-usage = build-usage.call [cmd, sub]
  expect-equals expected-usage actual-usage

  expected-cmd-usage := "sub --sub-option1=<string> --sub-option3 [<options>]"
  expect-equals expected-cmd-usage (sub.usage --invoked-command="sub")

  cmd = cli.Command "root"
      --usage="overridden use line"
      --run=:: unreachable
  expected-usage = """
    Usage:
      overridden use line
    """
  actual-usage = build-usage.call [cmd]
  expect-equals expected-usage actual-usage
  expect-equals expected-usage "Usage:\n  $(cmd.usage --invoked-command="bin/app")\n"

test-aliases:
  build-aliases := : | commands/List |
    path := Path.private_ commands --invoked-command="bin/app"
    help := HelpGenerator path
    help.build-aliases
    help.to-string

  cmd := cli.Command "root"
      --aliases=["alias1", "alias2"]
      --run=:: unreachable
  // The aliases for the root command are not shown.
  expect-equals "" (build-aliases.call [cmd])

  cmd = cli.Command "root"
  sub := cli.Command "sub"
      --aliases=["alias1"]
      --run=:: unreachable
  cmd.add sub

  expected := """
    Aliases:
      alias1
    """
  expect-equals expected (build-aliases.call [cmd, sub])

  cmd = cli.Command "root"
  sub = cli.Command "sub"
      --aliases=["alias1", "alias2"]
      --run=:: unreachable
  cmd.add sub

  expected = """
    Aliases:
      alias1, alias2
    """
  expect-equals expected (build-aliases.call [cmd, sub])

test-commands:
  build-commands := : | commands/List |
    path := Path.private_ commands --invoked-command="bin/app"
    help := HelpGenerator path
    help.build-commands
    help.to-string

  cmd := cli.Command "root"
      --run=:: unreachable
  // If the root command has a run function there is no subcommand section.
  expect-equals "" (build-commands.call [cmd])

  cmd = cli.Command "root"
  sub := cli.Command "sub"
      --run=:: unreachable
  cmd.add sub

  expected := """
    Commands:
      help  Show help for a command.
      sub
    """
  expect-equals expected (build-commands.call [cmd])

  cmd = cli.Command "root"
  sub = cli.Command "sub"
      --help="Subcommand."
      --run=:: unreachable
  cmd.add sub

  expected = """
    Commands:
      help  Show help for a command.
      sub   Subcommand.
    """
  expect-equals expected (build-commands.call [cmd])

  sub2 := cli.Command "sub2"
      --help="Subcommand 2."
      --run=:: unreachable
  cmd.add sub2
  sub3 := cli.Command "asub3"
      --help="Subcommand 3."
      --run=:: unreachable
  cmd.add sub3

  // Commands are sorted.
  expected = """
    Commands:
      asub3  Subcommand 3.
      help   Show help for a command.
      sub    Subcommand.
      sub2   Subcommand 2.
    """
  expect-equals expected (build-commands.call [cmd])

  cmd = cli.Command "root"
  sub = cli.Command "sub"
      --help="""
        First
        paragraph.

        Second
        paragraph.
        """
      --run=:: unreachable
  cmd.add sub

  // If a command has only a long help text, show the first paragraph.
  expected = """
    Commands:
      help  Show help for a command.
      sub   First
            paragraph.
    """
  expect-equals expected (build-commands.call [cmd])

  cmd = cli.Command "root"
  sub = cli.Command "sub"
      --run=:: unreachable
  cmd.add sub
  sub2 = cli.Command "sub2"
      --help="""
      Long
      shorthelp.
      """
      --run=:: unreachable
  cmd.add sub2
  sub3 = cli.Command "sub3"
      --help="Short help3."
      --run=:: unreachable
  cmd.add sub3

  expected = """
    Commands:
      help  Show help for a command.
      sub
      sub2  Long
            shorthelp.
      sub3  Short help3.
    """
  expect-equals expected (build-commands.call [cmd])

  cmd = cli.Command "root"
  sub = cli.Command "help"
      --help="My own help."
      --run=:: unreachable
  cmd.add sub

  // The automatically added help command is not added.
  expected = """
    Commands:
      help  My own help.
    """
  expect-equals expected (build-commands.call [cmd])

  cmd = cli.Command "root"
  sub = cli.Command "sub"
      --aliases=["help"]
      --help="Sub with 'help' alias."
      --run=:: unreachable
  cmd.add sub

  // The automatically added help command is not added.
  expected = """
    Commands:
      sub  Sub with 'help' alias.
    """
  expect-equals expected (build-commands.call [cmd])

test-options:
  build-local-options := : | commands/List |
    path := Path.private_ commands --invoked-command="bin/app"
    help := HelpGenerator path
    help.build-local-options
    help.to-string

  build-global-options := : | commands/List |
    path := Path.private_ commands --invoked-command="bin/app"
    help := HelpGenerator path
    help.build-global-options
    help.to-string

  // Try different options of types: int, string, enum, booleans (flags).
  // Try different flags, like --required, --short_help, --type, --default, multi.
  cmd := cli.Command "root"
      --options=[
        cli.OptionInt "option1" --help="Option 1." --default=42,
        cli.Option "option2" --help="Option 2." --default="foo",
        cli.OptionEnum "option3" ["bar", "baz"] --short-name="x" --help="Option 3." --default="bar",
        cli.Flag "option4" --short-name="4" --help="Option 4." --default=false,
        cli.Flag "option5" --help="Option 5." --default=true,

        cli.OptionInt "option6" --help="Option 6." --required,
        cli.Option "option7" --help="Option 7." --required,
        cli.OptionEnum "option8" ["bar", "baz"] --help="Option 8." --required,
        cli.Flag "option9" --help="Option 9." --required,

        cli.OptionInt "option10" --help="Option 10." --multi,
        cli.Option "option11" --help="Option 11." --multi,
        cli.OptionEnum "option12" ["bar", "baz"] --help="Option 12." --multi,
        cli.Flag "option13" --help="Option 13." --multi,

        cli.OptionInt "option14" --help="Option 14." --multi --required,
        cli.Option "option15" --help="Option 15." --multi --required,
        cli.OptionEnum "option16" ["bar", "baz"] --help="Option 16." --multi --required,
        cli.Flag "option17" --help="Option 17." --multi --required,

        cli.OptionInt "option18" --help="Option 18." --type="my_int_type",
        cli.Option "option19" --help="Option 19." --short-name="y" --type="my_string_type",
        cli.OptionEnum "option20" ["bar", "baz"] --help="Option 20." --type="my_enum_type",

        cli.OptionInt "option21" --help="Option 21\nmulti_line_help.",

        cli.OptionInt "option22" --short-name="zz" --help="Option 22." --default=42,
      ]
  sub := cli.Command "sub" --run=:: unreachable
  cmd.add sub


  // Note that all required arguments are in the usage line.
  expected-options := """
    Options:
      -h,  --help                     Show help for this command.
           --option1 int              Option 1. (default: 42)
           --option10 int             Option 10. (multi)
           --option11 string          Option 11. (multi)
           --option12 bar|baz         Option 12. (multi)
           --option13                 Option 13. (multi)
           --option14 int             Option 14. (multi, required)
           --option15 string          Option 15. (multi, required)
           --option16 bar|baz         Option 16. (multi, required)
           --option17                 Option 17. (multi, required)
           --option18 my_int_type     Option 18.
      -y,  --option19 my_string_type  Option 19.
           --option2 string           Option 2. (default: foo)
           --option20 my_enum_type    Option 20.
           --option21 int             Option 21
                                      multi_line_help.
      -zz, --option22 int             Option 22. (default: 42)
      -x,  --option3 bar|baz          Option 3. (default: bar)
      -4,  --option4                  Option 4.
           --option5                  Option 5. (default: true)
           --option6 int              Option 6. (required)
           --option7 string           Option 7. (required)
           --option8 bar|baz          Option 8. (required)
           --option9                  Option 9. (required)
    """
  actual-options := build-local-options.call [cmd]
  expect-equals expected-options actual-options

  expected-options = ""
  actual-options = build-global-options.call [cmd]
  expect-equals expected-options actual-options

  // Pretty much the same as the local options.
  // Title changes and the `--help` flag is gone.
  expected-options = """
    Global options:
           --option1 int              Option 1. (default: 42)
           --option10 int             Option 10. (multi)
           --option11 string          Option 11. (multi)
           --option12 bar|baz         Option 12. (multi)
           --option13                 Option 13. (multi)
           --option14 int             Option 14. (multi, required)
           --option15 string          Option 15. (multi, required)
           --option16 bar|baz         Option 16. (multi, required)
           --option17                 Option 17. (multi, required)
           --option18 my_int_type     Option 18.
      -y,  --option19 my_string_type  Option 19.
           --option2 string           Option 2. (default: foo)
           --option20 my_enum_type    Option 20.
           --option21 int             Option 21
                                      multi_line_help.
      -zz, --option22 int             Option 22. (default: 42)
      -x,  --option3 bar|baz          Option 3. (default: bar)
      -4,  --option4                  Option 4.
           --option5                  Option 5. (default: true)
           --option6 int              Option 6. (required)
           --option7 string           Option 7. (required)
           --option8 bar|baz          Option 8. (required)
           --option9                  Option 9. (required)
    """
  actual-options = build-global-options.call [cmd, sub]
  expect-equals expected-options actual-options

  // Test global options.
  cmd = cli.Command "root"
      --options=[
        cli.OptionInt "option1" --help="Option 1." --default=42,
      ]

  sub = cli.Command "sub"
      --options=[
        cli.OptionInt "option_sub1" --help="Option 1." --default=42,
      ]
      --run=:: unreachable
  cmd.add sub

  sub-local-expected := """
    Options:
      -h, --help             Show help for this command.
          --option-sub1 int  Option 1. (default: 42)
    """
  sub-global-expected := """
    Global options:
          --option1 int  Option 1. (default: 42)
    """
  sub-local-actual := build-local-options.call [cmd, sub]
  sub-global-actual := build-global-options.call [cmd, sub]
  expect-equals sub-local-expected sub-local-actual
  expect-equals sub-global-expected sub-global-actual

  // When the global options are hidden, they are not shown.
  cmd = cli.Command "root"
      --options=[
        cli.OptionInt "option1" --help="Option 1." --default=42 --hidden,
      ]

  sub = cli.Command "sub"
      --options=[
        cli.OptionInt "option_sub1" --help="Option 1." --default=42,
      ]
      --run=:: unreachable
  cmd.add sub

  sub-global-actual = build-global-options.call [cmd, sub]
  expect-equals "" sub-global-actual

  cmd = cli.Command "root"
      --options=[
        cli.OptionInt "option1" --short-name="h" --help="Option 1." --default=42,
      ]
      --run=:: unreachable
  expected := """
    Options:
          --help         Show help for this command.
      -h, --option1 int  Option 1. (default: 42)
    """
  actual := build-local-options.call [cmd]
  expect-equals expected actual

  cmd = cli.Command "root"
      --options=[
        cli.OptionInt "option1" --help="Option 1." --default=42,
        cli.OptionEnum "help" ["bar", "baz"] --help="Own help."
      ]
      --run=:: unreachable
  // No automatic help. Not even `-h`.
  expected = """
    Options:
          --help bar|baz  Own help.
          --option1 int   Option 1. (default: 42)
    """
  actual = build-local-options.call [cmd]
  expect-equals expected actual

  cmd = cli.Command "root" --run=:: null
  // This adds the ui-help options.
  cmd.run --add-ui-help []
  expected = """
    Global options:
          --output-format human|plain|json                   Specify the format used when printing to the console. (default: human)
          --verbose                                          Enable verbose output. Shorthand for --verbosity-level=verbose.
          --verbosity-level debug|info|verbose|quiet|silent  Specify the verbosity level. (default: info)
    """
  actual = build-global-options.call [cmd, sub]
  expect-equals expected actual

test-examples:
  build-examples := : | commands/List |
    path := Path.private_ commands --invoked-command="bin/app"
    help := HelpGenerator path
    help.build-examples
    help.to-string

  cmd := cli.Command "root"
      --options=[
        cli.OptionInt "option1" --help="Option 1." --default=42,
      ]
      --examples=[
        cli.Example "Example 1:" --arguments="--option1=499",
        cli.Example """
            Example 2
            over multiple lines:
            """
            --arguments="""
              --option1=1
              --option1=2
              """,
      ]
      --run=:: unreachable

  expected := """
    Examples:
      # Example 1:
      app --option1=499

      # Example 2
      # over multiple lines:
      app --option1=1
      app --option1=2
    """
  actual := build-examples.call [cmd]
  expect-equals expected actual

  // Example arguments are moved to the command that defines them.
  cmd = cli.Command "root"
      --options=[
        cli.OptionInt "option1" --short-name="x",
        cli.Flag "aa" --short-name="a",
      ]
  sub := cli.Command "sub"
      --options=[
        cli.OptionInt "option_sub1" --short-name="y",
        cli.Flag "bb" --short-name="b",
      ]
  sub2 := cli.Command "subsub"
      --options=[
        cli.OptionInt "option_subsub1" --short-name="z",
        cli.Flag "cc" --short-name="c",
      ]
      --rest=[
        cli.Option "rest" --multi
      ]
      --examples=[
        cli.Example "Example 1:" --arguments="--option1=499",
        cli.Example "Example 2:" --arguments="--option_sub1=499",
        cli.Example "Example 3:" --arguments="--option_subsub1=499",
        cli.Example "Example 4:"
            --arguments="--option_subsub1=499 --option_sub1=499 --option1=499",
        cli.Example "Example 5:"
            --arguments="--option_subsub1 499 --option_sub1 499 --option1 499",
        cli.Example "Example 6 with rest:"
            --arguments="--option_subsub1 499 --option_sub1 499 --option1 499 rest1 rest2",
        cli.Example "Clusters go to the first that accepts all:"
            --arguments="""
              -ab -c
              -c -b -a
              -ca -b
              -bc -a
              """,
        cli.Example "short_names can also have additional params:"
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
      # Example 1:
      app --option1=499 sub subsub

      # Example 2:
      app sub --option_sub1=499 subsub

      # Example 3:
      app sub subsub --option_subsub1=499

      # Example 4:
      app --option1=499 sub --option_sub1=499 subsub --option_subsub1=499

      # Example 5:
      app --option1 499 sub --option_sub1 499 subsub --option_subsub1 499

      # Example 6 with rest:
      app --option1 499 sub --option_sub1 499 subsub --option_subsub1 499 rest1 rest2

      # Clusters go to the first that accepts all:
      app sub -ab subsub -c
      app -a sub -b subsub -c
      app sub -b subsub -ca
      app -a sub subsub -bc

      # short_names can also have additional params:
      app sub -ay 33 subsub -c
      app sub -b subsub -cx 42
      app -a sub subsub -bz 55
    """
  actual = build-examples.call [cmd, sub, sub2]
  expect-equals expected actual

  // Verify that examples of subcommands are used if they have a global_priority.
  // Also check that they are sorted by priority.

  cmd = cli.Command "root"
      --examples=[
        cli.Example "Root example 1:" --arguments="sub",
        cli.Example "Root example 2:" --arguments="sub2",
      ]
  sub = cli.Command "sub"
      --examples=[
        cli.Example "Example 1:" --arguments="global3" --global-priority=3,
        cli.Example "Example 2:" --arguments="no_global",
        cli.Example "Example 3:" --arguments="global1" --global-priority=1,
      ]
      --rest=[
        cli.Option "rest"
      ]
      --run=:: unreachable
  cmd.add sub
  sub2 = cli.Command "sub2"
      --examples=[
        cli.Example "Example 4:" --arguments="no_global",
        cli.Example "Example 5:" --arguments="global5" --global-priority=5,
        cli.Example "Example 6:" --arguments="global1" --global-priority=1,
      ]
      --rest=[
        cli.Option "rest"
      ]
      --run=:: unreachable
  cmd.add sub2

  expected = """
    Examples:
      # Root example 1:
      app sub

      # Root example 2:
      app sub2

      # Example 5:
      app sub2 global5

      # Example 1:
      app sub global3

      # Example 3:
      app sub global1

      # Example 6:
      app sub2 global1
    """
  actual = build-examples.call [cmd]
  expect-equals expected actual

test-short-help:
  cmd := cli.Command "root"
      --help="Test command."
      --run=:: unreachable

  expected := "Test command."
  actual := cmd.short-help
  expect-equals expected actual

  cmd = cli.Command "root"
      --help="""
        Test command.
        """
      --run=:: unreachable

  expected = "Test command."
  actual = cmd.short-help
  expect-equals expected actual

  cmd = cli.Command "root"
      --help="""
        Test command.
        Second line.
        """
      --run=:: unreachable

  expected = "Test command.\nSecond line."
  actual = cmd.short-help
  expect-equals expected actual

  cmd = cli.Command "root"
      --help="""
        Test command.

        Second paragraph.
        """
      --run=:: unreachable

  expected = "Test command."
  actual = cmd.short-help
  expect-equals expected actual
