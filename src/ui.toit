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
  if output-format == null: output-format = "text"

  level/int := ?
  if verbose-level == "debug": level = Ui.DEBUG-LEVEL
  else if verbose-level == "info": level = Ui.NORMAL-LEVEL
  else if verbose-level == "verbose": level = Ui.VERBOSE-LEVEL
  else if verbose-level == "quiet": level = Ui.QUIET-LEVEL
  else if verbose-level == "silent": level = Ui.SILENT-LEVEL
  else: level = Ui.NORMAL-LEVEL

  if output-format == "json":
    return Ui.json --level=level
  else:
    return Ui.console --level=level

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

abstract class PrinterBase implements Printer:

  abstract needs-structured --kind/int -> bool
  abstract emit-structured --kind/int object/any

  abstract print_ str/string

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
      error "Invalid level: $level"

  constructor.console --level/int=NORMAL-LEVEL:
    return Ui --level=level --printer=ConsolePrinter

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
  info object/any:
    emit --kind=INFO --structured=: object

  /** Alias for $info. */
  print object/any:
    info object

  /** Variant of $info using the $DEBUG kind. */
  debug object/any:
    emit --kind=DEBUG --structured=: "$object"

  /** Variant of $info using the $VERBOSE kind. */
  verbose object/any:
    emit --kind=VERBOSE --structured=: "$object"

  /** Variant of $verbose that only calls the block when necessary. */
  verbose [generator]:
    do_ --kind=VERBOSE generator

  /** Emits the given $object at a warning-level as a string. */
  warning object/any:
    emit --kind=WARNING --structured=: "$object"

  /** Emits the given $object at an interactive-level as a string. */
  interactive object/any:
    emit --kind=INTERACTIVE --structured=: "$object"

  /** Emits the given $object at an error-level as a string. */
  error object/any:
    emit --kind=ERROR --structured=: "$object"

  /** Emits the given $object at a result-level as a string. */
  result object/any:
    emit --kind=RESULT --structured=: "$object"

  /**
  Aborts the program with the given error message.
  First emits $object at an error-level as as tring, then calls $abort.
  */
  abort object/any:
    error object
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
      error "Invalid level: $level"
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
  emit-table --kind/int=RESULT table/List --title/string?=null --header/Map?=null:
    do_ --kind=kind:
      if printer_.needs-structured --kind=kind:
        printer_.emit-structured --kind=kind table
      else:
        printer_.emit-table --kind=kind --title=title --header=header table

  /**
  Emits a list.

  Printers are *not* required to display the title.
  */
  emit-list --kind/int=RESULT list/List --title/string?=null:
    do_ --kind=kind:
      if printer_.needs-structured --kind=kind:
        printer_.emit-structured --kind=kind list
      else:
        printer_.emit-list --kind=kind --title=title list

  /**
  Emits a map.

  Printers are *not* required to display the title.
  */
  emit-map --kind/int=RESULT map/Map --title/string?=null:
    do_ --kind=kind:
      if printer_.needs-structured --kind=kind:
        printer_.emit-structured --kind=kind map
      else:
        printer_.emit-map --kind=kind --title=title map

  /**
  Emits the value created by calling $structured or $text.

  If the UI's printer requests a structured representation calls the $structured block and
    passes the result to the printer.

  If the printer does not request a structured representation calls the $text block and
    passes the result as string to the printer. The $text block may return
    null to indicate that no output should be generated.
  */
  emit --kind/int=RESULT [--structured] [--text]:
    do_ --kind=kind:
      if printer_.needs-structured --kind=kind:
        printer_.emit-structured --kind=kind structured.call
      else:
        message := text.call
        if message:
          printer_.emit --kind=kind "$text.call"

  /**
  Variant of $(emit --kind [--structured] [--text]).

  If the printer needs a non-structred representation, simply converts the
    result of the $structured block to a string.
  */
  emit --kind/int=RESULT [--structured]:
    do_ --kind=kind:
      if printer_.needs-structured --kind=kind:
        printer_.emit-structured --kind=kind structured.call
      else:
        printer_.emit --kind=kind "$(structured.call)"

  /**
  Whether the UI wants a structured representation for the given $kind.
  */
  wants-structured --kind/int=RESULT -> bool:
    return printer_.needs-structured --kind=kind

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

/**
Prints the given $str using $print.

This function is necessary, as $ConsolePrinter has its own 'print' method,
  which shadows the global one.
*/
global-print_ str/string:
  print str

class ConsolePrinter extends PrinterBase:
  needs-structured --kind/int -> bool: return false

  print_ str/string:
    global-print_ str

  emit-structured --kind/int object/any:
    unreachable

class JsonPrinter extends PrinterBase:
  needs-structured --kind/int -> bool: return kind == Ui.RESULT

  print_ str/string:
    print-on-stderr_ str

  emit-structured --kind/int object/any:
    global-print_ (json.stringify object)
