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

    // OptionPath --extensions: directories must still be suggested so the
    //   user can navigate into them.
    tmux.send-keys ["$binary deploy --config xsub", "Tab"]
    tmux.wait-for "xsubdir"
    tmux.cancel

    // Completion must also work when the binary is invoked via a relative
    //   path (e.g. ./fleet) rather than the absolute path baked into the
    //   completion script. Re-source with a relative path so that
    //   `complete` registers "./fleet" as a bind name.
    tmux.send-line "source <(./fleet completion bash) && echo re-sourced"
    tmux.wait-for "re-sourced"
    tmux.send-keys ["./fleet deploy --channel ", "Tab", "Tab"]
    tmux.wait-for "stable"
    content = tmux.capture
    expect (content.contains "beta")
    tmux.cancel

    // Tilde expansion: the "lookup" command opens the file given as the
    //   first rest arg and offers fixed candidates for the second arg.
    //   When the file path uses ~, the shell must expand the tilde so
    //   the program can open the file.
    // Find an existing file in $HOME to avoid creating test artifacts.
    tmux.send-line "for f in .profile .bashrc .zshrc .zshenv .bash_profile .config; do test -e ~/\$f && echo tilde-found:\$f && break; done"
    tmux.wait-for "tilde-found:"
    tilde-file := ""
    lines := (tmux.capture).split "\n"
    lines.do: | line/string |
      if (line.trim.starts-with "tilde-found:") and tilde-file == "":
        tilde-file = ((line.trim).split ":").last

    expect (tilde-file != "")

    // Re-source with absolute path.
    tmux.send-line "source <($binary completion bash) && echo re-sourced2"
    tmux.wait-for "re-sourced2"

    // Complete the entry arg using a tilde path for the file.
    // Three Tabs are needed: the first fills the common prefix "tilde-ok-",
    // the second is treated as a new "first Tab" for the updated word, and
    // the third actually displays the candidate list.
    tmux.send-keys ["$binary lookup ~/$(tilde-file) ", "Tab", "Tab", "Tab"]
    tmux.wait-for "tilde-ok-alpha"
    content = tmux.capture
    expect (content.contains "tilde-ok-bravo")
    expect (content.contains "tilde-ok-charlie")
    tmux.cancel

    print "  All bash tests passed."
  finally:
    tmux.close
