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
    return JsonUi --level=level
  else:
    return ConsoleUi --level=level

interface Printer:
  emit o/any --title/string?=null --header/Map?=null
  emit-structured [--json] [--stdout]

abstract class PrinterBase implements Printer:
  prefix_/string? := ?
  constructor .prefix_:

  abstract needs-structured_ -> bool
  abstract print_ str/string
  abstract handle-structured_ o/any

  emit o/any --title/string?=null --header/Map?=null:
    if needs-structured_:
      handle-structured_ o
      return

    // Prints the prefix on a line. Typically something like 'Warning: ' or 'Error: '.
    print-prefix-on-line := :
      if prefix_:
        print_ prefix_
        prefix_ = null

    indentation := ""
    // Local block that prints the title, if any on one line, and
    // adjusts the indentation.
    print-title-on-line := :
      if title:
        print_ "$title:"
        indentation = "  "

    if o is List and header:
      // A table.
      print-prefix-on-line.call
      emit-table_ --title=title --header=header (o as List)
    else if o is List:
      print-prefix-on-line.call
      print-title-on-line.call
      emit-list_ (o as List) --indentation=indentation
    else if o is Map:
      print-prefix-on-line.call
      print-title-on-line.call
      emit-map_ (o as Map) --indentation=indentation
    else:
      // Convert to string.
      msg := "$o"
      if title:
        msg = "$title: $msg"
      if prefix_:
        msg = "$prefix_$msg"
        prefix_ = null
      print_ msg

  emit-list_ list/List --indentation/string:
    list.do:
      // TODO(florian): should the entries be recursively pretty-printed?
      print_ "$indentation$it"

  emit-map_ map/Map --indentation/string:
    map.do: | key value |
      if value is Map:
        print_ "$indentation$key:"
        emit-map_ value --indentation="$indentation  "
      else:
        // TODO(florian): should the entries handle lists as well.
        print_ "$indentation$key: $value"

  emit-table_ --title/string?=null --header/Map table/List:
    if needs-structured_:
      handle-structured_ table
      return

    if prefix_:
      print_ prefix_
      prefix_ = null

    // TODO(florian): make this look nicer.
    if title:
      print_ "$title:"

    column-count := header.size
    column-sizes := header.map: | _ header-string/string | header-string.size --runes

    table.do: | row/Map |
      header.do --keys: | key/string |
        entry/string := "$row[key]"
        column-sizes.update key: | old/int | max old (entry.size --runes)

    pad := : | o/Map |
      padded-row := []
      column-sizes.do: | key size |
        entry := "$o[key]"
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

  emit-structured [--json] [--stdout]:
    if needs-structured_:
      handle-structured_ json.call
      return

    stdout.call this

/**
A class for handling input/output from the user.

The Ui class is used to display text to the user and to get input from the user.
*/
abstract class Ui:
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
  constructor --.level/int:
    if not DEBUG-LEVEL >= level >= SILENT-LEVEL:
      error "Invalid level: $level"

  do --kind/int=Ui.INFO [generator] -> none:
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
    generator.call (printer_ --kind=kind)

  /** Emits the given object $o at a debug-level. */
  debug o/any --title/string?=null --header/Map?=null:
    do --kind=DEBUG: | printer/Printer | printer.emit o --title=title --header=header

  /** Emits the given object $o at a verbose-level. */
  verbose o/any --title/string?=null --header/Map?=null:
    do --kind=VERBOSE: | printer/Printer | printer.emit o --title=title --header=header

  /** Emits the given object $o at an info-level. */
  info o/any --title/string?=null --header/Map?=null:
    do --kind=INFO: | printer/Printer | printer.emit o --title=title --header=header

  /** Alias for $info. */
  print o/any: info o

  /** Emits the given object $o at a warning-level. */
  warning o/any --title/string?=null --header/Map?=null:
    do --kind=WARNING: | printer/Printer | printer.emit o --title=title --header=header

  /** Emits the given object $o at an interactive-level. */
  interactive o/any --title/string?=null --header/Map?=null:
    do --kind=INTERACTIVE: | printer/Printer | printer.emit o --title=title --header=header

  /** Emits the given object $o at an error-level. */
  error o/any --title/string?=null --header/Map?=null:
    do --kind=ERROR: | printer/Printer | printer.emit o --title=title --header=header

  /** Emits the given object $o as result. */
  result o/any --title/string?=null --header/Map?=null:
    do --kind=RESULT: | printer/Printer | printer.emit o --title=title --header=header

  /**
  Aborts the program with the given error message.
  First emits $o at an error-level, then calls $abort.
  */
  abort o/any --title/string?=null --header/Map?=null:
    do --kind=ERROR: | printer/Printer | printer.emit o --title=title --header=header
    abort

  printer_ --kind/int -> Printer:
    prefix/string? := null
    if kind == Ui.WARNING:
      prefix = "Warning: "
    else if kind == Ui.ERROR:
      prefix = "Error: "
    return create-printer_ prefix kind

  /**
  Aborts the program with the given error message.

  # Inheritance
  It is safe to override this method with a custom implementation. The
    method should always abort. Either with 'exit 1', or with an exception.
  */
  abort -> none:
    exit 1

  /**
  Creates a new printer for the given $kind.

  # Inheritance
  Customization generally happens at this level, by providing different
    implementations of the $Printer class.
  */
  abstract create-printer_ prefix/string? kind/int -> Printer

/**
Prints the given $str using $print.

This function is necessary, as $ConsolePrinter has its own 'print' method,
  which shadows the global one.
*/
global-print_ str/string:
  print str

class ConsolePrinter extends PrinterBase:
  constructor prefix/string?:
    super prefix

  needs-structured_: return false

  print_ str/string:
    global-print_ str

  handle-structured_ structured:
    unreachable

class ConsoleUi extends Ui:

  constructor --level/int=Ui.NORMAL-LEVEL:
    super --level=level

  create-printer_ prefix/string? kind/int -> Printer:
    return ConsolePrinter prefix

class JsonPrinter extends PrinterBase:
  kind_/int

  constructor prefix/string? .kind_:
    super prefix

  needs-structured_: return kind_ == Ui.RESULT

  print_ str/string:
    print-on-stderr_ str

  handle-structured_ structured:
    global-print_ (json.stringify structured)

class JsonUi extends Ui:
  constructor --level/int=Ui.QUIET-LEVEL:
    super --level=level

  create-printer_ prefix/string? kind/int -> Printer:
    return JsonPrinter prefix kind
