// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import expect show *
import host.pipe
import .completion_shell

main:
  if not has-command_ "tmux":
    print "tmux not found, skipping bash completion tests."
    return

  // Bash 3.x (macOS default) lacks compopt and has limited programmable
  // completion support. Skip if bash is too old.
  bash-version := (pipe.backticks ["bash", "-c", "echo \$BASH_VERSINFO"]).trim
  if bash-version == "" or bash-version[0] < '4':
    print ""
    print "=== Skipping bash tests (bash $bash-version too old, need 4+) ==="
    return

  with-tmp-dir: | tmpdir |
    binary := setup-test-binary_ tmpdir
    test-bash binary tmpdir

  print ""
  print "All bash completion tests passed!"

test-bash binary/string tmpdir/string:
  print ""
  print "=== Testing bash completion ==="
  tmux := Tmux (next-session-name_) --shell-cmd=["bash", "--norc", "--noprofile"]
  try:
    tmux.send-line "source <($binary completion bash); echo sourced"
    tmux.wait-for "sourced"

    // Subcommand completion (double Tab for ambiguous matches).
    tmux.send-keys ["$binary ", "Tab", "Tab"]
    tmux.wait-for "deploy"
    content := tmux.capture
    expect (content.contains "status")
    expect (content.contains "help")
    expect (content.contains "completion")
    tmux.cancel

    // Unique prefix auto-completes inline.
    tmux.send-keys ["$binary dep", "Tab"]
    tmux.wait-for "deploy"
    tmux.cancel

    // Enum value completion.
    tmux.send-keys ["$binary deploy --channel ", "Tab", "Tab"]
    tmux.wait-for "stable"
    content = tmux.capture
    expect (content.contains "beta")
    expect (content.contains "dev")
    tmux.cancel

    // Short option -d triggers device completion.
    tmux.send-keys ["$binary deploy -d ", "Tab", "Tab"]
    tmux.wait-for "d3b07384"
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
    tmux.send-keys ["$binary deploy --config xconfig.", "Tab", "Tab"]
    tmux.wait-for "xconfig.toml"
    content = tmux.capture
    expect (content.contains "xconfig.yaml")
    expect (not content.contains "xconfig.txt")
    tmux.cancel

    print "  All bash tests passed."
  finally:
    tmux.close
