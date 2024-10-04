// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import encoding.json

create-ui-from-args_ args/List:
  verbose-level/string? := null
  output-format/string? := null

  // We don't keep track of whether an argument was already provided.
  // The last one wins.
  // The real parsing later will catch any errors.
  // The output might still be affected since we use the created Ui class
  // for the output of parsing.
  // Also we might parse the flags in the wrong way here. For example,
  //   `--output "--verbosity-level"` would be parsed differently if we knew
  // that `--output` is an option that takes an argument. We completely ignore
  // this here.
  for i := 0; i < args.size; i++:
    arg := args[i]
    if arg == "--": break
    if arg == "--verbose":
      verbose-level = "verbose"
    else if arg == "--verbosity-level" or arg == "--verbose_level":
      if i + 1 >= args.size:
        // We will get an error during the real parsing of the args.
        break
      verbose-level = args[++i]
    else if arg.starts-with "--verbosity-level=" or arg.starts-with "--verbose_level=":
      verbose-level = arg["--verbosity-level=".size..]
    else if arg == "--output-format" or arg == "--output_format":
      if i + 1 >= args.size:
        // We will get an error during the real parsing of the args.
        break
      output-format = args[++i]
    else if arg.starts-with "--output-format=" or arg.starts-with "--output_format=":
      output-format = arg["--output-format=".size..]

  if verbose-level == null: verbose-level = "info"
  if output-format == null: output-format = "human"

  level/int := ?
  if verbose-level == "debug": level = Ui.DEBUG-LEVEL
  else if verbose-level == "info": level = Ui.NORMAL-LEVEL
  else if verbose-level == "verbose": level = Ui.VERBOSE-LEVEL
  else if verbose-level == "quiet": level = Ui.QUIET-LEVEL
  else if verbose-level == "silent": level = Ui.SILENT-LEVEL
  else: level = Ui.NORMAL-LEVEL

  if output-format == "json":
    return Ui.json --level=level
  else if output-format == "plain":
    return Ui.plain --level=level
  else if output-format == "human":
    return Ui.human --level=level
  else:
    throw "Invalid output format: $output-format"

interface Printer:
  /** Emits the given $msg of the given message-$kind. */
  emit --kind/int msg/string
  /**
  Emits the given $list of the given message-$kind.

  This method is only called if the printer does not request a structured
    representation.
  */
  emit-list --kind/int list/List --title/string?
  /**
  Emits the given $table of the given message-$kind.

  This method is only called if the printer does not request a structured
    representation.
  */
  emit-table --kind/int table/List --title/string? --header/Map?
  /**
  Emits the given $map of the given message-$kind.

  This method is only called if the printer does not request a structured
    representation.
  */
  emit-map --kind/int map/Map --title/string?

  /** Whether the printer wants a structured representation for the given $kind. */
  needs-structured --kind/int -> bool

  /** Emits the given $json-object of the given message-$kind. */
  emit-structured --kind/int json-object/any

  /** Whether the printer wants a human representation for the given $kind. */
  wants-human --kind/int -> bool

/**
A printer that prints human-readable output.
*/
abstract class HumanPrinterBase implements Printer:

  abstract emit-structured --kind/int object/any
  abstract print_ str/string

  needs-structured --kind/int -> bool:
    return false

  wants-human --kind/int -> bool:
    return true

  emit --kind/int msg/string:
    prefix := ""
    if kind == Ui.ERROR:
      prefix = "Error: "
    else if kind == Ui.WARNING:
      prefix = "Warning: "
    print_ "$prefix$msg"

  print-prefix_ --kind/int --title/string? -> string:
    prefix := ""
    if kind == Ui.ERROR:
      prefix = "Error:"
    else if kind == Ui.WARNING:
      prefix = "Warning:"

    if title:
      if prefix != "": prefix = "$prefix $title:"
      else: prefix = "$title:"

    if prefix != "":
      print_ prefix
      return "  "

    return ""

  emit-list --kind/int list/List --title/string?:
    indentation := print-prefix_ --kind=kind --title=title
    emit-list_ list --indentation=indentation

  emit-list_ list/List --indentation/string:
    list.do:
      // TODO(florian): should the entries be recursively pretty-printed?
      print_ "$indentation$it"

  emit-map --kind/int map/Map --title/string?:
    indentation := print-prefix_ --kind=kind --title=title
    emit-map_ map --indentation=indentation

  emit-map_ map/Map --indentation/string:
    map.do: | key value |
      if value is Map:
        print_ "$indentation$key:"
        emit-map_ value --indentation="$indentation  "
      else if value is List:
        print_ "$indentation$key:"
        emit-list_ value --indentation="$indentation  "
      else:
        // TODO(florian): should the entries handle lists as well.
        print_ "$indentation$key: $value"

  emit-table --kind/int table/List --title/string?=null --header/Map:
    // Ignore the recommended indentation.
    print-prefix_ --kind=kind --title=title

    column-count := header.size
    column-sizes := header.map: | _ header-string/string | header-string.size --runes

    table.do: | row/Map |
      header.do --keys: | key/string |
        entry/string := "$row[key]"
        column-sizes.update key: | old/int | max old (entry.size --runes)

    pad := : | object/Map |
      padded-row := []
      column-sizes.do: | key size |
        entry := "$object[key]"
        // TODO(florian): allow alignment.
        padded := entry + " " * (size - (entry.size --runes))
        padded-row.add padded
      padded-row

    bars := column-sizes.values.map: "─" * it
    print_ "┌─$(bars.join "─┬─")─┐"

    sized-header-entries := []
    padded-row := pad.call header
    print_ "│ $(padded-row.join "   ") │"
    print_ "├─$(bars.join "─┼─")─┤"

    table.do: | row |
      padded-row = pad.call row
      print_ "│ $(padded-row.join "   ") │"
    print_ "└─$(bars.join "─┴─")─┘"

/**
A printer that prints output in simple text format.

Typically, this printer is used in shell scripts or other non-interactive
  environments, where JSON output is not desired.
*/
abstract class PlainPrinterBase implements Printer:

  abstract emit-structured --kind/int object/any
  abstract print_ str/string

  needs-structured --kind/int -> bool:
    return false

  wants-human --kind/int -> bool:
    return false

  emit --kind/int msg/string:
    print_ msg

  emit-list --kind/int list/List --title/string?:
    emit-list_ list

  emit-list_ list/List:
    list.do:
      // TODO(florian): should the entries be recursively pretty-printed?
      print_ "$it"

  emit-map --kind/int map/Map --title/string?:
    emit-map_ map --prefix=""

  emit-map_ map/Map --prefix/string:
    map.do: | key value |
      if value is Map:
        emit-map_ value --prefix="$prefix$key."
      else if value is List:
        print_ "$prefix$key: $(value.join ", ")"
      else:
        // TODO(florian): should the entries handle lists as well.
        print_ "$prefix$key: $value"

  emit-table --kind/int table/List --title/string?=null --header/Map:
    column-count := header.size
    column-sizes := header.map: 0

    table.do: | row/Map |
      header.do --keys: | key/string |
        entry/string := "$row[key]"
        column-sizes.update key: | old/int | max old (entry.size --runes)

    table.do: | row |
      out := ""
      spacing := ""
      column-sizes.do: | key size |
        entry := "$row[key]"
        out += "$spacing$entry"
        spacing = " " * (1 + size - (entry.size --runes))
      print_ out

/**
A class for handling input/output from the user.

The Ui class is used to display text to the user and to get input from the user.
*/
class Ui:
  static DEBUG ::= 0
  static VERBOSE ::= 1
  static INFO ::= 2
  static WARNING ::= 3
  static INTERACTIVE ::= 4
  static ERROR ::= 5
  static RESULT ::= 6

  static DEBUG-LEVEL ::= -1
  static VERBOSE-LEVEL ::= -2
  static NORMAL-LEVEL ::= -3
  static QUIET-LEVEL ::= -4
  static SILENT-LEVEL ::= -5

  level/int
  printer_/Printer

  constructor --.level=NORMAL-LEVEL --printer/Printer:
    printer_ = printer
    if not DEBUG-LEVEL >= level >= SILENT-LEVEL:
      throw "Invalid level: $level"

  constructor.human --level/int=NORMAL-LEVEL:
    return Ui --level=level --printer=HumanPrinter

  constructor.plain --level/int=NORMAL-LEVEL:
    return Ui --level=level --printer=PlainPrinter

  constructor.json --level/int=NORMAL-LEVEL:
    return Ui --level=level --printer=JsonPrinter

  constructor.from-args args/List:
    return create-ui-from-args_ args

  /**
  Emits the given $object using the $INFO kind.

  If the printer requests a structured object, the $object is provided as is.
    As such, the object must be a valid JSON object.
  Otherwise, the $object is converted to a string.
  */
  // TODO(florian): change the bool type to 'True'.
  emit --info/bool object/any -> none:
    if not info: throw "INVALID_ARGUMENT"
    emit --kind=INFO --structured=: object

  /** Variant of $emit using the $DEBUG kind. */
  // TODO(florian): change the bool type to 'True'.
  emit --debug/bool object/any -> none:
    if not debug: throw "INVALID_ARGUMENT"
    emit --kind=DEBUG --structured=: object

  /** Variant of $(emit --debug object) that only calls the given $generator when needed. */
  emit --debug/bool [generator] -> none:
    if not debug: throw "INVALID_ARGUMENT"
    emit --kind=DEBUG --structured=generator

  /** Variant of $emit using the $VERBOSE kind. */
  // TODO(florian): change the bool type to 'True'.
  emit --verbose/bool object/any -> none:
    if not verbose: throw "INVALID_ARGUMENT"
    emit --kind=VERBOSE --structured=: object

  /** Variant of $(emit --verbose object) that only calls the given $generator when needed. */
  // TODO(florian): change the bool type to 'True'.
  emit --verbose/bool [generator] -> none:
    if not verbose: throw "INVALID_ARGUMENT"
    emit --kind=VERBOSE --structured=generator

  /** Variant of $emit using the $WARNING kind. */
  // TODO(florian): change the bool type to 'True'.
  emit --warning/bool object/any -> none:
    if not warning: throw "INVALID_ARGUMENT"
    emit --kind=WARNING --structured=: object

  /** Variant of $emit using the $INTERACTIVE kind. */
  // TODO(florian): change the bool type to 'True'.
  emit --interactive/bool object/any -> none:
    if not interactive: throw "INVALID_ARGUMENT"
    emit --kind=INTERACTIVE --structured=: object

  /** Variant of $emit using the $ERROR kind. */
  // TODO(florian): change the bool type to 'True'.
  emit --error/bool object/any -> none:
    if not error: throw "INVALID_ARGUMENT"
    emit --kind=ERROR --structured=: object

  /**
  Variant of $emit using the $RESULT kind.

  A program should do only a single result output per run.
  */
  // TODO(florian): change the bool type to 'True'.
  emit --result/bool object/any -> none:
    if not result: throw "INVALID_ARGUMENT"
    emit --kind=RESULT --structured=: object

  /**
  Aborts the program with the given error message.
  First emits $object at an error-level as as tring, then calls $abort.
  */
  abort object/any -> none:
    emit --error object
    abort

  do_ --kind/int [generator] -> none:
    if level == DEBUG-LEVEL:
      // Always triggers.
    else if level == VERBOSE-LEVEL:
      if kind < VERBOSE: return
    else if level == NORMAL-LEVEL:
      if kind < INFO: return
    else if level == QUIET-LEVEL:
      if kind < INTERACTIVE: return
    else if level == SILENT-LEVEL:
      if kind < RESULT: return
    else:
      throw "Invalid level: $level"
    generator.call

  /**
  Emits a table.

  A table is a list of maps. Each map represents a row in the table. The keys
    of the map are the column names. The values are the entries in the table.

  The $title may be used to create a title string. Printers are *not* required
    to display the title.

  The $header map may used to create a header row. The keys of the map are the
    key entries into the $table. The values are used in the header row. Printers
    are *not* required to use the $header.
  */
  emit-table --kind/int table/List --title/string?=null --header/Map?=null -> none:
    do_ --kind=kind:
      if printer_.needs-structured --kind=kind:
        printer_.emit-structured --kind=kind table
      else:
        printer_.emit-table --kind=kind --title=title --header=header table

  /** Variant of $(emit-table --kind table) using the $DEBUG kind. */
  // TODO(florian): change the bool type to 'True'.
  emit-table --debug/bool table/List --title/string?=null --header/Map?=null -> none:
    if not debug: throw "INVALID_ARGUMENT"
    emit-table --kind=DEBUG table --title=title --header=header

  /** Variant of $(emit-table --kind table) using the $VERBOSE kind. */
  // TODO(florian): change the bool type to 'True'.
  emit-table --verbose/bool table/List --title/string?=null --header/Map?=null -> none:
    if not verbose: throw "INVALID_ARGUMENT"
    emit-table --kind=VERBOSE table --title=title --header=header

  /** Variant of $(emit-table --kind table) using the $INFO kind. */
  // TODO(florian): change the bool type to 'True'.
  emit-table --info/bool table/List --title/string?=null --header/Map?=null -> none:
    if not info: throw "INVALID_ARGUMENT"
    emit-table --kind=INFO table --title=title --header=header

  /** Variant of $(emit-table --kind table) using the $WARNING kind. */
  // TODO(florian): change the bool type to 'True'.
  emit-table --warning/bool table/List --title/string?=null --header/Map?=null -> none:
    if not warning: throw "INVALID_ARGUMENT"
    emit-table --kind=WARNING table --title=title --header=header

  /** Variant of $(emit-table --kind table) using the $INTERACTIVE kind. */
  // TODO(florian): change the bool type to 'True'.
  emit-table --interactive/bool table/List --title/string?=null --header/Map?=null -> none:
    if not interactive: throw "INVALID_ARGUMENT"
    emit-table --kind=INTERACTIVE table --title=title --header=header

  /** Variant of $(emit-table --kind table) using the $ERROR kind. */
  // TODO(florian): change the bool type to 'True'.
  emit-table --error/bool table/List --title/string?=null --header/Map?=null -> none:
    if not error: throw "INVALID_ARGUMENT"
    emit-table --kind=ERROR table --title=title --header=header

  /**
  Variant of $(emit-table --kind table) using the $RESULT kind.

  A program should do only a single result output per run.
  */
  // TODO(florian): change the bool type to 'True'.
  emit-table --result/bool table/List --title/string?=null --header/Map?=null -> none:
    if not result: throw "INVALID_ARGUMENT"
    emit-table --kind=RESULT table --title=title --header=header

  /**
  Emits a list.

  Printers are *not* required to display the title.
  */
  emit-list --kind/int list/List --title/string?=null -> none:
    do_ --kind=kind:
      if printer_.needs-structured --kind=kind:
        printer_.emit-structured --kind=kind list
      else:
        printer_.emit-list --kind=kind --title=title list

  /** Variant of $(emit-list --kind list) using the $DEBUG kind. */
  // TODO(florian): change the bool type to 'True'.
  emit-list --debug/bool list/List --title/string?=null -> none:
    if not debug: throw "INVALID_ARGUMENT"
    emit-list --kind=DEBUG list --title=title

  /** Variant of $(emit-list --kind list) using the $VERBOSE kind. */
  // TODO(florian): change the bool type to 'True'.
  emit-list --verbose/bool list/List --title/string?=null -> none:
    if not verbose: throw "INVALID_ARGUMENT"
    emit-list --kind=VERBOSE list --title=title

  /** Variant of $(emit-list --kind list) using the $INFO kind. */
  // TODO(florian): change the bool type to 'True'.
  emit-list --info/bool list/List --title/string?=null -> none:
    if not info: throw "INVALID_ARGUMENT"
    emit-list --kind=INFO list --title=title

  /** Variant of $(emit-list --kind list) using the $WARNING kind. */
  // TODO(florian): change the bool type to 'True'.
  emit-list --warning/bool list/List --title/string?=null -> none:
    if not warning: throw "INVALID_ARGUMENT"
    emit-list --kind=WARNING list --title=title

  /** Variant of $(emit-list --kind list) using the $INTERACTIVE kind. */
  // TODO(florian): change the bool type to 'True'.
  emit-list --interactive/bool list/List --title/string?=null -> none:
    if not interactive: throw "INVALID_ARGUMENT"
    emit-list --kind=INTERACTIVE list --title=title

  /** Variant of $(emit-list --kind list) using the $ERROR kind. */
  // TODO(florian): change the bool type to 'True'.
  emit-list --error/bool list/List --title/string?=null -> none:
    if not error: throw "INVALID_ARGUMENT"
    emit-list --kind=ERROR list --title=title

  /**
  Variant of $(emit-list --kind list) using the $RESULT kind.

  A program should do only a single result output per run.
  */
  // TODO(florian): change the bool type to 'True'.
  emit-list --result/bool list/List --title/string?=null -> none:
    if not result: throw "INVALID_ARGUMENT"
    emit-list --kind=RESULT list --title=title

  /**
  Emits a map.

  Printers are *not* required to display the title.
  */
  emit-map --kind/int map/Map --title/string?=null -> none:
    do_ --kind=kind:
      if printer_.needs-structured --kind=kind:
        printer_.emit-structured --kind=kind map
      else:
        printer_.emit-map --kind=kind --title=title map

  /** Variant of $(emit-map --kind map) using the $DEBUG kind. */
  // TODO(florian): change the bool type to 'True'.
  emit-map --debug/bool map/Map --title/string?=null -> none:
    if not debug: throw "INVALID_ARGUMENT"
    emit-map --kind=DEBUG map --title=title

  /** Variant of $(emit-map --kind map) using the $VERBOSE kind. */
  // TODO(florian): change the bool type to 'True'.
  emit-map --verbose/bool map/Map --title/string?=null -> none:
    if not verbose: throw "INVALID_ARGUMENT"
    emit-map --kind=VERBOSE map --title=title

  /** Variant of $(emit-map --kind map) using the $INFO kind. */
  // TODO(florian): change the bool type to 'True'.
  emit-map --info/bool map/Map --title/string?=null -> none:
    if not info: throw "INVALID_ARGUMENT"
    emit-map --kind=INFO map --title=title

  /** Variant of $(emit-map --kind map) using the $WARNING kind. */
  // TODO(florian): change the bool type to 'True'.
  emit-map --warning/bool map/Map --title/string?=null -> none:
    if not warning: throw "INVALID_ARGUMENT"
    emit-map --kind=WARNING map --title=title

  /** Variant of $(emit-map --kind map) using the $INTERACTIVE kind. */
  // TODO(florian): change the bool type to 'True'.
  emit-map --interactive/bool map/Map --title/string?=null -> none:
    if not interactive: throw "INVALID_ARGUMENT"
    emit-map --kind=INTERACTIVE map --title=title

  /** Variant of $(emit-map --kind map) using the $ERROR kind. */
  // TODO(florian): change the bool type to 'True'.
  emit-map --error/bool map/Map --title/string?=null -> none:
    if not error: throw "INVALID_ARGUMENT"
    emit-map --kind=ERROR map --title=title

  /**
  Variant of $(emit-map --kind map) using the $RESULT kind.

  A program should do only a single result output per run.
  */
  // TODO(florian): change the bool type to 'True'.
  emit-map --result/bool map/Map --title/string?=null -> none:
    if not result: throw "INVALID_ARGUMENT"
    emit-map --kind=RESULT map --title=title

  /**
  Emits the value created by calling $structured or $text.

  If the UI's printer requests a structured representation calls the $structured block and
    passes the result to the printer.

  If the printer does not request a structured representation calls the $text block and
    passes the result as string to the printer. The $text block may return
    null to indicate that no output should be generated.
  */
  emit --kind/int [--structured] [--text]:
    do_ --kind=kind:
      if printer_.needs-structured --kind=kind:
        printer_.emit-structured --kind=kind structured.call
      else:
        message := text.call
        if message:
          printer_.emit --kind=kind "$text.call"

  /** Variant of $(emit --kind [--structured] [--text]) using the $DEBUG kind. */
  emit --debug/bool [--structured] [--text]:
    emit --kind=DEBUG --structured=structured --text=text

  /** Variant of $(emit --kind [--structured] [--text]) using the $VERBOSE kind. */
  // TODO(florian): change the bool type to 'True'.
  emit --verbose/bool [--structured] [--text] -> none:
    if not verbose: throw "INVALID_ARGUMENT"
    emit --kind=VERBOSE --structured=structured --text=text

  /** Variant of $(emit --kind [--structured] [--text]) using the $INFO kind. */
  // TODO(florian): change the bool type to 'True'.
  emit --info/bool [--structured] [--text] -> none:
    if not info: throw "INVALID_ARGUMENT"
    emit --kind=INFO --structured=structured --text=text

  /** Variant of $(emit --kind [--structured] [--text]) using the $WARNING kind. */
  // TODO(florian): change the bool type to 'True'.
  emit --warning/bool [--structured] [--text] -> none:
    if not warning: throw "INVALID_ARGUMENT"
    emit --kind=WARNING --structured=structured --text=text

  /** Variant of $(emit --kind [--structured] [--text]) using the $INTERACTIVE kind. */
  // TODO(florian): change the bool type to 'True'.
  emit --interactive/bool [--structured] [--text] -> none:
    if not interactive: throw "INVALID_ARGUMENT"
    emit --kind=INTERACTIVE --structured=structured --text=text

  /** Variant of $(emit --kind [--structured] [--text]) using the $ERROR kind. */
  // TODO(florian): change the bool type to 'True'.
  emit --error/bool [--structured] [--text] -> none:
    if not error: throw "INVALID_ARGUMENT"
    emit --kind=ERROR --structured=structured --text=text

  /**
  Variant of $(emit --kind [--structured] [--text]) using the $RESULT kind.

  A program should do only a single result output per run.
  */
  // TODO(florian): change the bool type to 'True'.
  emit --result/bool [--structured] [--text] -> none:
    if not result: throw "INVALID_ARGUMENT"
    emit --kind=RESULT --structured=structured --text=text

  /**
  Variant of $(emit --kind [--structured] [--text]).

  If the printer needs a non-structred representation, simply converts the
    result of the $structured block to a string.
  */
  emit --kind/int [--structured]:
    do_ --kind=kind:
      if printer_.needs-structured --kind=kind:
        printer_.emit-structured --kind=kind structured.call
      else:
        printer_.emit --kind=kind "$(structured.call)"

  /** Variant of $(emit --kind [--structured]) using the $DEBUG kind. */
  // TODO: change the bool type to 'True'.
  emit --debug/bool [--structured] -> none:
    if not debug: throw "INVALID_ARGUMENT"
    emit --kind=DEBUG --structured=structured

  /** Variant of $(emit --kind [--structured]) using the $VERBOSE kind. */
  // TODO: change the bool type to 'True'.
  emit --verbose/bool [--structured] -> none:
    if not verbose: throw "INVALID_ARGUMENT"
    emit --kind=VERBOSE --structured=structured

  /** Variant of $(emit --kind [--structured]) using the $INFO kind. */
  // TODO: change the bool type to 'True'.
  emit --info/bool [--structured] -> none:
    if not info: throw "INVALID_ARGUMENT"
    emit --kind=INFO --structured=structured

  /** Variant of $(emit --kind [--structured]) using the $WARNING kind. */
  // TODO: change the bool type to 'True'.
  emit --warning/bool [--structured] -> none:
    if not warning: throw "INVALID_ARGUMENT"
    emit --kind=WARNING --structured=structured

  /** Variant of $(emit --kind [--structured]) using the $INTERACTIVE kind. */
  // TODO: change the bool type to 'True'.
  emit --interactive/bool [--structured] -> none:
    if not interactive: throw "INVALID_ARGUMENT"
    emit --kind=INTERACTIVE --structured=structured

  /** Variant of $(emit --kind [--structured]) using the $ERROR kind. */
  // TODO: change the bool type to 'True'.
  emit --error/bool [--structured] -> none:
    if not error: throw "INVALID_ARGUMENT"
    emit --kind=ERROR --structured=structured

  /**
  Variant of $(emit --kind [--structured]) using the $RESULT kind.

  A program should do only a single result output per run.
  */
  // TODO: change the bool type to 'True'.
  emit --result/bool [--structured] -> none:
    if not result: throw "INVALID_ARGUMENT"
    emit --kind=RESULT --structured=structured

  /**
  Whether the UI wants a structured representation for the given $kind.
  */
  wants-structured --kind/int=RESULT -> bool:
    return printer_.needs-structured --kind=kind

  /**
  Whether the UI wants a human representation for the given $kind.
  */
  wants-human --kind/int=RESULT -> bool:
    return printer_.wants-human --kind=kind

  /**
  Aborts the program with the given error message.

  # Inheritance
  It is safe to override this method with a custom implementation. The
    method should always abort. Either with 'exit 1', or with an exception.
  */
  abort -> none:
    exit 1

  /**
  Returns a new Ui object with the given $level and $printer.

  If $level is not provided, the level of the new Ui object is the same as
    this object.

  If $printer is not provided, the printer of the new Ui object
    is the same as this object.
  */
  with --level/int?=null --printer/Printer?=null -> Ui:
    return Ui
        --level=level or this.level
        --printer=printer or this.printer_

class HumanPrinter extends HumanPrinterBase:
  print_ str/string:
    print str

  emit-structured --kind/int object/any:
    unreachable

class PlainPrinter extends PlainPrinterBase:
  print_ str/string:
    print str

  emit-structured --kind/int object/any:
    unreachable

class JsonPrinter extends HumanPrinterBase:
  needs-structured --kind/int -> bool:
    return kind == Ui.RESULT

  wants-human --kind/int -> bool:
    return kind != Ui.RESULT

  print_ str/string:
    print-on-stderr_ str

  emit-structured --kind/int object/any:
    print (json.stringify object)
