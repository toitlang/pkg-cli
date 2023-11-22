// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli
import cli.cache as cli
import host.file

store-bytes app/cli.App:
  cache := app.cache

  data := cache.get "my-key": | store/cli.FileStore |
    // Block that is called when the key is not found.
    print "Data is not cached. Computing it."
    store.save #[0x01, 0x02, 0x03]

  print data  // Prints #[0x01, 0x02, 0x03].

store-from-file app/cli.App:
  cache := app.cache

  data := cache.get "my-file-key": | store/cli.FileStore |
    // Block that is called when the key is not found.
    print "Data is not cached. Computing it."
    store.with-tmp-directory: | tmp-dir |
      data-path := "$tmp-dir/data.txt"
      // Create a file with some data.
      file.write-content --path=data-path "Hello world"
      store.move data-path

  print data  // Prints the binary representation of "Hello world".

main args:
  cmd := cli.Command "my-app"
      --run=:: | app/cli.App parsed/cli.Parsed |
        print "Data is cached in $app.cache.path"
        store-bytes app
        store-from-file app

  cmd.run args
