import .src.arg_parser as arguments

main args:
  command := arguments.Command "root"
      --short_help="One-line help"
      --aliases=["alias1", "alias2"]
      --long_help="""
        Some help for this command.
        """
      --options=[
        arguments.Flag "xhelp" --short_name="x" --short_help="xx" --required,
        arguments.OptionEnum "format" ["long", "short"]
          --short_name="f"
          --short_help="Output format"
          --default="long",
        arguments.Option "global" --short_help="global required flag" --required,
      ]
      --examples=[
        arguments.Example "Example of subcommand"
            --arguments="-x --format=long --global \"xxx\" other --other_int2=45 in out"
      ]

  other := arguments.Command "other"
      --aliases=["foo", "bar"]
      --run=:: | parsed | run_other parsed
      --long_help="""
        Some long help for the other command.

        Multiple lines.
        """
      --options=[
        arguments.Option "other" --short_help="other option",
        arguments.OptionInt "other_int" --short_help="other int option\ntwo lines" --default=42,
        arguments.OptionInt "other_int2" --required --multi,
      ]
      --rest=[
        arguments.Option "input" --short_help="Input file" --required --type="file",
        arguments.Option "output" --short_help="Output file" --multi --required --type="file",
      ]
      --examples=[
        arguments.Example "Use a long output format"
            --arguments="-x --format=long --global \"xxx\" --other_int2=44 in out"
            --global_priority=3,
      ]

  other2 := arguments.Command "other2"
      --run=:: | parsed | run_other parsed
      --short_help="""Some short help for the other2 command.\nTwo lines."""
      --rest=[
        arguments.Option "input" --short_help="Input file" --required --type="file",
        arguments.Option "output" --short_help="Output file" --multi --required --type="file",
        arguments.Flag "flag_rest"
      ]
      --examples=[
        arguments.Example "other2 example" --arguments="-x --format=long --global \"xxx\" input output output2" --global_priority=5,
        arguments.Example "other2 example2" --arguments="--no-xhelp --global xxx x y",
      ]

  command.add other
  command.add other2
  command.run args

run_help parsed/arguments.Parsed:
  print "in_help"
  print parsed

run_other parsed/arguments.Parsed:
  print "in_other"
  print parsed
