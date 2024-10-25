:: ################################################################
:: ##                  🔥 WinMasterBlocker 🔥                     #
:: ################################################################
:: # Author: https://github.com/ph33nx                            #
:: # Repo: https://github.com/ph33nx/WinMasterBlocker             #
:: #                                                              #
:: # This script blocks inbound/outbound network access           #
:: # for major apps like Adobe, Autodesk, Corel, Maxon,           #
:: # and more using Windows Firewall.                             #
:: #                                                              #
:: # Features:                                                    #
:: # - Block executables using windows firewall for popular       # 
:: #   vendors                                                    #
:: # - Add or Delete inbound, outbound, or both types of rules    #
:: # - Avoids duplicate firewall rules                            #
:: # - Logs skipped entries for existing rules                    #
:: #                                                              #
:: # Check out the repo to contribute:                            #
:: # https://github.com/ph33nx/WinMasterBlocker                   #
:: ################################################################

@echo off
setlocal enabledelayedexpansion

:: Array of vendors and their paths
set "vendors[0]=Adobe"
set "paths[0]=C:\Program Files\Adobe;C:\Program Files\Common Files\Adobe;C:\Program Files (x86)\Adobe;C:\Program Files (x86)\Common Files\Adobe;C:\ProgramData\Adobe"

set "vendors[1]=Corel"
set "paths[1]=C:\Program Files\Corel;C:\Program Files\Common Files\Corel;C:\Program Files (x86)\Corel"

set "vendors[2]=Autodesk"
set "paths[2]=C:\Program Files\Autodesk;C:\Program Files (x86)\Common Files\Macrovision Shared;C:\Program Files (x86)\Common Files\Autodesk Shared"

set "vendors[3]=Maxon"
set "paths[3]=C:\Program Files\Maxon;C:\Program Files (x86)\Maxon;C:\ProgramData\Maxon"

set "vendors[4]=Red Giant"
set "paths[4]=C:\Program Files\Red Giant;C:\Program Files (x86)\Red Giant"

:: Check if script is run as administrator
:check_admin
    net session >nul 2>&1
    if %errorlevel% neq 0 (
        echo.
        echo This script must be run as Administrator.
        echo Attempting to re-launch with elevated privileges...
        powershell -Command "Start-Process '%~f0' -Verb RunAs"
        exit /b
    )

:: If admin, proceed with script
echo Running with Administrator privileges...
goto menu

:: Main menu for user selection
:menu
cls
echo Choose a vendor to block or delete rules:
echo.

:: Iterate through defined vendors
set i=0
:vendor_loop
if not defined vendors[%i%] goto after_vendor_list
echo !i!: !vendors[%i%]!
set /a i+=1
goto vendor_loop

:after_vendor_list
echo 99: Delete all firewall rules (added by this script)
echo.

set /p "choice=Enter your choice (0-99): "

:: Validate if choice is a number between 0 and 99
set /a test_choice=%choice% 2>nul
if "%choice%" neq "%test_choice%" (
    echo Invalid input, please enter a valid number.
    pause
    goto menu
)

:: Dynamic input validation based on the number of vendors
set max_choice=!i!
if "%choice%"=="00" (
    goto end
) else if "%choice%"=="99" (
    goto delete_menu
) else if %choice% lss %max_choice% (
    goto process_vendor
) else (
    echo Invalid choice, try again.
    pause
    goto menu
)

:: Menu for deleting rules (inbound, outbound, both)
:delete_menu
cls
echo Select which firewall rules to DELETE (added by this script):
echo 1: Delete Outbound rules
echo 2: Delete Inbound rules
echo 3: Delete All
echo.

set /p "delete_choice=Enter your choice (1-3): "
if "%delete_choice%"=="1" (
    goto delete_outbound
) else if "%delete_choice%"=="2" (
    goto delete_inbound
) else if "%delete_choice%"=="3" (
    goto delete_both
) else (
    echo Invalid choice, try again.
    pause
    goto delete_menu
)

:: Delete Outbound rules
:delete_outbound
cls
echo Deleting all outbound firewall rules (added by this script)...
for /f "tokens=*" %%r in ('powershell -command "(Get-NetFirewallRule | where {$_.DisplayName -like '*-block'}).DisplayName"') do (
    for %%D in (out) do (
        netsh advfirewall firewall delete rule name="%%r" dir=%%D
    )
)
echo Outbound rules deleted successfully.
goto firewall_check

:: Delete Inbound rules
:delete_inbound
cls
echo Deleting all inbound firewall rules (added by this script)...
for /f "tokens=*" %%r in ('powershell -command "(Get-NetFirewallRule | where {$_.DisplayName -like '*-block'}).DisplayName"') do (
    for %%D in (in) do (
        netsh advfirewall firewall delete rule name="%%r" dir=%%D
    )
)
echo Inbound rules deleted successfully.
goto firewall_check

:: Delete Both Inbound and Outbound rules
:delete_both
cls
echo Deleting all inbound and outbound firewall rules (added by this script)...
for /f "tokens=*" %%r in ('powershell -command "(Get-NetFirewallRule | where {$_.DisplayName -like '*-block'}).DisplayName"') do (
    for %%D in (in out) do (
        netsh advfirewall firewall delete rule name="%%r" dir=%%D
    )
)
echo Inbound and Outbound rules deleted successfully.
goto firewall_check

:: Process each vendor's paths and block executables
:process_vendor
cls
set "selected_vendor=!vendors[%choice%]!"
set "selected_paths=!paths[%choice%]!"

:: Initialize rule counter and a flag to track if any valid path was found
set "rule_count=0"
set "any_valid_path=false"

echo Blocking executables for %selected_vendor% with paths %selected_paths%...

:: Loop through each path and perform a deep nested search for executables
for %%P in ("%selected_paths:;=" "%") do (
    set "current_path=%%~P"
    echo Checking path: "!current_path!"

    if exist "!current_path!" (
        set "any_valid_path=true"
        echo Path exists: "!current_path!" - Searching for executables...

        set "exe_found_in_path=false"

        :: Use pushd/popd to make current_path the root of the recursive search
        pushd "!current_path!"
        for /R %%F in (*.exe) do (
            set "current_exe=%%F"
            set "exe_found_in_path=true"
            echo Found executable: "!current_exe!"
            call :check_and_block "!current_exe!" "!selected_vendor!"
        )
        popd

        :: Check if any executables were found in the current path
        if "!exe_found_in_path!"=="false" (
            echo No executables found in path: "!current_path!"
        )
        
    ) else (
        echo Path not found: "!current_path!"
    )
)

:: Final check after loop - notify if no valid directories were found
if "!any_valid_path!"=="false" (
    echo No valid directories found for %selected_vendor%.
) else if %rule_count%==0 (
    echo No executable files found to block for %selected_vendor%.
)

echo.
echo Completed blocking for %selected_vendor%.
echo Total rules added: %rule_count%
pause
goto menu


:: Function to check if a rule exists, and add it if not
:check_and_block
set "exe_path=%~1"
set "vendor_name=%~2"
set "rule_name=%~n1 %vendor_name%-block"

echo Checking rule for: "%exe_path%"

:: Check if the rule already exists
for /f "tokens=*" %%r in ('powershell -command "(Get-NetFirewallRule | where {$_.DisplayName -eq '%rule_name%'}).DisplayName"') do (
    if "%%r"=="%rule_name%" (
        echo Rule for "%exe_path%" already exists, skipping...
        goto :continue
    )
)

:: Add rule if it doesn’t exist
echo Blocking: "%~n1"
netsh advfirewall firewall add rule name="%rule_name%" dir=out program="%exe_path%" action=block
netsh advfirewall firewall add rule name="%rule_name%" dir=in program="%exe_path%" action=block

:: Increment rule count for each rule added
set /a rule_count+=1

:continue
goto :eof

:: Notify user to check Windows Firewall with Advanced Security
:firewall_check
echo.
echo All changes completed. You can verify the new rules in "Windows Firewall with Advanced Security"
echo.
pause
goto menu

:end
endlocal
exit /b
