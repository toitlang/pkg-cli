// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli show Cli DirectoryStore
import host.file

store-directory cli/Cli:
  cache := cli.cache

  directory := cache.get-directory-path "my-dir-key": | store/DirectoryStore |
    // Block that is called when the key is not found.
    // The returned directory is stored in the cache.
    print "Directory is not cached. Computing it."
    store.with-tmp-directory: | tmp-dir |
      // Create a few files with some data.
      file.write-content --path="$tmp-dir/data1.txt" "Hello world"
      file.write-content --path="$tmp-dir/data2.txt" "Bonjour monde"
      store.move tmp-dir

  print directory  // Prints the path to the directory.
