#!/usr/bin/env bash
# Coverage audit: asserts that WinMasterBlocker.bat still covers the
# executables and paths we promise to cover. This is the regression
# guard against issues like #6 (AcroCEF leaking) being reintroduced by
# a future refactor.
#
# Add new entries to REQUIRED_EXES / REQUIRED_PATHS as new vendor or
# CEF children are discovered.

set -u

SCRIPT="${1:-WinMasterBlocker.bat}"
fail=0

err() {
    printf '\033[31m[audit] %s\033[0m\n' "$1" >&2
    fail=1
}

ok() {
    printf '[audit] ok: %s\n' "$1"
}

if [[ ! -f "$SCRIPT" ]]; then
    err "missing $SCRIPT"
    exit 1
fi

# Adobe known-CEF coverage. These executables are explicitly named by the
# Adobe non-default-path sweep in WinMasterBlocker.bat. Regressing this
# list silently re-opens issue #6 (AcroCEF reaching the internet on
# custom installs), so we assert by literal substring match.
REQUIRED_ADOBE_EXES=(
    "acrocef.exe"
    "RdrCEF.exe"
    "Acrobat.exe"
    "AcroRd32.exe"
    "AdobeNotificationClient.exe"
    "AdobeIPCBroker.exe"
    "AGSService.exe"
    "AdobeUpdateService.exe"
    "Creative Cloud.exe"
)

for exe in "${REQUIRED_ADOBE_EXES[@]}"; do
    if grep -qF "$exe" "$SCRIPT"; then
        ok "Adobe known-exe present: $exe"
    else
        err "Adobe known-exe missing from script: $exe"
    fi
done

# Path coverage. These environment variables must appear in the Adobe
# paths string so non-C: and AppData installs are walked. The recursive
# *.exe walk under these paths is what catches the long tail of phone-home
# binaries; the .github/workflows/ci.yml integration job verifies the
# actual blocking behaviour with staged fake binaries.
REQUIRED_PATH_VARS=(
    '%ProgramFiles%'
    '%ProgramFiles(x86)%'
    '%CommonProgramFiles%'
    '%LOCALAPPDATA%'
    '%APPDATA%'
    '%ProgramData%'
)

for v in "${REQUIRED_PATH_VARS[@]}"; do
    if grep -qF "$v" "$SCRIPT"; then
        ok "path var present: $v"
    else
        err "path var missing from script: $v"
    fi
done

# Behavioural affordances required by the test harness and by senior
# admin operating mode.
REQUIRED_TOKENS=(
    "WHATIF"
    "WMB_LOG"
    "SPDX-License-Identifier"
    "WMB_VERSION"
)

for tok in "${REQUIRED_TOKENS[@]}"; do
    if grep -qF "$tok" "$SCRIPT"; then
        ok "token present: $tok"
    else
        err "token missing from script: $tok"
    fi
done

exit "$fail"
