// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import expect show *
import .completion_shell

main:
  if not has-command_ "tmux":
    print "tmux not found, skipping fish completion tests."
    return

  if not has-command_ "fish":
    print ""
    print "=== Skipping fish tests (fish not installed) ==="
    return

  with-tmp-dir: | tmpdir |
    binary := setup-test-binary_ tmpdir
    test-fish binary tmpdir

  print ""
  print "All fish completion tests passed!"

test-fish binary/string tmpdir/string:
  print ""
  print "=== Testing fish completion ==="
  tmux := Tmux (next-session-name_) --shell-cmd=["fish", "--no-config"]
  try:
    tmux.send-line "$binary completion fish | source; echo sourced"
    tmux.wait-for "sourced"

    // Subcommand completion.
    tmux.send-keys ["$binary ", "Tab"]
    tmux.wait-for "deploy"
    content := tmux.capture
    expect (content.contains "status")
    tmux.cancel

    // Enum value completion.
    tmux.send-keys ["$binary deploy --channel ", "Tab"]
    tmux.wait-for "stable"
    content = tmux.capture
    expect (content.contains "beta")
    tmux.cancel

    // Device completion with descriptions.
    tmux.send-keys ["$binary deploy --device ", "Tab"]
    tmux.wait-for "Living Room Sensor"
    tmux.cancel

    // OptionPath: file option falls back to file completion.
    tmux.send-line "cd $tmpdir && echo cd-done"
    tmux.wait-for "cd-done"
    tmux.send-keys ["$binary deploy --firmware xfirm", "Tab"]
    tmux.wait-for "xfirmware.bin"
    tmux.cancel

    // OptionPath --directory: falls back to directory-only completion.
    tmux.send-keys ["$binary deploy --output-dir xrel", "Tab"]
    tmux.wait-for "xreleases"
    tmux.cancel

    print "  All fish tests passed."
  finally:
    tmux.close
