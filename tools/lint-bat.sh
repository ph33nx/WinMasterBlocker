#!/usr/bin/env bash
# Lightweight linter for batch scripts. Catches the patterns that have
# historically broken WinMasterBlocker: missing admin guard, label drift,
# unbalanced setlocal/endlocal, BOM, unquoted netsh paths.
#
# Usage: tools/lint-bat.sh <file.bat> [<file.bat> ...]

set -u

fail=0

err() {
    printf '\033[31m[lint] %s: %s\033[0m\n' "$1" "$2" >&2
    fail=1
}

ok() {
    printf '[lint] %s: %s\n' "$1" "$2"
}

for f in "$@"; do
    [[ "$f" == *.bat ]] || continue
    [[ -f "$f" ]] || continue

    # 1. UTF-8 BOM at start of file. cmd.exe will print it as "´╗┐" on the
    #    first echoed line and breaks @echo off.
    if head -c 3 "$f" | xxd -p | grep -q '^efbbbf'; then
        err "$f" "UTF-8 BOM detected at start of file"
    fi

    content=$(cat "$f")

    # 2. @echo off must appear within the first 30 lines.
    if ! head -n 30 "$f" | grep -qiE '^[[:space:]]*@echo[[:space:]]+off'; then
        err "$f" "missing @echo off in first 30 lines"
    fi

    # 3. Admin elevation block. We require either net session check or
    #    a Start-Process RunAs invocation.
    if ! grep -qiE 'net session|Start-Process .*RunAs' "$f"; then
        err "$f" "missing admin elevation guard (net session or Start-Process RunAs)"
    fi

    # 4. setlocal / endlocal balance.
    setlocals=$(grep -ciE '^[[:space:]]*setlocal\b' "$f" || true)
    endlocals=$(grep -ciE '^[[:space:]]*endlocal\b' "$f" || true)
    if [[ "$setlocals" -gt 0 && "$endlocals" -lt 1 ]]; then
        err "$f" "setlocal without endlocal (setlocal=$setlocals endlocal=$endlocals)"
    fi

    # 5. Label drift: every :label (excluding :: comments, :eof / :EOF, and
    #    fall-through labels above the first goto/call) must be referenced
    #    by a goto or call somewhere in the file.
    first_jump=$(grep -niE '^[[:space:]]*(goto|call)[[:space:]]+' "$f" \
        | head -1 | cut -d: -f1)
    [[ -z "$first_jump" ]] && first_jump=0

    labels_with_lines=$(grep -nE '^[[:space:]]*:[a-zA-Z_][a-zA-Z0-9_]*' "$f" \
        | tr -d '\r' || true)

    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        line_no=$(printf '%s\n' "$entry" | cut -d: -f1)
        rest=$(printf '%s\n' "$entry" | cut -d: -f2-)
        label=$(printf '%s' "$rest" | sed -E 's/^[[:space:]]*://' | awk '{print $1}')
        case "$label" in
            ""|eof|EOF|continue) continue ;;
        esac
        # Fall-through entries above the first goto/call are exempt.
        if [[ "$line_no" -lt "$first_jump" ]]; then
            continue
        fi
        if ! grep -qiE "(^|[[:space:]])(goto|call)[[:space:]]+:?${label}([[:space:]]|$)" "$f"; then
            err "$f" "orphaned label :$label (no goto / call references)"
        fi
    done <<< "$labels_with_lines"

    # 6. netsh add rule without quoted program= path. netsh silently
    #    misparses paths with spaces and creates a rule against the wrong
    #    binary, which then never fires.
    if grep -nE 'netsh advfirewall firewall add rule' "$f" \
        | grep -vE 'program="[^"]*"' \
        | grep -E 'program=' >/dev/null; then
        err "$f" "netsh add rule with unquoted program= argument"
    fi

    # 7. SPDX license identifier required.
    if ! grep -q 'SPDX-License-Identifier:' "$f"; then
        err "$f" "missing SPDX-License-Identifier header"
    fi

    [[ "$fail" -eq 0 ]] && ok "$f" "ok"
done

exit "$fail"
