// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

import fs

/**
Extracts the basename from the given $path, stripping any directory components
  and the .exe extension on Windows.
*/
basename_ path/string -> string:
  name := fs.basename path
  // Strip .exe suffix so that completions work on Windows where
  // system.program-path includes the extension but users type without it.
  if name.ends-with ".exe": name = name[..name.size - 4]
  return name

/**
Returns the list of command names to which a generated completion script
  should bind.

A naive `complete`/`compdef` registration only matches the exact basename
  of the program — i.e. only when the binary is on \$PATH. Users who source
  the script with a path (for example `source <(examples/comp ...)`) would
  then invoke the binary as `examples/comp` or `./examples/comp`, which
  shells look up verbatim and fail to match.

We therefore register every plausible invocation form:
- the basename (for \$PATH-installed binaries),
- the program-path as given (for relative or absolute paths),
- a "./" prefixed variant for relative paths (the common "./bin" case).
*/
completion-bind-names_ program-path/string -> List:
  name := basename_ program-path
  names := [name]
  if program-path != name: names.add program-path
  is-absolute := program-path.starts-with "/"
      or (program-path.size >= 2 and program-path[1] == ':')  // Windows drive.
  already-dotted := program-path.starts-with "./" or program-path.starts-with ".\\"
  if not is-absolute and not already-dotted and program-path != name:
    names.add "./$program-path"
  return names

/**
Sanitizes the given $name for use as a shell function name.

Replaces all non-alphanumeric characters with underscores and prefixes
  with an underscore if the name starts with a digit.
*/
sanitize-func-name_ name/string -> string:
  buffer := []
  name.do --runes: | c/int |
    if 'a' <= c <= 'z' or 'A' <= c <= 'Z' or '0' <= c <= '9':
      buffer.add (string.from-rune c)
    else:
      buffer.add "_"
  result := buffer.join ""
  if result.size > 0 and '0' <= result[0] <= '9':
    result = "_$result"
  return result

/**
Returns a bash completion script for the given $program-path.
*/
bash-completion-script_ --program-path/string -> string:
  program-name := basename_ program-path
  func-name := sanitize-func-name_ program-name
  bind-names := (completion-bind-names_ program-path).map: "\"$it\""
  bind-names-str := bind-names.join " "
  return """
    _$(func-name)_completions() {
        local IFS=\$'\\n'
        shopt -s extglob 2>/dev/null

        local completions
        completions=\$("$program-path" __complete -- "\${COMP_WORDS[@]:1:\$COMP_CWORD}")
        if [ \$? -ne 0 ]; then
            return
        fi

        local directive_line
        directive_line=\$(echo "\$completions" | tail -n 1)
        completions=\$(echo "\$completions" | sed '\$d')

        directive_line="\${directive_line#:}"

        local directive extensions=""
        if [[ "\$directive_line" == *:* ]]; then
            directive="\${directive_line%%:*}"
            extensions="\${directive_line#*:}"
        else
            directive="\$directive_line"
        fi

        local candidates=()
        while IFS='' read -r line; do
            local candidate="\${line%%\$'\\t'*}"
            if [ -n "\$candidate" ]; then
                candidates+=("\$candidate")
            fi
        done <<< "\$completions"

        local cur_word="\${COMP_WORDS[\$COMP_CWORD]}"
        COMPREPLY=(\$(compgen -W "\${candidates[*]}" -- "\$cur_word"))

        if [[ \$directive -eq 1 ]]; then
            compopt +o default 2>/dev/null
        elif [[ \$directive -eq 4 ]]; then
            if [[ \${#COMPREPLY[@]} -eq 0 ]]; then
                if [[ -n "\$extensions" ]]; then
                    local ext_pattern=""
                    IFS=',' read -ra exts <<< "\$extensions"
                    for ext in "\${exts[@]}"; do
                        ext="\${ext#.}"
                        if [[ -n "\$ext_pattern" ]]; then
                            ext_pattern="\$ext_pattern|\$ext"
                        else
                            ext_pattern="\$ext"
                        fi
                    done
                    COMPREPLY=(\$(compgen -f -X "!*.@(\$ext_pattern)" -- "\$cur_word"))
                    COMPREPLY+=(\$(compgen -d -- "\$cur_word"))
                    # Remove duplicate directory entries.
                    COMPREPLY=(\$(printf '%s\\n' "\${COMPREPLY[@]}" | sort -u))
                else
                    compopt -o default 2>/dev/null
                fi
            fi
        elif [[ \$directive -eq 8 ]]; then
            if [[ \${#COMPREPLY[@]} -eq 0 ]]; then
                compopt -o dirnames 2>/dev/null
            fi
        fi
    }
    complete -o default -F _$(func-name)_completions $bind-names-str"""

/**
Returns a zsh completion script for the given $program-path.
*/
zsh-completion-script_ --program-path/string -> string:
  program-name := basename_ program-path
  func-name := sanitize-func-name_ program-name
  bind-names := (completion-bind-names_ program-path).map: "\"$it\""
  bind-names-str := bind-names.join " "
  return """
    #compdef $program-name

    _$(func-name)() {
        local -a completions
        local directive_line directive extensions=""

        local output
        output=\$("$program-path" __complete -- "\${words[@]:1:\$((CURRENT-1))}" 2>/dev/null)
        if [ \$? -ne 0 ]; then
            return
        fi

        directive_line=\$(echo "\$output" | tail -n 1)
        directive_line="\${directive_line#:}"

        if [[ "\$directive_line" == *:* ]]; then
            directive="\${directive_line%%:*}"
            extensions="\${directive_line#*:}"
        else
            directive="\$directive_line"
        fi

        local -a lines
        lines=("\${(@f)\$(echo "\$output" | sed '\$d')}")

        local -a candidates
        for line in "\${lines[@]}"; do
            if [[ "\$line" == *\$'\\t'* ]]; then
                local val="\${line%%\$'\\t'*}"
                local desc="\${line#*\$'\\t'}"
                candidates+=("\${val}:\$desc")
            else
                if [ -n "\$line" ]; then
                    candidates+=("\$line")
                fi
            fi
        done

        if [[ \${#candidates[@]} -gt 0 ]]; then
            _describe '' candidates
        fi

        if [[ \$directive -eq 4 ]]; then
            if [[ -n "\$extensions" ]]; then
                # Issue one _files -g call per extension. Alternation
                #   patterns like "(*.toml|*.yaml)" or "*.(toml|yaml)"
                #   break _path_files directory-prefix navigation in zsh,
                #   so we avoid them entirely.
                local -a ext_array
                ext_array=(\${(s:,:)extensions})
                for ext in "\${ext_array[@]}"; do
                    _files -g "*\$ext"
                done
            else
                _files
            fi
        elif [[ \$directive -eq 8 ]]; then
            _directories
        fi
    }

    compdef _$(func-name) $bind-names-str"""

/**
Returns a fish completion script for the given $program-path.
*/
fish-completion-script_ --program-path/string -> string:
  program-name := basename_ program-path
  func-name := sanitize-func-name_ program-name
  // Fish's `complete -c` takes one command name per invocation, so emit
  //   one `complete` line per bind name.
  bind-lines := (completion-bind-names_ program-path).map: | n/string |
    "complete -c \"$n\" -f -a '(__$(func-name)_completions)'"
  complete-block := bind-lines.join "\n    "
  return """
    function __$(func-name)_completions
        set -l tokens (commandline -opc)
        set -l current (commandline -ct)

        set -l output ("$program-path" __complete -- \$tokens[2..] \$current 2>/dev/null)
        if test \$status -ne 0
            return
        end

        set -l directive_line (string replace -r '^:(.*)' '\$1' \$output[-1])
        set -e output[-1]

        set -l directive \$directive_line
        set -l extensions ""
        if string match -q '*:*' \$directive_line
            set directive (string split ':' \$directive_line)[1]
            set extensions (string split ':' \$directive_line)[2]
        end

        for line in \$output
            set -l parts (string split \\t \$line)
            if test (count \$parts) -gt 1
                printf '%s\\t%s\\n' \$parts[1] \$parts[2]
            else
                if test -n "\$parts[1]"
                    echo \$parts[1]
                end
            end
        end

        if test "\$directive" = "4"
            if test -n "\$extensions"
                set -l cur (commandline -ct)
                set -l ext_list (string split ',' \$extensions)
                for f in \$cur*
                    if test -d "\$f"
                        echo \$f
                        continue
                    end
                    for ext in \$ext_list
                        if string match -q "*\$ext" \$f
                            echo \$f
                            break
                        end
                    end
                end
            else
                __fish_complete_path (commandline -ct)
            end
        else if test "\$directive" = "8"
            __fish_complete_directories (commandline -ct)
        end
    end

    $complete-block"""

/**
Returns a PowerShell completion script for the given $program-path.
*/
powershell-completion-script_ --program-path/string -> string:
  program-name := basename_ program-path
  bind-names := (completion-bind-names_ program-path).map: "'$it'"
  bind-names-str := bind-names.join ","
  return """
    Register-ArgumentCompleter -Native -CommandName @($bind-names-str) -ScriptBlock {
        param(\$wordToComplete, \$commandAst, \$cursorPosition)

        \$tokens = \$commandAst.ToString() -split '\\s+'
        if (\$tokens.Length -gt 1) {
            \$completionArgs = \$tokens[1..(\$tokens.Length - 1)]
        } else {
            \$completionArgs = @()
        }
        if (\$completionArgs.Length -eq 0 -or \$completionArgs[-1] -ne \$wordToComplete) {
            \$completionArgs += \$wordToComplete
        }

        \$output = & '$program-path' __complete -- @completionArgs 2>\$null
        if (\$LASTEXITCODE -ne 0 -or -not \$output) { return }

        \$lines = \$output -split '\\r?\\n'
        \$directiveLine = (\$lines[-1] -replace '^:', '')
        \$lines = \$lines[0..(\$lines.Length - 2)]

        \$directive = \$directiveLine
        \$extensions = ''
        if (\$directiveLine -match '^(\\d+):(.+)\$') {
            \$directive = \$Matches[1]
            \$extensions = \$Matches[2]
        }

        foreach (\$line in \$lines) {
            if (-not \$line) { continue }
            if (\$line -match '^([^\\t]+)\\t(.+)\$') {
                \$value = \$Matches[1]
                \$desc = \$Matches[2]
            } else {
                \$value = \$line
                \$desc = \$line
            }
            if (\$value -notlike "\$wordToComplete*") { continue }
            [System.Management.Automation.CompletionResult]::new(
                \$value,
                \$value,
                'ParameterValue',
                \$desc
            )
        }

        if (\$directive -eq '4' -or \$directive -eq '8') {
            \$completionType = if (\$directive -eq '8') { 'ProviderContainer' } else { 'ProviderItem' }
            \$items = Get-ChildItem -Path "\$wordToComplete*" -ErrorAction SilentlyContinue
            if (\$directive -eq '8') {
                \$items = \$items | Where-Object { \$_.PSIsContainer }
            } elseif (\$extensions) {
                \$extArray = \$extensions -split ','
                \$items = \$items | Where-Object {
                    \$_.PSIsContainer -or (\$extArray -contains \$_.Extension)
                }
            }
            \$items | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    \$_.FullName,
                    \$_.Name,
                    \$completionType,
                    \$_.FullName
                )
            }
        }
    }"""
