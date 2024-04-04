// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import host.os
import host.file
import host.directory
import encoding.json
import fs.xdg
import fs
import .utils_

/**
Loads configurations.

Typically, configurations are layered. For example:
- System: \$(prefix)/etc/XXXconfig
- Global: \$XDG_CONFIG_HOME/XXX/config or ~/.XXXconfig. By default \$XDG_CONFIG_HOME is
  set to \$(HOME).
- Local: \$XXX_DIR/config

For now, only "globals" (the ones from the home directory) are implemented.
*/

/**
A class to manage configurations that should be stored in a file.
*/
class Config:
  app-name/string
  path/string
  data/Map

  /**
  Variant of $(constructor --app-name [--init]).

  Initializes the configuration with an empty map if it doesn't exist.
  */
  constructor --app-name/string:
    return Config --app-name=app-name --init=: {:}

  /**
  Reads the configuration for $app-name.
  Calls $init if no configuration is found and uses it as initial configuration.

  This function looks for the configuration file in the following places:
  - If the environment variable APP_CONFIG (where "APP" is the uppercased version of
    $app-name) is set, uses it as the path to the configuration file.
  - CONFIG_HOME/$app-name/config where CONFIG_HOME is either equal to the environment
    variable XDG_CONFIG_HOME (if set), and \$HOME/.config otherwise.
  - The directories given in \$XDG_CONFIG_DIRS (separated by ':').
  */
  constructor --app-name/string [--init]:
    app-name-upper := app-name.to-ascii-upper
    env-path := os.env.get "$(app-name-upper)_CONFIG"
    if env-path:
      data := read-config-file_ env-path --if_absent=: init.call
      return Config --app-name=app-name --path=env-path --data=data

    config-home := xdg.config-home

    // The path we are using to write configurations to.
    all-dirs := [config-home] + xdg.config-dirs
    all-dirs.do: | dir/string |
      path := "$dir/$app-name/config"
      data := read-config-file_ path --if_absent=: null
      if data:
        return Config --app-name=app-name --path=path --data=data

    default-app-config-path := "$config-home/$app-name/config"
    return Config --app-name=app-name --path=default-app-config-path --data=init.call

  /**
  Variant of $(constructor --app-name --path --data).

  Calls $init if no configuration is found and uses it as initial configuration.
  */
  constructor --app-name/string --path/string [--init]:
    data := read-config-file_ path --if_absent=: init.call
    return Config --app-name=app-name --path=path --data=data

  /**
  Constructs a new configuration with the given $app-name, $path and $data.
  */
  constructor --.app-name --.path --.data:

  static read-config-file_ path/string [--if-absent] -> Map?:
    if not file.is-file path:
      return if-absent.call

    data := null
    exception := catch:
      content := file.read-content path
      data = json.decode content
    if exception: throw "Invalid configuration file '$path': $exception."
    if data is not Map: throw "Invalid JSON in configuration file '$path'."
    return data

  /**
  Whether the configuration contains the given $key.

  The key is split on dots, and the value is searched for in the nested map.
  */
  contains key/string -> bool:
    parts := key.split "."
    current := data
    parts.do:
      if current is not Map: return false
      if current.contains it: current = current[it]
      else: return false
    return true

  /**
  Sets the given $key to $value.

  The key is split on dots, and the value is set in the nested map.
  */
  operator[]= key/string value/any -> none:
    parts := key.split "."
    current := data
    parts[.. parts.size - 1].do:
      if current is not Map: throw "Cannot set $key: Path contains non-map."
      current = current.get it --init=: {:}
    current[parts.last] = value

  /**
  Removes the value for the given $key.
  */
  remove key/string -> none:
    parts := key.split "."
    current := data
    parts[.. parts.size - 1].do:
      if current is not Map: return
      if current.contains it: current = current[it]
      else: return
    current.remove parts.last

  /**
  Gets the value for the given $key.
  Returns null if the $key isn't present.

  The key is split on dots, and the value is searched for in the nested map.
  */
  get key/string -> any:
    return get_ key --no-initialize-if-absent --init=: unreachable

  /**
  Variant of $(get key).

  Calls $init if the $key isn't present, and stores the result as initial
    value.

  Creates all intermediate maps if they don't exist.
  */
  get key/string [--init] -> any:
    return get_ key --initialize-if-absent --init=init

  get_ key/string --initialize-if-absent/bool [--init]:
    parts := key.split "."
    result := data
    for i := 0; i < parts.size; i++:
      part-key := parts[i]
      if result is not Map:
        throw "Invalid key. $(parts[.. i - 1].join ".") is not a map"
      result = result.get part-key --init=:
        if not initialize-if-absent: return null
        i != parts.size - 1 ? {:} : init.call
    return result

  /**
  Writes the configuration to the file that was specified during constructions.
  */
  write:
    write-config-file_ path data

  /**
  Writes the configuration to the given $override-path.
  */
  write override-path/string:
    write-config-file_ override-path data

  /**
  Writes the configuration map $data to the given $path.
  */
  write-config-file_ path/string data/Map:
    directory.mkdir --recursive (fs.dirname path)

    content := json.encode data
    stream := file.Stream.for-write path
    try:
      stream.out.write content
    finally:
      stream.close
