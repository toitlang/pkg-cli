// Copyright (C) 2024 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import cli show *
import host.file

store-bytes cli/Cli:
  cache := cli.cache

  data := cache.get "my-key": | store/FileStore |
    // Block that is called when the key is not found.
    // The returned data is stored in the cache.
    print "Data is not cached. Computing it."
    store.save #[0x01, 0x02, 0x03]

  print data  // Prints #[0x01, 0x02, 0x03].

store-directory cli/Cli:
  cache := cli.cache

  directory := cache.get-directory-path "my-dir-key": | store/DirectoryStore |
    // Block that is called when the key is not found.
    // The returned directory is stored in the cache.
    print "Directory is not cached. Computing it."
    store.with-tmp-directory: | tmp-dir |
      // Create a few files with some data.
      file.write-contents --path="$tmp-dir/data1.txt" "Hello world"
      file.write-contents --path="$tmp-dir/data2.txt" "Bonjour monde"
      store.move tmp-dir

  print directory  // Prints the path to the directory.

main args:
  // Uses the application name "cli-example" which will be used
  // to compute the path of the cache directory.
  root-cmd := Command "cli-example"
      --help="""
          An example application demonstrating the file-cache.
          """
      --options=[
        OptionEnum "mode" ["file", "directory"]
            --help="Store a file in the cache."
            --required,
      ]
      --run=:: run it
  root-cmd.run args

run invocation/Invocation:
  if invocation["mode"] == "file":
    store-bytes invocation.cli
  else:
    store-directory invocation.cli
