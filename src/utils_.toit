// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import host.directory
import host.file
import host.os
import system

/**
Converts snake-case strings to kebab case.

For example, "hello_world" becomes "hello-world".
*/
to-kebab str/string -> string:
  return str.replace --all "_" "-"

with-tmp-directory [block]:
  tmpdir := directory.mkdtemp "/tmp/artemis-"
  try:
    block.call tmpdir
  finally:
    directory.rmdir --recursive tmpdir

/**
Copies the $source directory into the $target directory.

If the $target directory does not exist, it is created.
*/
copy-directory --source/string --target/string:
  directory.mkdir --recursive target
  file.copy --recursive --source=source --target=target
