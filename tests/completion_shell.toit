// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import fs
import host.directory
import host.file
import host.pipe
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
  wait-for expected/string --timeout-ms/int=10000 -> none:
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
    directory.rmdir --recursive --force tmpdir

has-command_ name/string -> bool:
  exit-code := pipe.run-program ["which", name]
  return exit-code == 0

/**
Compiles the test app binary and creates OptionPath test artifacts.
Returns the path to the compiled binary.
The $tmpdir must already exist.
*/
setup-test-binary_ tmpdir/string -> string:
  test-dir := fs.dirname system.program-path
  app-source := "$test-dir/completion_shell_test_app.toit"
  binary := "$tmpdir/fleet"
  if system.platform == system.PLATFORM-WINDOWS:
    binary = "$tmpdir/fleet.exe"
  print "Compiling test app..."
  pipe.run-program ["toit", "compile", "-o", binary, app-source]
  print "Binary compiled: $binary"

  // Create artifacts for OptionPath completion testing.
  file.write-contents --path="$tmpdir/xfirmware.bin" ""
  directory.mkdir "$tmpdir/xreleases"

  // Create artifacts for extension-filtered completion testing.
  file.write-contents --path="$tmpdir/xconfig.toml" ""
  file.write-contents --path="$tmpdir/xconfig.yaml" ""
  file.write-contents --path="$tmpdir/xconfig.txt" ""

  // Directory used to verify that extension-filtered completion still lets
  //   the user navigate into directories.
  directory.mkdir "$tmpdir/xsubdir"
  file.write-contents --path="$tmpdir/xsubdir/nested.toml" ""

  return binary

