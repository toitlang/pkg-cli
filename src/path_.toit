// Copyright (C) 2024 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import .cli show Command

class Path:
  invoked-command/string
  commands/List

  constructor command/Command --invoked-command/string:
    return Path.private_ --invoked-command=invoked-command [command]

  constructor.private_ .commands --.invoked-command:

  operator + command/Command -> Path:
    return Path.private_ (commands + [command]) --invoked-command=invoked-command

  size -> int:
    return commands.size

  operator [] index/int -> Command:
    return commands[index]

  first -> Command:
    return commands.first

  last -> Command:
    return commands.last

  to-string -> string:
    if commands.size == 1:
      return invoked-command
    names := commands[1..].map: |command/Command| command.name
    return "$invoked-command $(names.join " ")"

  stringify -> string:
    return to-string
