// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import host.directory
import host.file
import host.os
import host.pipe
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

tool-path_ tool/string -> string:
  if system.platform != system.PLATFORM-WINDOWS: return tool
  // On Windows, we use the <tool>.exe that comes with Git for Windows.

  // TODO(florian): depending on environment variables is brittle.
  // We should use `SearchPath` (to find `git.exe` in the PATH), or
  // 'SHGetSpecialFolderPath' (to find the default 'Program Files' folder).
  program-files-path := os.env.get "ProgramFiles"
  if not program-files-path:
    // This is brittle, as Windows localizes the name of the folder.
    program-files-path = "C:/Program Files"
  result := "$program-files-path/Git/usr/bin/$(tool).exe"
  if not file.is-file result:
    throw "Could not find $result. Please install Git for Windows"
  return result

/**
Copies the $source directory into the $target directory.

If the $target directory does not exist, it is created.
*/
// TODO(florian): this should not use 'tar'. Once we have support for
// symlinks this function should be rewritten.
copy-directory --source/string --target/string:
  directory.mkdir --recursive target
  with-tmp-directory: | tmp-dir |
    // We are using `tar` so we keep the permissions and symlinks.
    tar := tool-path_ "tar"

    tmp-tar := "$tmp-dir/tmp.tar"
    extra-args := []
    if system.platform == system.PLATFORM-WINDOWS:
      // Tar can't handle backslashes as separators.
      source = source.replace --all "\\" "/"
      target = target.replace --all "\\" "/"
      tmp-tar = tmp-tar.replace --all "\\" "/"
      extra-args = ["--force-local"]

    // We are using an intermediate file.
    // Using pipes was too slow on Windows.
    // See https://github.com/toitlang/toit/issues/1568.
    pipe.backticks [tar, "c", "-f", tmp-tar, "-C", source, "."] + extra-args
    pipe.backticks [tar, "x", "-f", tmp-tar, "-C", target] + extra-args
