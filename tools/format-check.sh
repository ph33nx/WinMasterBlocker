#!/usr/bin/env bash
# Format check for batch scripts: CRLF endings, no trailing whitespace,
# trailing newline, no tabs.
#
# Usage: tools/format-check.sh <file.bat> [<file.bat> ...]

set -u

fail=0

err() {
    printf '\033[31m[format] %s: %s\033[0m\n' "$1" "$2" >&2
    fail=1
}

ok() {
    printf '[format] %s: %s\n' "$1" "$2"
}

for f in "$@"; do
    [[ "$f" == *.bat ]] || continue
    [[ -f "$f" ]] || continue

    # CRLF check. We fail if any line is missing the trailing \r.
    if grep -Uq $'[^\r]$' "$f"; then
        err "$f" "lines missing CRLF endings (run: perl -pi -e 's/\\\\r?\\\\n/\\\\r\\\\n/g' $f)"
    fi

    # Trailing whitespace before \r.
    if grep -nE $'[ \t]+\r?$' "$f" >/dev/null; then
        err "$f" "trailing whitespace on one or more lines"
    fi

    # Tab characters anywhere.
    if grep -nP '\t' "$f" >/dev/null; then
        err "$f" "tab characters present (use spaces)"
    fi

    # Final newline.
    if [[ -n "$(tail -c 1 "$f")" ]]; then
        err "$f" "no final newline"
    fi

    [[ "$fail" -eq 0 ]] && ok "$f" "ok"
done

exit "$fail"
