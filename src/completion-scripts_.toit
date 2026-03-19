// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.

/**
Extracts the basename from the given $path, stripping any directory components.
*/
basename_ path/string -> string:
  slash := path.index-of --last "/"
  if slash >= 0: return path[slash + 1..]
  return path

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
  return """
    _$(func-name)_completions() {
        local IFS=\$'\\n'

        local completions
        completions=\$("$program-path" __complete -- "\${COMP_WORDS[@]:1:\$COMP_CWORD}")
        if [ \$? -ne 0 ]; then
            return
        fi

        local directive
        directive=\$(echo "\$completions" | tail -n 1)
        completions=\$(echo "\$completions" | sed '\$d')

        directive="\${directive#:}"

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
                compopt -o default 2>/dev/null
            fi
        elif [[ \$directive -eq 8 ]]; then
            if [[ \${#COMPREPLY[@]} -eq 0 ]]; then
                compopt -o dirnames 2>/dev/null
            fi
        fi
    }
    complete -o default -F _$(func-name)_completions "$program-name\""""

/**
Returns a zsh completion script for the given $program-path.
*/
zsh-completion-script_ --program-path/string -> string:
  program-name := basename_ program-path
  func-name := sanitize-func-name_ program-name
  return """
    #compdef $program-name

    _$(func-name)() {
        local -a completions
        local directive

        local output
        output=\$("$program-path" __complete -- "\${words[@]:1:\$((CURRENT-1))}" 2>/dev/null)
        if [ \$? -ne 0 ]; then
            return
        fi

        directive=\$(echo "\$output" | tail -n 1)
        directive="\${directive#:}"

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
            _files
        elif [[ \$directive -eq 8 ]]; then
            _directories
        fi
    }

    compdef _$(func-name) "$program-name\""""

/**
Returns a fish completion script for the given $program-path.
*/
fish-completion-script_ --program-path/string -> string:
  program-name := basename_ program-path
  func-name := sanitize-func-name_ program-name
  return """
    function __$(func-name)_completions
        set -l tokens (commandline -opc)
        set -l current (commandline -ct)

        set -l output ("$program-path" __complete -- \$tokens[2..] \$current 2>/dev/null)
        if test \$status -ne 0
            return
        end

        set -l directive (string replace -r '^:(.*)' '\$1' \$output[-1])
        set -e output[-1]

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
            __fish_complete_path (commandline -ct)
        else if test "\$directive" = "8"
            __fish_complete_directories
        end
    end

    complete -c "$program-name" -f -a '(__$(func-name)_completions)'"""

/**
Returns a PowerShell completion script for the given $program-path.
*/
powershell-completion-script_ --program-path/string -> string:
  program-name := basename_ program-path
  return """
    Register-ArgumentCompleter -Native -CommandName '$program-name' -ScriptBlock {
        param(\$wordToComplete, \$commandAst, \$cursorPosition)

        \$tokens = \$commandAst.ToString() -split '\\s+'
        \$args = \$tokens[1..(\$tokens.Length - 1)]

        \$output = & $program-path __complete -- @args 2>\$null
        if (\$LASTEXITCODE -ne 0) { return }

        \$lines = \$output -split '\\n'
        \$directive = (\$lines[-1] -replace '^:', '')
        \$lines = \$lines[0..(\$lines.Length - 2)]

        foreach (\$line in \$lines) {
            if (-not \$line) { continue }
            if (\$line -match '^([^\\t]+)\\t(.+)\$') {
                \$value = \$Matches[1]
                \$desc = \$Matches[2]
            } else {
                \$value = \$line
                \$desc = \$line
            }
            [System.Management.Automation.CompletionResult]::new(
                \$value,
                \$value,
                'ParameterValue',
                \$desc
            )
        }

        if (\$directive -eq '4' -or \$directive -eq '8') {
            \$completionType = if (\$directive -eq '8') { 'ProviderContainer' } else { 'ProviderItem' }
            Get-ChildItem -Path "\$wordToComplete*" -ErrorAction SilentlyContinue |
                Where-Object { \$directive -ne '8' -or \$_.PSIsContainer } |
                ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new(
                        \$_.FullName,
                        \$_.Name,
                        \$completionType,
                        \$_.FullName
                    )
                }
        }
    }"""
