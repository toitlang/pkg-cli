// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli show Cli FileStore
import host.file

store-from-file cli/Cli:
  cache := cli.cache

  data := cache.get "my-file-key": | store/FileStore |
    // Block that is called when the key is not found.
    print "Data is not cached. Computing it."
    store.with-tmp-directory: | tmp-dir |
      data-path := "$tmp-dir/data.txt"
      // Create a file with some data.
      file.write-content --path=data-path "Hello world"
      store.move data-path

  print data  // Prints the binary representation of "Hello world".
