// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import cli show Cli FileStore

store-bytes cli/Cli:
  cache := cli.cache

  data := cache.get "my-key": | store/FileStore |
    // Block that is called when the key is not found.
    // The returned data is stored in the cache.
    print "Data is not cached. Computing it."
    store.save #[0x01, 0x02, 0x03]

  print data  // Prints #[0x01, 0x02, 0x03].
