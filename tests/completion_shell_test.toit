// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import expect show *
import fs
import host.pipe
import host.directory
import system

/**
A tmux session wrapper for testing interactive shell completions.
*/
class Tmux:
  session-name/string

  constructor .session-name --shell/string --width/int=200 --height/int=50:
    pipe.run-program [
      "tmux", "new-session",
      "-d",                   // Detached.
      "-s", session-name,
      "-x", "$width",
      "-y", "$height",
      shell,
    ]
    // Wait for the shell to initialize.
    sleep --ms=500

  /**
  Sends keystrokes to the tmux session.
  Each argument is a tmux key name (e.g. "Enter", "Tab", "C-c").
  */
  send-keys keys/List -> none:
    pipe.run-program ["tmux", "send-keys", "-t", session-name] + keys

  /** Sends a Tab keystroke. */
  send-tab -> none:
    send-keys ["Tab"]

  /** Sends text followed by Enter. */
  send-line text/string -> none:
    send-keys [text, "Enter"]

  /** Sends Ctrl-C to cancel the current line. */
  cancel -> none:
    send-keys ["C-c"]

  /** Captures the current pane content as a string. */
  capture -> string:
    return pipe.backticks ["tmux", "capture-pane", "-t", session-name, "-p"]

  /**
  Waits until the pane contains the given $expected string, or times out.
  Returns true if found, false on timeout.
  */
  wait-for expected/string --timeout-ms/int=5000 -> bool:
    deadline := Time.monotonic-us + timeout-ms * 1000
    while Time.monotonic-us < deadline:
      content := capture
      if content.contains expected: return true
      sleep --ms=200
    return false

  /** Kills the tmux session. */
  close -> none:
    catch: pipe.run-program ["tmux", "kill-session", "-t", session-name]

// Unique session prefix for this test run.
session-id_ := 0

next-session-name_ -> string:
  session-id_++
  return "completion-test-$Time.monotonic-us-$session-id_"

with-tmp-dir [block]:
  tmpdir := directory.mkdtemp "/tmp/completion-shell-test-"
  try:
    block.call tmpdir
  finally:
    catch: pipe.run-program ["rm", "-rf", tmpdir]

binary_ := ?

has-command_ name/string -> bool:
  exit-code := pipe.run-program ["which", name]
  return exit-code == 0

main:
  if not has-command_ "tmux":
    print "tmux not found, skipping shell completion tests."
    return

  test-dir := fs.dirname system.program-path
  app-source := "$test-dir/completion_shell_test_app.toit"

  with-tmp-dir: | tmpdir |
    binary_ = "$tmpdir/fleet"
    print "Compiling test app..."
    pipe.run-program ["toit", "compile", "-o", binary_, app-source]
    print "Binary compiled: $binary_"

    test-bash
    test-zsh
    test-fish

    print ""
    print "All shell completion tests passed!"

test-bash:
  print ""
  print "=== Testing bash completion ==="
  tmux := Tmux (next-session-name_) --shell="bash --norc --noprofile"
  try:
    // Source the completion script.
    tmux.send-line "source <($binary_ completion bash)"
    sleep --ms=500

    // Test 1: Subcommand completion (double Tab for ambiguous matches).
    tmux.send-keys ["$binary_ ", "Tab", "Tab"]
    expect (tmux.wait-for "deploy")
        --message="bash: subcommand 'deploy' should appear"
    content := tmux.capture
    expect (content.contains "status")
        --message="bash: subcommand 'status' should appear"
    expect (content.contains "help")
        --message="bash: subcommand 'help' should appear"
    expect (content.contains "completion")
        --message="bash: subcommand 'completion' should appear"
    tmux.cancel
    sleep --ms=300

    // Test 2: Unique prefix auto-completes inline.
    tmux.send-keys ["$binary_ dep", "Tab"]
    sleep --ms=1000
    content = tmux.capture
    // With a single match, bash auto-completes inline.
    expect (content.contains "deploy")
        --message="bash: 'dep' should auto-complete to 'deploy'"
    tmux.cancel
    sleep --ms=300

    // Test 3: Enum value completion.
    tmux.send-keys ["$binary_ deploy --channel ", "Tab", "Tab"]
    expect (tmux.wait-for "stable")
        --message="bash: enum value 'stable' should appear"
    content = tmux.capture
    expect (content.contains "beta")
        --message="bash: enum value 'beta' should appear"
    expect (content.contains "dev")
        --message="bash: enum value 'dev' should appear"
    tmux.cancel
    sleep --ms=300

    // Test 4: Short option -d triggers device completion.
    tmux.send-keys ["$binary_ deploy -d ", "Tab", "Tab"]
    expect (tmux.wait-for "d3b07384")
        --message="bash: short option -d should show device UUID"
    tmux.cancel
    sleep --ms=300

    print "  All bash tests passed."
  finally:
    tmux.close

test-zsh:
  print ""
  print "=== Testing zsh completion ==="
  tmux := Tmux (next-session-name_) --shell="zsh -f"
  try:
    // Initialize zsh completion system.
    tmux.send-line "autoload -U compinit && compinit -u"
    sleep --ms=500
    tmux.send-line "source <($binary_ completion zsh)"
    sleep --ms=500

    // Test 1: Subcommand completion.
    tmux.send-keys ["$binary_ ", "Tab"]
    expect (tmux.wait-for "deploy")
        --message="zsh: subcommand 'deploy' should appear"
    content := tmux.capture
    expect (content.contains "status")
        --message="zsh: subcommand 'status' should appear"
    tmux.cancel
    sleep --ms=300

    // Test 2: Enum value completion.
    tmux.send-keys ["$binary_ deploy --channel ", "Tab"]
    expect (tmux.wait-for "stable")
        --message="zsh: enum value 'stable' should appear"
    content = tmux.capture
    expect (content.contains "beta")
        --message="zsh: enum value 'beta' should appear"
    tmux.cancel
    sleep --ms=300

    // Test 3: Device completion with descriptions.
    tmux.send-keys ["$binary_ deploy --device ", "Tab"]
    expect (tmux.wait-for "Living Room Sensor")
        --message="zsh: device completion should show description"
    tmux.cancel
    sleep --ms=300

    print "  All zsh tests passed."
  finally:
    tmux.close

test-fish:
  // Check if fish is available.
  if not has-command_ "fish":
    print ""
    print "=== Skipping fish tests (fish not installed) ==="
    return

  print ""
  print "=== Testing fish completion ==="
  tmux := Tmux (next-session-name_) --shell="fish --no-config"
  try:
    // Source the completion script.
    tmux.send-line "$binary_ completion fish | source"
    sleep --ms=500

    // Test 1: Subcommand completion.
    tmux.send-keys ["$binary_ ", "Tab"]
    expect (tmux.wait-for "deploy")
        --message="fish: subcommand 'deploy' should appear"
    content := tmux.capture
    expect (content.contains "status")
        --message="fish: subcommand 'status' should appear"
    tmux.cancel
    sleep --ms=300

    // Test 2: Enum value completion.
    tmux.send-keys ["$binary_ deploy --channel ", "Tab"]
    expect (tmux.wait-for "stable")
        --message="fish: enum value 'stable' should appear"
    content = tmux.capture
    expect (content.contains "beta")
        --message="fish: enum value 'beta' should appear"
    tmux.cancel
    sleep --ms=300

    // Test 3: Device completion with descriptions.
    tmux.send-keys ["$binary_ deploy --device ", "Tab"]
    expect (tmux.wait-for "Living Room Sensor")
        --message="fish: device completion should show description"
    tmux.cancel
    sleep --ms=300

    print "  All fish tests passed."
  finally:
    tmux.close
