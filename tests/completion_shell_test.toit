// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import fs
import host.pipe
import host.directory
import system

/**
A tmux session wrapper for testing interactive shell completions.
*/
class Tmux:
  /** The socket name, unique per session to avoid server conflicts. */
  socket-name/string

  constructor .socket-name --shell-cmd/List --width/int=200 --height/int=50:
    args := [
      "tmux",
      "-L", socket-name,     // Use a dedicated server socket.
      "new-session",
      "-d",                   // Detached.
      "-s", socket-name,
      "-x", "$width",
      "-y", "$height",
    ] + shell-cmd
    exit-code := pipe.run-program args
    if exit-code != 0:
      throw "tmux new-session failed with exit code $exit-code for shell '$shell-cmd'"
    // Wait for the shell to initialize.
    send-line "echo tmux-ready"
    wait-for "tmux-ready"

  /**
  Sends keystrokes to the tmux session.
  Each argument is a tmux key name (e.g. "Enter", "Tab", "C-c").
  */
  send-keys keys/List -> none:
    pipe.run-program ["tmux", "-L", socket-name, "send-keys", "-t", socket-name] + keys

  /** Sends text followed by Enter. */
  send-line text/string -> none:
    send-keys [text, "Enter"]

  /** Sends Ctrl-C to cancel the current line, then waits for the shell to be ready. */
  cancel -> none:
    send-keys ["C-c"]
    // Echo a marker and wait for it so we know the shell is ready.
    marker := "ready-$Time.monotonic-us"
    send-line "echo $marker"
    wait-for marker

  /** Captures the current pane content as a string. */
  capture -> string:
    return pipe.backticks ["tmux", "-L", socket-name, "capture-pane", "-t", socket-name, "-p"]

  /**
  Waits until the pane contains the given $expected string, or throws on timeout.
  */
  wait-for expected/string --timeout-ms/int=5000 -> none:
    deadline := Time.monotonic-us + timeout-ms * 1000
    delay-ms := 10
    while Time.monotonic-us < deadline:
      content := capture
      if content.contains expected: return
      sleep --ms=delay-ms
      delay-ms = min 500 (delay-ms * 2)
    content := capture
    throw "Timed out waiting for '$expected' in tmux pane. Content:\n$content"

  /** Kills the tmux server (and its session). */
  close -> none:
    catch: pipe.run-program ["tmux", "-L", socket-name, "kill-server"]

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

    // Create artifacts for OptionPath completion testing.
    pipe.run-program ["touch", "$tmpdir/xfirmware.bin"]
    pipe.run-program ["mkdir", "$tmpdir/xreleases"]

    test-bash tmpdir
    test-zsh tmpdir
    test-fish tmpdir

    print ""
    print "All shell completion tests passed!"

test-bash tmpdir/string:
  // Bash 3.x (macOS default) lacks compopt and has limited programmable
  // completion support. Skip if bash is too old.
  bash-version := (pipe.backticks ["bash", "-c", "echo \$BASH_VERSINFO"]).trim
  if bash-version == "" or bash-version[0] < '4':
    print ""
    print "=== Skipping bash tests (bash $bash-version too old, need 4+) ==="
    return

  print ""
  print "=== Testing bash completion ==="
  tmux := Tmux (next-session-name_) --shell-cmd=["bash", "--norc", "--noprofile"]
  try:
    tmux.send-line "source <($binary_ completion bash); echo sourced"
    tmux.wait-for "sourced"

    // Subcommand completion (double Tab for ambiguous matches).
    tmux.send-keys ["$binary_ ", "Tab", "Tab"]
    tmux.wait-for "deploy"
    content := tmux.capture
    assert_ (content.contains "status")
    assert_ (content.contains "help")
    assert_ (content.contains "completion")
    tmux.cancel

    // Unique prefix auto-completes inline.
    tmux.send-keys ["$binary_ dep", "Tab"]
    tmux.wait-for "deploy"
    tmux.cancel

    // Enum value completion.
    tmux.send-keys ["$binary_ deploy --channel ", "Tab", "Tab"]
    tmux.wait-for "stable"
    content = tmux.capture
    assert_ (content.contains "beta")
    assert_ (content.contains "dev")
    tmux.cancel

    // Short option -d triggers device completion.
    tmux.send-keys ["$binary_ deploy -d ", "Tab", "Tab"]
    tmux.wait-for "d3b07384"
    tmux.cancel

    // OptionPath: file option falls back to file completion.
    tmux.send-line "cd $tmpdir && echo cd-done"
    tmux.wait-for "cd-done"
    tmux.send-keys ["$binary_ deploy --firmware xfirm", "Tab"]
    tmux.wait-for "xfirmware.bin"
    tmux.cancel

    // OptionPath --directory: falls back to directory-only completion.
    tmux.send-keys ["$binary_ deploy --output-dir xrel", "Tab"]
    tmux.wait-for "xreleases"
    tmux.cancel

    print "  All bash tests passed."
  finally:
    tmux.close

test-zsh tmpdir/string:
  if not has-command_ "zsh":
    print ""
    print "=== Skipping zsh tests (zsh not installed) ==="
    return

  print ""
  print "=== Testing zsh completion ==="
  tmux := Tmux (next-session-name_) --shell-cmd=["zsh", "-f"]
  try:
    tmux.send-line "autoload -U compinit && compinit -u && echo ready"
    tmux.wait-for "ready"
    tmux.send-line "source <($binary_ completion zsh) && echo sourced"
    tmux.wait-for "sourced"

    // Subcommand completion.
    tmux.send-keys ["$binary_ ", "Tab"]
    tmux.wait-for "deploy"
    content := tmux.capture
    assert_ (content.contains "status")
    tmux.cancel

    // Enum value completion.
    tmux.send-keys ["$binary_ deploy --channel ", "Tab"]
    tmux.wait-for "stable"
    content = tmux.capture
    assert_ (content.contains "beta")
    tmux.cancel

    // Device completion with descriptions.
    tmux.send-keys ["$binary_ deploy --device ", "Tab"]
    tmux.wait-for "Living Room Sensor"
    tmux.cancel

    // OptionPath: file option falls back to file completion.
    tmux.send-line "cd $tmpdir && echo cd-done"
    tmux.wait-for "cd-done"
    tmux.send-keys ["$binary_ deploy --firmware xfirm", "Tab"]
    tmux.wait-for "xfirmware.bin"
    tmux.cancel

    // OptionPath --directory: falls back to directory-only completion.
    tmux.send-keys ["$binary_ deploy --output-dir xrel", "Tab"]
    tmux.wait-for "xreleases"
    tmux.cancel

    print "  All zsh tests passed."
  finally:
    tmux.close

test-fish tmpdir/string:
  if not has-command_ "fish":
    print ""
    print "=== Skipping fish tests (fish not installed) ==="
    return

  print ""
  print "=== Testing fish completion ==="
  tmux := Tmux (next-session-name_) --shell-cmd=["fish", "--no-config"]
  try:
    tmux.send-line "$binary_ completion fish | source; echo sourced"
    tmux.wait-for "sourced"

    // Subcommand completion.
    tmux.send-keys ["$binary_ ", "Tab"]
    tmux.wait-for "deploy"
    content := tmux.capture
    assert_ (content.contains "status")
    tmux.cancel

    // Enum value completion.
    tmux.send-keys ["$binary_ deploy --channel ", "Tab"]
    tmux.wait-for "stable"
    content = tmux.capture
    assert_ (content.contains "beta")
    tmux.cancel

    // Device completion with descriptions.
    tmux.send-keys ["$binary_ deploy --device ", "Tab"]
    tmux.wait-for "Living Room Sensor"
    tmux.cancel

    // OptionPath: file option falls back to file completion.
    tmux.send-line "cd $tmpdir; and echo cd-done"
    tmux.wait-for "cd-done"
    tmux.send-keys ["$binary_ deploy --firmware xfirm", "Tab"]
    tmux.wait-for "xfirmware.bin"
    tmux.cancel

    // OptionPath --directory: falls back to directory-only completion.
    tmux.send-keys ["$binary_ deploy --output-dir xrel", "Tab"]
    tmux.wait-for "xreleases"
    tmux.cancel

    print "  All fish tests passed."
  finally:
    tmux.close

assert_ condition/bool:
  if not condition: throw "ASSERTION_FAILED"
