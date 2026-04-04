// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import expect show *
import .completion_shell

main:
  if not has-command_ "tmux":
    print "tmux not found, skipping zsh completion tests."
    return

  if not has-command_ "zsh":
    print ""
    print "=== Skipping zsh tests (zsh not installed) ==="
    return

  with-tmp-dir: | tmpdir |
    binary := setup-test-binary_ tmpdir
    test-zsh binary tmpdir

  print ""
  print "All zsh completion tests passed!"

test-zsh binary/string tmpdir/string:
  print ""
  print "=== Testing zsh completion ==="
  tmux := Tmux (next-session-name_) --shell-cmd=["zsh", "-f"]
  try:
    tmux.send-line "autoload -U compinit && compinit -u && echo ready"
    tmux.wait-for "ready"
    tmux.send-line "source <($binary completion zsh) && echo sourced"
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

    // OptionPath --extensions: only .toml and .yaml files should complete.
    tmux.send-keys ["$binary deploy --config xconfig.", "Tab"]
    tmux.wait-for "xconfig.toml"
    content = tmux.capture
    expect (content.contains "xconfig.yaml")
    expect (not content.contains "xconfig.txt")
    tmux.cancel

    print "  All zsh tests passed."
  finally:
    tmux.close
