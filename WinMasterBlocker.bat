:: ################################################################
:: ##                  WinMasterBlocker                           #
:: ################################################################
:: # Author:  https://github.com/ph33nx
:: # Repo:    https://github.com/ph33nx/WinMasterBlocker
:: # SPDX-License-Identifier: MIT
:: # Version: 2.0.0
:: #
:: # Blocks inbound and outbound network access for Adobe,
:: # Autodesk, Corel, Maxon, Red Giant and other vendors using
:: # the Windows Firewall command line. No third-party tools.
:: #
:: # Environment overrides (optional):
:: #   WHATIF=1                Log every netsh call instead of executing it.
:: #   WMB_VENDOR=adobe        Run unattended against a single vendor.
:: #   WMB_ACTION=block|delete Action for unattended mode (default: block).
:: #   WMB_QUIET=1             Suppress per-rule echo output.
:: # All overrides survive the UAC re-launch when double-clicking the script.
:: #
:: # Transcript log (always written):
:: #   %TEMP%\WinMasterBlocker-YYYYMMDDhhmmss.log
:: ################################################################

@echo off
setlocal enabledelayedexpansion

set "WMB_VERSION=2.0.0"

:: ---------------------------------------------------------------------------
:: UAC handoff restore. When :check_admin re-launches the script with
:: elevation, env vars set in the un-elevated shell (WHATIF, WMB_VENDOR,
:: WMB_TEST_ROOT, ...) do not cross the privilege boundary. The un-elevated
:: side persists them to a temp file matching wmb-uac-*.env and passes the
:: path as %1; we read it back here and delete the file. Validation guards
:: against an unrelated file path being consumed if a user passes %1 by
:: accident.
:: ---------------------------------------------------------------------------
set "_handoff=%~1"
if not defined _handoff goto wmb_after_uac_restore
echo !_handoff! | findstr /I /R "wmb-uac-.*\.env" >nul 2>&1
if errorlevel 1 goto wmb_after_uac_restore
if not exist "!_handoff!" goto wmb_after_uac_restore
for /f "usebackq tokens=1,* delims==" %%a in ("!_handoff!") do set "%%a=%%b"
del "!_handoff!" 2>nul
set "_handoff="
:wmb_after_uac_restore

:: ---------------------------------------------------------------------------
:: Test affordance. WMB_TEST_ROOT lets the integration test point the path
:: table at a fake install tree without requiring admin write to
:: C:\Program Files. Implemented with goto rather than an if-block because
:: cmd's pre-parser counts parens in if-block bodies, and "ProgramFiles(x86)"
:: contains literal parens that confuse the counter.
:: ---------------------------------------------------------------------------
if not defined WMB_TEST_ROOT goto wmb_after_test_root
set "ProgramFiles=%WMB_TEST_ROOT%\Program Files"
set "ProgramFiles(x86)=%WMB_TEST_ROOT%\Program Files (x86)"
set "CommonProgramFiles=%WMB_TEST_ROOT%\Common Files"
set "CommonProgramFiles(x86)=%WMB_TEST_ROOT%\Common Files (x86)"
set "ProgramData=%WMB_TEST_ROOT%\ProgramData"
set "LOCALAPPDATA=%WMB_TEST_ROOT%\AppData\Local"
set "APPDATA=%WMB_TEST_ROOT%\AppData\Roaming"
:wmb_after_test_root

:: ---------------------------------------------------------------------------
:: Vendor and path table. Paths use environment variables so non-C: installs,
:: x86 / x64 splits, ProgramData, and per-user AppData locations all resolve
:: at runtime. This is what catches Adobe AcroCEF on installs that did not
:: land under C:\Program Files\Adobe.
:: ---------------------------------------------------------------------------
set "vendors[0]=Adobe"
set "paths[0]=%ProgramFiles%\Adobe;%ProgramFiles(x86)%\Adobe;%CommonProgramFiles%\Adobe;%CommonProgramFiles(x86)%\Adobe;%ProgramData%\Adobe;%LOCALAPPDATA%\Adobe;%APPDATA%\Adobe"

set "vendors[1]=Corel"
set "paths[1]=%ProgramFiles%\Corel;%ProgramFiles(x86)%\Corel;%CommonProgramFiles%\Corel;%CommonProgramFiles(x86)%\Corel;%ProgramData%\Corel"

set "vendors[2]=Autodesk"
set "paths[2]=%ProgramFiles%\Autodesk;%ProgramFiles(x86)%\Autodesk;%CommonProgramFiles(x86)%\Autodesk Shared;%CommonProgramFiles(x86)%\Macrovision Shared;%ProgramData%\Autodesk"

set "vendors[3]=Maxon"
set "paths[3]=%ProgramFiles%\Maxon;%ProgramFiles(x86)%\Maxon;%ProgramData%\Maxon"

set "vendors[4]=Red Giant"
set "paths[4]=%ProgramFiles%\Red Giant;%ProgramFiles(x86)%\Red Giant;%ProgramData%\Red Giant"

:: ---------------------------------------------------------------------------
:: Transcript log. PowerShell gives us a locale-independent 14-char timestamp
:: that is safe to embed in a filename. wmic is removed in newer Windows 11
:: builds, so we do not rely on it.
:: ---------------------------------------------------------------------------
set "ts="
for /f "delims=" %%T in ('powershell -NoProfile -Command "[DateTime]::Now.ToString('yyyyMMddHHmmss')" 2^>nul') do set "ts=%%T"
if not defined ts set "ts=00000000000000"
set "WMB_LOG=%TEMP%\WinMasterBlocker-%ts%.log"
> "%WMB_LOG%" echo WinMasterBlocker v%WMB_VERSION% started %ts%
>>"%WMB_LOG%" echo WHATIF=%WHATIF% WMB_VENDOR=%WMB_VENDOR% WMB_ACTION=%WMB_ACTION% WMB_QUIET=%WMB_QUIET%

:: ---------------------------------------------------------------------------
:: Admin check.
:: ---------------------------------------------------------------------------
:check_admin
    net session >nul 2>&1
    if %errorlevel% neq 0 (
        echo.
        echo This script must be run as Administrator.
        echo Attempting to re-launch with elevated privileges...
        call :write_uac_handoff
        powershell -NoProfile -Command "Start-Process '%~f0' -ArgumentList '!_handoff_out!' -Verb RunAs"
        exit /b
    )

echo Running with Administrator privileges...
echo Transcript: %WMB_LOG%

:: ---------------------------------------------------------------------------
:: Bulk-cache existing firewall rules. One PowerShell call up front replaces
:: the per-executable Get-NetFirewallRule that used to dominate runtime on
:: large Adobe installs (5+ minutes -> seconds). The cache is plain text;
:: duplicate detection is a single findstr against it.
:: ---------------------------------------------------------------------------
set "WMB_RULES_CACHE=%TEMP%\WinMasterBlocker-rules-%ts%.txt"
echo Caching existing firewall rules...
>>"%WMB_LOG%" echo Caching existing firewall rules to %WMB_RULES_CACHE%
powershell -NoProfile -Command "(Get-NetFirewallRule -DisplayName '*-block' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DisplayName)" 2>nul > "%WMB_RULES_CACHE%"
if not exist "%WMB_RULES_CACHE%" type nul > "%WMB_RULES_CACHE%"
call :reload_rule_set

:: ---------------------------------------------------------------------------
:: Unattended mode for IT pros. Set WMB_VENDOR=adobe (case-insensitive) and
:: optionally WMB_ACTION=block|delete. Skips the menu entirely.
:: ---------------------------------------------------------------------------
if defined WMB_VENDOR (
    call :resolve_vendor "%WMB_VENDOR%"
    if not defined WMB_RESOLVED_INDEX (
        echo Unknown WMB_VENDOR: %WMB_VENDOR%
        >>"%WMB_LOG%" echo ERROR unknown vendor %WMB_VENDOR%
        endlocal
        exit /b 2
    )
    set "choice=!WMB_RESOLVED_INDEX!"
    if /i "%WMB_ACTION%"=="delete" (
        set "delete_choice=3"
        goto delete_both
    )
    goto process_vendor
)

goto menu

:: ---------------------------------------------------------------------------
:: Main menu.
:: ---------------------------------------------------------------------------
:menu
cls
echo WinMasterBlocker v%WMB_VERSION%
echo Transcript: %WMB_LOG%
if defined WHATIF echo *** WHATIF mode: no firewall changes will be made ***
echo.
echo Choose a vendor to block, or pick a maintenance action:
echo.

set i=0
:vendor_loop
if not defined vendors[%i%] goto after_vendor_list
echo  !i!: !vendors[%i%]!
set /a i+=1
goto vendor_loop

:after_vendor_list
echo.
echo 98: Update Adobe (re-scan after Adobe / Acrobat updates)
echo 99: Delete all firewall rules added by this script
echo 00: Exit
echo.

set /p "choice=Enter your choice: "

set /a test_choice=%choice% 2>nul
if "%choice%" neq "%test_choice%" (
    echo Invalid input, please enter a valid number.
    pause
    goto menu
)

set max_choice=!i!
if "%choice%"=="00" (
    goto end
) else if "%choice%"=="99" (
    goto delete_menu
) else if "%choice%"=="98" (
    set "choice=0"
    goto process_vendor
) else if %choice% lss %max_choice% (
    goto process_vendor
) else (
    echo Invalid choice, try again.
    pause
    goto menu
)

:: ---------------------------------------------------------------------------
:: Delete-rules menu.
:: ---------------------------------------------------------------------------
:delete_menu
cls
echo Select which firewall rules to DELETE (added by this script):
echo 1: Delete Outbound rules
echo 2: Delete Inbound rules
echo 3: Delete All
echo 0: Back
echo.

set /p "delete_choice=Enter your choice (0-3): "
if "%delete_choice%"=="1" (
    goto delete_outbound
) else if "%delete_choice%"=="2" (
    goto delete_inbound
) else if "%delete_choice%"=="3" (
    goto delete_both
) else if "%delete_choice%"=="0" (
    goto menu
) else (
    echo Invalid choice, try again.
    pause
    goto delete_menu
)

:delete_outbound
cls
echo Deleting outbound firewall rules added by this script...
call :delete_rules out
goto firewall_check

:delete_inbound
cls
echo Deleting inbound firewall rules added by this script...
call :delete_rules in
goto firewall_check

:delete_both
cls
echo Deleting all firewall rules added by this script...
call :delete_rules both
goto firewall_check

:: dir = "in" | "out" | "both". Reads names from the rule cache so we never
:: touch unrelated rules on the host. Refreshes the cache afterwards.
:delete_rules
set "dir_arg=%~1"
for /f "usebackq delims=" %%r in ("%WMB_RULES_CACHE%") do (
    if not "%%r"=="" (
        if /i "%dir_arg%"=="both" (
            call :run_netsh_delete "%%r" out
            call :run_netsh_delete "%%r" in
        ) else (
            call :run_netsh_delete "%%r" %dir_arg%
        )
    )
)
echo Refreshing rule cache...
powershell -NoProfile -Command "(Get-NetFirewallRule -DisplayName '*-block' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DisplayName)" 2>nul > "%WMB_RULES_CACHE%"
if not exist "%WMB_RULES_CACHE%" type nul > "%WMB_RULES_CACHE%"
call :reload_rule_set
goto :eof

:run_netsh_delete
if defined WHATIF (
    echo [WHATIF] netsh advfirewall firewall delete rule name="%~1" dir=%~2
    >>"%WMB_LOG%" echo [WHATIF] delete rule "%~1" dir=%~2
) else (
    netsh advfirewall firewall delete rule name="%~1" dir=%~2 >nul
    >>"%WMB_LOG%" echo deleted rule "%~1" dir=%~2
)
goto :eof

:: ---------------------------------------------------------------------------
:: Process vendor: walk every path, recursively, and block every .exe found.
:: ---------------------------------------------------------------------------
:process_vendor
cls
set "selected_vendor=!vendors[%choice%]!"
set "selected_paths=!paths[%choice%]!"

set "rule_count=0"
set "any_valid_path=false"

echo Blocking executables for %selected_vendor%
>>"%WMB_LOG%" echo BEGIN vendor=%selected_vendor%

for %%P in ("%selected_paths:;=" "%") do (
    set "current_path=%%~P"
    if exist "!current_path!" (
        set "any_valid_path=true"
        >>"%WMB_LOG%" echo path exists "!current_path!"
        if not defined WMB_QUIET echo Searching: "!current_path!"

        pushd "!current_path!"
        for /R %%F in (*.exe) do (
            call :check_and_block "%%F" "!selected_vendor!"
        )
        popd
    ) else (
        >>"%WMB_LOG%" echo path missing "!current_path!"
    )
)

:: Adobe known-process sweep on non-default install paths (alternative
:: drives, user profile). The recursive walk above covered %ProgramFiles%,
:: %LOCALAPPDATA%, etc. The bulk rule cache means rules already added by
:: the main walk are skipped here via !rule_set! membership.
if /i "%selected_vendor%"=="Adobe" call :adobe_known_sweep

if "!any_valid_path!"=="false" (
    echo No installation directories found for %selected_vendor%.
    >>"%WMB_LOG%" echo END vendor=%selected_vendor% rules=0 reason=no-paths
) else (
    echo.
    echo Completed: %selected_vendor%. Rules added: !rule_count!
    >>"%WMB_LOG%" echo END vendor=%selected_vendor% rules=!rule_count!
)

if defined WMB_VENDOR (
    endlocal
    exit /b 0
)

pause
goto menu

:: ---------------------------------------------------------------------------
:: Add inbound + outbound block rules for an executable, unless an identically
:: named rule already exists in the cache.
:: ---------------------------------------------------------------------------
:check_and_block
set "exe_path=%~1"
set "vendor_name=%~2"
set "rule_name=%~n1 %vendor_name%-block"

set "_probe=|%rule_name%|"
if not "!rule_set:%_probe%=!"=="!rule_set!" (
    if not defined WMB_QUIET echo Skip exists: "%~n1"
    >>"%WMB_LOG%" echo skip "%rule_name%"
    goto :eof
)

if not defined WMB_QUIET echo Block: "%~n1"
if defined WHATIF (
    echo [WHATIF] netsh advfirewall firewall add rule name="%rule_name%" dir=out program="%exe_path%" action=block
    echo [WHATIF] netsh advfirewall firewall add rule name="%rule_name%" dir=in  program="%exe_path%" action=block
    >>"%WMB_LOG%" echo [WHATIF] add "%rule_name%" out program="%exe_path%"
    >>"%WMB_LOG%" echo [WHATIF] add "%rule_name%" in  program="%exe_path%"
) else (
    netsh advfirewall firewall add rule name="%rule_name%" dir=out program="%exe_path%" action=block >nul
    netsh advfirewall firewall add rule name="%rule_name%" dir=in  program="%exe_path%" action=block >nul
    >>"%WMB_LOG%" echo add "%rule_name%" program="%exe_path%"
)

>>"%WMB_RULES_CACHE%" echo %rule_name%
set "rule_set=!rule_set!%rule_name%|"
set /a rule_count+=1
goto :eof

:: ---------------------------------------------------------------------------
:: Load WMB_RULES_CACHE into !rule_set! as |name1|name2|...| so per-exe
:: membership in :check_and_block is a substring substitution rather than
:: a per-exe findstr child process.
:: ---------------------------------------------------------------------------
:reload_rule_set
set "rule_set=|"
for /f "usebackq delims=" %%R in ("%WMB_RULES_CACHE%") do set "rule_set=!rule_set!%%R|"
goto :eof

:: ---------------------------------------------------------------------------
:: Adobe-specific belt-and-suspenders sweep. Walks roots the standard path
:: table cannot reach: every logical drive's \Adobe\ folder (custom installs
:: to D:\Adobe\ etc) and %USERPROFILE%\Adobe (some Creative Cloud components
:: drop here). For each root, looks only for the specific binaries that have
:: historically slipped past the recursive walk on non-default installs.
:: ---------------------------------------------------------------------------
:adobe_known_sweep
>>"%WMB_LOG%" echo BEGIN known-sweep vendor=Adobe
for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%D:\Adobe\" call :adobe_sweep_root "%%D:\Adobe"
)
if exist "%USERPROFILE%\Adobe\" call :adobe_sweep_root "%USERPROFILE%\Adobe"
>>"%WMB_LOG%" echo END known-sweep vendor=Adobe
goto :eof

:adobe_sweep_root
set "_root=%~1"
>>"%WMB_LOG%" echo known-sweep scanning "!_root!"
for %%E in ("acrocef.exe" "RdrCEF.exe" "Acrobat.exe" "AcroRd32.exe" "AdobeNotificationClient.exe" "AdobeIPCBroker.exe" "AGSService.exe" "AdobeUpdateService.exe" "Creative Cloud.exe") do (
    for /f "delims=" %%P in ('dir /b /s /a-d "!_root!\%%~E" 2^>nul') do (
        call :check_and_block "%%P" "Adobe"
    )
)
goto :eof

:: ---------------------------------------------------------------------------
:: Persist defined env vars to a temp file before UAC re-launch. The elevated
:: side reads the file via the wmb_after_uac_restore block at the top of the
:: script. Sets _handoff_out to the file path so the caller can pass it.
:: ---------------------------------------------------------------------------
:write_uac_handoff
set "_handoff_out=%TEMP%\wmb-uac-%RANDOM%-%RANDOM%.env"
> "!_handoff_out!" type nul
if defined WHATIF        >>"!_handoff_out!" echo WHATIF=!WHATIF!
if defined WMB_VENDOR    >>"!_handoff_out!" echo WMB_VENDOR=!WMB_VENDOR!
if defined WMB_ACTION    >>"!_handoff_out!" echo WMB_ACTION=!WMB_ACTION!
if defined WMB_QUIET     >>"!_handoff_out!" echo WMB_QUIET=!WMB_QUIET!
if defined WMB_TEST_ROOT >>"!_handoff_out!" echo WMB_TEST_ROOT=!WMB_TEST_ROOT!
goto :eof

:: ---------------------------------------------------------------------------
:: Resolve a vendor name (case-insensitive) to its index. Sets
:: WMB_RESOLVED_INDEX if found, otherwise leaves it undefined.
:: ---------------------------------------------------------------------------
:resolve_vendor
set "WMB_RESOLVED_INDEX="
set "v_query=%~1"
set j=0
:rv_loop
if not defined vendors[%j%] goto :eof
set "v_curr=!vendors[%j%]!"
if /i "!v_curr!"=="!v_query!" (
    set "WMB_RESOLVED_INDEX=%j%"
    goto :eof
)
set /a j+=1
goto rv_loop

:firewall_check
echo.
echo Done. Verify in "Windows Firewall with Advanced Security".
echo Transcript: %WMB_LOG%
echo.
if not defined WMB_VENDOR pause
if defined WMB_VENDOR (
    endlocal
    exit /b 0
)
goto menu

:end
>>"%WMB_LOG%" echo exit
endlocal
exit /b 0
