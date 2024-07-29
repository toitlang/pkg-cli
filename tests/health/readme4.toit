// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli
import cli.cache as cli
import host.file

store-directory app/cli.Application:
  cache := app.cache

  directory := cache.get-directory-path "my-dir-key": | store/cli.DirectoryStore |
    // Block that is called when the key is not found.
    // The returned directory is stored in the cache.
    print "Directory is not cached. Computing it."
    store.with-tmp-directory: | tmp-dir |
      // Create a few files with some data.
      file.write-content --path="$tmp-dir/data1.txt" "Hello world"
      file.write-content --path="$tmp-dir/data2.txt" "Bonjour monde"
      store.move tmp-dir

  print directory  // Prints the path to the directory.

main args:
  cmd := cli.Command "my-app"
      --run=:: | app/cli.Application parsed/cli.Invocation |
        print "Data is cached in $app.cache.path"
        store-directory app

  cmd.run args
