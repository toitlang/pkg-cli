// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

/**
Converts snake-case strings to kebab case.

For example, "hello_world" becomes "hello-world".
*/
to_kebab str/string -> string:
  return str.replace --all "_" "-"
