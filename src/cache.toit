// Copyright (C) 2023 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import crypto.sha256
import encoding.base64
import encoding.json
import fs
import desktop
import host.os
import host.file
import host.directory
import io
import lockfile
import log
import system

import .utils_

/**
Handles cached files.

Typically, caches are stored in the user's home: \$(HOME)/.cache, but users can
  overwrite this by setting the \$XDG_CACHE_HOME environment variable.

To simplify testing, the environment variable '<app-name>_CACHE_DIR' can be used to
  override the cache directory.

This library is thread-safe with respect to creation of entries. It uses file locks,
  to ensure that only one process is creating a cache entry at a time.
*/

/**
A class to manage objects that can be downloaded or generated, but should
  be kept alive if possible.
*/
class Cache:
  app-name/string
  path/string

  /**
  Creates a new cache.

  Determines the cache directory in the following order:
  - If APP_CACHE_DIR (where "APP" is the uppercased version of $app-name) is set,
    uses it as the path to the cache.
  - If the \$XDG_CACHE_HOME environment variable is set, the cache is located
    at \$XDG_CACHE_HOME/$app-name.
  - Otherwise, the cache directory is set to \$(HOME)/.cache/$app-name.
  */
  constructor --app-name/string:
    app-name-upper := app-name.to-ascii-upper
    app-name-upper = app-name-upper.replace --all "-" "_"
    env-path := os.env.get "$(app-name-upper)_CACHE_DIR"
    if env-path:
      return Cache --app-name=app-name --path=env-path

    cache-home := desktop.cache-home
    return Cache --app-name=app-name --path="$cache-home/$(app-name)"

  /**
  Creates a new cache using the given $path as the cache directory.
  */
  constructor --.app-name --.path:

  with-lock_ key/string --lock/lockfile.Lock? [--on-stale-lock] [block] -> none:
    if not lock: lock = lockfile.Lock (get-lockfile-path key)
    lock.do --on-stale=on-stale-lock block
    unreachable

  /**
  Removes the cache entry with the given $key.
  */
  remove key/string -> none:
    key-path := key-path_ key
    if file.is-file key-path:
      file.delete key-path
    else if file.is-directory key-path:
      tmp-path := directory.mkdtemp key-path
      file.rename key-path tmp-path
      directory.rmdir --recursive --force tmp-path

  /**
  Whether the cache contains the given $key.

  The key can point to a file or a directory.
  */
  contains key/string -> bool:
    key-path := key-path_ key
    return file.is-file key-path or file.is-directory key-path

  /**
  Returns a path to the cache entry with the given $key.

  If the cache entry doesn't exist yet, then the returned string
    points to a non-existing file.
  */
  get-file-path key/string -> string:
    return key-path_ key

  get-lockfile-path key/string -> string:
    return "$(key-path_ key).lock"

  /**
  Variant of $(get key [block]).

  Returns a path to the cache entry, instead of the content.
  */
  get-file-path --lock/lockfile.Lock?=null key/string [block] -> string:
    return get-file-path key
        --lock=lock
        --on-stale-lock=(: directory.rmdir it)
        block

  /**
  Variant of $(get key [--on-stale-lock] [block]).

  Returns a path to the cache entry, instead of the content.
  */
  get-file-path key/string -> string
      --lock/lockfile.Lock?=null
      [--on-stale-lock]
      [block]:
    key-path := key-path_ key
    if file.is-file key-path: return key-path
    return update-file_ key
        --lock=lock
        --no-is-update
        --on-stale-lock=on-stale-lock: | path/string store/FileStore_ |
      if file.is-file path:
        // The entry was created in the meantime.
        return path
      block.call store

  /**
  Updates the content of the cache entry with the given $key.

  Calls the $block with the path to the cache entry and an instance of
    $FileStore, which can be used to store the value that should be in the cache.
  */
  update-file_ key/string -> string
      --lock/lockfile.Lock?=null
      --is-update/bool
      [--on-stale-lock]
      [block]:
    with-lock_ key --lock=lock --on-stale-lock=on-stale-lock:
      return update-file-holding-lock_ key --is-update=is-update block
    unreachable

  update-file-holding-lock_ key --is-update/bool [block] -> string:
    key-path := key-path_ key
    if file.is-directory key-path:
      throw "Cache entry '$(key)' is a directory."

    file-store := FileStore_ this key --is-update=is-update
    try:
      block.call key-path file-store
      if (not is-update or not file.is-file key-path) and
          not file-store.has-stored_:
        throw "Generator callback didn't store anything."
    finally:
      file-store.close_

    return key-path

  /**
  Variant of $(get key [--on-stale-lock] [block]).

  If a stale lock is detected deletes it. This is an unsafe operation, as
    there is no guarantee that the deleted lock isn't already a new one from
    another process that went through the same logic at the same time.
  */
  get key/string --lock/lockfile.Lock?=null [block] -> ByteArray:
    return get key --lock=lock block --on-stale-lock=(: directory.rmdir it)

  /**
  Returns the content of the cache entry with the given $key.

  If the cache entry doesn't exist yet, calls the $block callback
    to generate it. The block is called with an instance of
    $FileStore, which can be used to store the value that
    should be in the cache.

  Throws, if there already exists a cache entry with the given $key, but
    that entry is not a file.

  Guards the creation of the cache entry with a lockfile. If multiple processes
    try to create the same cache entry at the same time, then only one
    process will call the $block callback, while the other processes wait
    for the lock to be released.

  Reading the cache entry is not guarded by the lock.

  If the lock is detected to be stale, then the $on-stale-lock is called with
    the path to the lock directory as argument.

  If no $lock is given, creates one with the default parameters of $lockfile.Lock,
    at $get-lockfile-path
  */
  get key/string -> ByteArray
      --lock/lockfile.Lock?=null
      [--on-stale-lock]
      [block]:
    key-path := key-path_ key

    if file.is-file key-path:
      // Catch in case there is a concurrent update that deletes the file.
      // If that happens, we try again while holding the lock. The catch
      // might hide a different error (not a file-not-found error), but
      // we are OK with retrying in that case too.
      catch: return file.read-contents key-path

    with-lock_ key --lock=lock --on-stale-lock=on-stale-lock:
      if file.is-file key-path:
        return file.read-contents key-path

      new-path := update-file-holding-lock_ key --is-update=true: | _ store/FileStore_ |
        block.call store
      assert: new-path == key-path
      return file.read-contents new-path
    unreachable

  /**
  Variant of $(update key [--on-stale-lock] [block]).

  If a stale lock is detected deletes it. This is an unsafe operation, as
    there is no guarantee that the deleted lock isn't already a new one from
    another process that went through the same logic at the same time.
  */
  update key/string -> ByteArray
      --lock/lockfile.Lock?=null
      [block]:
    return update key --lock=lock block --on-stale-lock=(: directory.rmdir it)

  /**
  Updates the content of the cache entry with the given $key.

  Calls the $block with the path to the cache entry and an instance of
    $FileStore, which can be used to store the value that should be in the cache.
    The path to the cache entry may point to a non-existing file.

  If no entry exists yet, the $block must store a value in the cache. If
    an entry already exists, the $block may choose to not store a new value.

  Returns the content of the cache entry after the update. Always holds the
    lock while reading the content.

  Guards the update of the cache entry with a lockfile. If multiple processes
    try to create the same cache entry at the same time, then only one
    process will call the $block callback, while the other processes wait
    for the lock to be released.

  If the lock is detected to be stale, then the $on-stale-lock is called with
    the path to the lock directory as argument.

  If no $lock is given, creates one with the default parameters of $lockfile.Lock,
    at $get-lockfile-path
  */
  update key/string -> ByteArray
      --lock/lockfile.Lock?=null
      [--on-stale-lock]
      [block]:
    with-lock_ key --lock=lock --on-stale-lock=on-stale-lock:
      key-path := update-file-holding-lock_ key --is-update block
      return file.read-contents key-path

    unreachable

  /**
  Returns the path to the directory item with the given $key.

  If the cache entry doesn't exist yet, then the returned string
    points to a non-existing directory.
  */
  get-directory-path key/string -> string:
    return key-path_ key

  /**
  Variant of $(get-directory-path key [--on-stale-lock] [block]).


  If a stale lock is detected deletes it. This is an unsafe operation, as
    there is no guarantee that the deleted lock isn't already a new one from
    another process that went through the same logic at the same time.
  */
  get-directory-path key/string --lock/lockfile.Lock?=null [block] -> string:
    return get-directory-path key
        --lock=lock
        --on-stale-lock=(: directory.rmdir it)
        block

  /**
  Returns the path to the cached directory item with the given $key.

  If the cache entry doesn't exist yet, calls the $block callback
    to generate it. The block is called with an instance of
    $DirectoryStore, which must be used to store the value that
    should be in the cache.

  Throws, if there already exists a cache entry with the given $key, but
    that entry is a file.
  */
  get-directory-path key/string -> string
      --lock/lockfile.Lock?=null
      [--on-stale-lock]
      [block]:

    if not lock: lock = lockfile.Lock (get-lockfile-path key)
    lock.do --on-stale=on-stale-lock:
      key-path := key-path_ key
      if file.is-file key-path:
        throw "Cache entry '$(key)' is a file."

      if not file.is-directory key-path:
        directory-store := DirectoryStore_ this key
        try:
          block.call directory-store
          if not directory-store.has-stored_:
            throw "Generator callback didn't store anything."
        finally:
          directory-store.close_

      return key-path
    unreachable

  ensure-cache-directory_:
    directory.mkdir --recursive path

  /**
  Escapes the given $path so it's valid.
  Escapes '\' even if the platform is Windows, where it's a valid
    path separator.
  If two given paths are equal, then the escaped paths are also equal.
  If they are different, then the escaped paths are also different.
  */
  escape-path_ path/string -> string:
    if system.platform != system.PLATFORM-WINDOWS:
      return path
    // On Windows, we need to escape some characters.
    // We use '#' as escape character.
    // We will treat '/' as the folder separator, and escape '\'.
    escaped-path := path.replace --all "#" "##"
    // The following characters are not allowed:
    //  <, >, :, ", |, ?, *
    // '\' and '/' would both become folder separators, so
    // we escape '\' to stay unique.
    // We escape them as #<hex value>.
    [ '<', '>', ':', '"', '|', '?', '*', '\\' ].do:
      escaped-path = escaped-path.replace --all
          string.from-rune it
          "#$(%02X it)"
    if escaped-path.ends-with " " or escaped-path.ends-with ".":
      // Windows doesn't allow files to end with a space or a dot.
      // Add a suffix to make it valid.
      // Note that this still guarantees uniqueness, because
      // a space would normally not be escaped.
      escaped-path = "$escaped-path#20"

    // We reserve the suffix ".lock" for lock files.
    // If the escaped path ends with ".lock_*", we add an extra "_".
    without-trailing-underscore := escaped-path.trim --right "_"
    if without-trailing-underscore.ends-with ".lock":
      escaped-path = "$(escaped-path)_"
    return escaped-path

  key-path_ key/string -> string:
    if system.platform == system.PLATFORM-WINDOWS and key.size > 100:
      // On Windows we shorten the path so it doesn't run into the 260 character limit.
      sha := sha256.Sha256
      sha.add key
      key = "$(base64.encode --url-mode sha.get)"

    return "$(path)/$(escape-path_ key)"

  with-tmp-directory_ key/string?=null [block]:
    ensure-cache-directory_
    prefix := ?
    if key and system.platform != system.PLATFORM-WINDOWS:
      // On Windows don't try to create long prefixes as paths are limited to 260 characters.
      escaped-key := escape-path_ key
      escaped-key = escaped-key.replace --all "/" "_"
      prefix = "$(path)/$(escaped-key)-"
    else:
      prefix = "$(path)/tmp-"

    tmp-dir := directory.mkdtemp prefix
    try:
      block.call tmp-dir
    finally:
      // It's legal for the block to (re)move the directory.
      if file.is-directory tmp-dir:
        directory.rmdir --recursive tmp-dir

/**
An interface to store a file in the cache.

An instance of this class is provided to callers of the cache's get methods
  when the key doesn't exist yet. The caller must then call one of the store
  methods to fill the cache.
*/
interface FileStore:
  key -> string

  /**
  Creates a temporary directory that is on the same file system as the cache.
  As such, it is suitable for a $move call.

  Calls the given $block with the path as argument.
  The temporary directory is deleted after the block returns.
  */
  with-tmp-directory [block] -> none

  /**
  Saves the given $bytes as the content of $key.

  If the key already exists, the generated content is dropped.
  This can happen if two processes try to access the cache at the same time.
  */
  save bytes/io.Data -> none

  /**
  Calls the given $block with a $io.Writer.

  The $block must write its chunks to the writer.
  The writer is closed after the block returns.
  */
  save-via-writer [block] -> none

  /**
  Copies the content of $path to the cache under $key.

  If the key already exists, the generated content is dropped.
  This can happen if two processes try to access the cache at the same time.
  */
  copy path/string -> none

  /**
  Moves the file at $path to the cache under $key.

  If the key already exists, the generated content is dropped.
  This can happen if two processes try to access the cache at the same time.
  */
  move path/string -> none

  // TODO(florian): add "download" method.
  // download url/string --compressed/bool=false --path/string="":

/**
An interface to store a directory in the cache.

An instance of this class is provided to callers of the cache's get methods
  when the key doesn't exist yet. The caller must then call one of the store
  methods to fill the cache.
*/
interface DirectoryStore:
  key -> string

  /**
  Creates a temporary directory that is on the same file system as the cache.
  As such, it is suitable for a $move call.

  Calls the given $block with the path as argument.
  The temporary directory is deleted after the block returns.
  */
  with-tmp-directory [block] -> none

  /**
  Copies the content of the directory $path to the cache under $key.

  If the key already exists, the generated content is dropped.
  This can happen if two processes try to access the cache at the same time.
  */
  copy path/string -> none

  /**
  Moves the directory at $path to the cache under $key.

  If the key already exists, the generated content is dropped.
  This can happen if two processes try to access the cache at the same time.
  */
  move path/string -> none

  // TODO(florian): add "download" method.
  // Must be a tar, tar.gz, tgz, or zip.
  // download url/string --path/string="":


class FileStore_ implements FileStore:
  cache_/Cache
  key/string
  has-stored_/bool := false
  is-closed_/bool := false
  is-update_/bool := ?

  constructor .cache_ .key --is-update/bool:
    is-update_ = is-update

  close_: is-closed_ = true

  /**
  Creates a temporary directory that is on the same file system as the cache.
  As such, it is suitable for a $move call.

  Calls the given $block with the path as argument.
  The temporary directory is deleted after the block returns.
  */
  with-tmp-directory [block] -> none:
    cache_.with-tmp-directory_ block

  /**
  Saves the given $bytes as the content of $key.

  If the key already exists, the generated content is dropped.
  This can happen if two processes try to access the cache at the same time.
  */
  save bytes/io.Data -> none:
    store_: | file-path/string |
      file.write-contents bytes --path=file-path

  /**
  Calls the given $block with a $io.Writer.

  The $block must write its chunks to the writer.
  The writer is closed after the block returns.
  */
  save-via-writer [block] -> none:
    store_: | file-path/string |
      stream := file.Stream.for-write file-path
      try:
        block.call stream.out
      finally:
        stream.close

  /**
  Copies the content of $path to the cache under $key.

  If the key already exists, the generated content is dropped.
  This can happen if two processes try to access the cache at the same time.
  */
  copy path/string -> none:
    store_: | file-path/string |
      copy-file_ --source=path --target=file-path

  /**
  Moves the file at $path to the cache under $key.

  If the key already exists, the generated content is dropped.
  This can happen if two processes try to access the cache at the same time.
  */
  move path/string -> none:
    if has-stored_: throw "Already saved content for key: $key"
    if is-closed_: throw "FileStore is closed"

    store_: | file-path/string |
      // TODO(florian): we should be able to test whether the rename should succeed.
      exception := catch: file.rename path file-path
      if not exception: continue.store_
      // We assume that the files weren't on the same file system.
      copy-file_ --source=path --target=file-path

  store_ [block] -> none:
    if has-stored_: throw "Already saved content for key: $key"
    if is-closed_: throw "FileStore is closed"

    // Save files into a temporary file first, then rename it to the final
    // location.
    cache_.with-tmp-directory_ key: | tmp-dir |
      tmp-path := "$tmp-dir/content"
      block.call tmp-path
      key-path := cache_.key-path_ key
      key-dir := fs.dirname key-path
      directory.mkdir --recursive key-dir
      if is-update_ and file.is-file key-path:
        // When updating, we may need to delete the old file first.
        file.delete key-path
      atomic-move-file_ tmp-path key-path

    has-stored_ = true

class DirectoryStore_ implements DirectoryStore:
  cache_/Cache
  key/string
  has-stored_/bool := false
  is-closed_/bool := false

  constructor .cache_ .key:

  close_: is-closed_ = true

  /**
  Creates a temporary directory that is on the same file system as the cache.
  As such, it is suitable for a $move call.

  Calls the given $block with the path as argument.
  The temporary directory is deleted after the block returns.
  */
  with-tmp-directory [block] -> none:
    cache_.with-tmp-directory_ block

  /**
  Copies the content of the directory $path to the cache under $key.

  If the key already exists, the generated content is dropped.
  This can happen if two processes try to access the cache at the same time.
  */
  copy path/string -> none:
    store_: | dir-path/string |
      copy-directory --source=path --target=dir-path

  /**
  Moves the directory at $path to the cache under $key.

  If the key already exists, the generated content is dropped.
  This can happen if two processes try to access the cache at the same time.
  */
  move path/string -> none:
    store_: | dir-path/string |
      // TODO(florian): we should be able to test whether the rename should succeed.
      exception := catch: file.rename path dir-path
      if not exception: continue.store_
      // We assume that the files weren't on the same file system.
      copy-directory --source=path --target=dir-path

  // TODO(florian): add "download" method.
  // Must be a tar, tar.gz, tgz, or zip.
  // download url/string --path/string="":

  store_ [block] -> none:
    if has-stored_: throw "Already saved content for key: $key"
    if is-closed_: throw "DirectoryStore is closed"

    // Save files into a temporary directory first, then rename it to the final
    // location.
    cache_.with-tmp-directory_ key: | tmp-dir |
      block.call tmp-dir
      key-path := cache_.key-path_ key
      key-dir := fs.dirname key-path
      directory.mkdir --recursive key-dir
      atomic-move-directory_ tmp-dir key-path

    has-stored_ = true


atomic-move-file_ source-path/string target-path/string -> none:
  if file.is-file target-path:
    // This shouldn't happen, as cache creations are guarded by locks.
    return
  file.rename source-path target-path

atomic-move-directory_ source-path/string target-path/string -> none:
  if file.is-directory target-path:
    // This shouldn't happen, as cache creations are guarded by locks.
    return
  file.rename source-path target-path

copy-file_ --source/string --target/string -> none:
  // TODO(florian): we want to keep the permissions of the original file,
  // except that we want to make the file read-only.
  in-stream := file.Stream.for-read source
  out-stream := file.Stream.for-write target
  out-stream.out.write-from in-stream.in
  in-stream.close
  out-stream.close
