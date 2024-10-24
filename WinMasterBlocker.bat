@echo off
:: #########################################################
:: ##              🔥 WinMasterBlocker 🔥                 ##
:: #########################################################
:: # Author: https://github.com/ph33nx                     #
:: # Repo: https://github.com/ph33nx/WinMasterBlocker      #
:: #                                                       #
:: # This script blocks inbound/outbound network access    #
:: # for major apps like Adobe, Autodesk, Corel, FL Studio,#
:: # and more using Windows Firewall.                      #
:: #                                                       #
:: # Features:                                             #
:: # - Block rules for popular providers                   #
:: # - Delete inbound, outbound, or both types of rules    #
:: # - Avoids duplicate firewall rules                     #
:: # - Logs skipped entries for existing rules             #
:: #                                                       #
:: # Check out the repo to contribute:                     #
:: # https://github.com/ph33nx/WinMasterBlocker            #
:: ########################################################

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
echo.

setlocal enabledelayedexpansion

:: Color definitions (for cmd window)
set "COLOR_GREEN=0a"
set "COLOR_RED=0c"
set "COLOR_YELLOW=0e"
set "COLOR_RESET=07"

:: Array of providers and their paths
set "providers[0]=Adobe"
set "paths[0]=C:\Program Files\Adobe C:\Program Files\Common Files\Adobe C:\Program Files (x86)\Adobe C:\Program Files (x86)\Common Files\Adobe C:\ProgramData\Adobe"

set "providers[1]=Corel"
set "paths[1]=C:\Program Files\Corel C:\Program Files\Common Files\Corel C:\Program Files (x86)\Corel"

set "providers[2]=Autodesk"
set "paths[2]=C:\Program Files\Autodesk C:\Program Files (x86)\Common Files\Macrovision Shared C:\Program Files (x86)\Common Files\Autodesk Shared"

set "providers[9]=Image-Line (FL Studio)"
set "paths[9]=C:\Program Files\Image-Line C:\Program Files (x86)\Image-Line C:\ProgramData\Image-Line C:\Users\%USERNAME%\Documents\Image-Line"

set "providers[6]=Maxon"
set "paths[6]=C:\Program Files\Maxon C:\Program Files (x86)\Maxon C:\ProgramData\Maxon"

set "providers[7]=Red Giant"
set "paths[7]=C:\Program Files\Red Giant C:\Program Files (x86)\Red Giant"

set "providers[8]=Dassault Systems (SolidWorks)"
set "paths[8]=C:\Program Files\SolidWorks C:\Program Files\Dassault Systemes C:\Program Files (x86)\SolidWorks C:\Program Files (x86)\Dassault Systemes"

:: Function to set the console color
:color
    echo|set /p=" " > nul
    for /f %%i in ('"prompt $H & echo on & for %%N in (1) do rem"') do (
        call set "ascii=%%i"
    )
    <nul set /p"= %ascii%"
    color %1
    goto :eof

:: Main menu for user selection
:menu
cls
echo Choose a provider to block or delete rules:
echo.
for /L %%i in (0,1,9999) do (
    if defined providers[%%i] (
        echo %%i: !providers[%%i]!
    ) else (
        goto after_provider_list
    )
)

:after_provider_list
echo 99: Delete all rules (added by this script)
echo 0: Exit
echo.

set /p "choice=Enter your choice (0-99): "

:: Validate the user's choice
if "%choice%"=="0" (
    goto end
) else if "%choice%"=="99" (
    goto delete_menu
) else if "%choice%" geq "0" if "%choice%" leq "2" (
    goto process_provider
) else (
    echo Invalid choice, try again.
    pause
    goto menu
)

:: Menu for deleting rules (inbound, outbound, both)
:delete_menu
cls
echo Select which rules to delete:
echo 1: Delete Outbound rules (added by this script)
echo 2: Delete Inbound rules (added by this script)
echo 3: Delete both Inbound and Outbound rules (added by this script)
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
call :color %COLOR_RED%
echo Deleting all outbound firewall rules (added by this script)...
for /f "tokens=*" %%r in ('powershell -command "(Get-NetFirewallRule | where {$_.DisplayName -like '*-block'}).DisplayName"') do (
    for %%D in (out) do (
        netsh advfirewall firewall delete rule name="%%r" dir=%%D
    )
)
call :color %COLOR_GREEN%
echo Outbound rules deleted successfully.
goto firewall_check

:: Delete Inbound rules
:delete_inbound
cls
call :color %COLOR_RED%
echo Deleting all inbound firewall rules (added by this script)...
for /f "tokens=*" %%r in ('powershell -command "(Get-NetFirewallRule | where {$_.DisplayName -like '*-block'}).DisplayName"') do (
    for %%D in (in) do (
        netsh advfirewall firewall delete rule name="%%r" dir=%%D
    )
)
call :color %COLOR_GREEN%
echo Inbound rules deleted successfully.
goto firewall_check

:: Delete Both Inbound and Outbound rules
:delete_both
cls
call :color %COLOR_RED%
echo Deleting all inbound and outbound firewall rules (added by this script)...
for /f "tokens=*" %%r in ('powershell -command "(Get-NetFirewallRule | where {$_.DisplayName -like '*-block'}).DisplayName"') do (
    for %%D in (in out) do (
        netsh advfirewall firewall delete rule name="%%r" dir=%%D
    )
)
call :color %COLOR_GREEN%
echo Inbound and Outbound rules deleted successfully.
goto firewall_check

:: Process each provider's paths and block executables
:process_provider
cls
set "selected_provider=!providers[%choice%]!"
set "selected_paths=!paths[%choice%]!"

call :color %COLOR_YELLOW%
echo Blocking executables for %selected_provider%...
call :color %COLOR_RESET%

for %%P in (%selected_paths%) do (
    if exist "%%P" (
        for /R "%%P" %%X in (*.exe) do (
            call :check_and_block "%%X" "%selected_provider%"
        )
    ) else (
        call :color %COLOR_RED%
        echo Path not found: %%P
        call :color %COLOR_RESET%
    )
)
echo Blocking completed for %selected_provider%.
pause
goto menu

:: Function to check if a rule exists, and add it if not
:check_and_block
set "exe_path=%~1"
set "provider_name=%~2"
set "rule_name=%~n1 %provider_name%-block"

for /f "tokens=*" %%r in ('powershell -command "(Get-NetFirewallRule | where {$_.DisplayName -eq '%rule_name%'}).DisplayName"') do (
    if "%%r"=="%rule_name%" (
        echo Rule for %exe_path% already exists, skipping...
        goto :continue
    )
)

echo Blocking: %~n1
netsh advfirewall firewall add rule name="%rule_name%" dir=out program="%exe_path%" action=block
netsh advfirewall firewall add rule name="%rule_name%" dir=in program="%exe_path%" action=block

:continue
goto :eof

:: Notify user to check Windows Firewall with Advanced Security
:firewall_check
call :color %COLOR_GREEN%
echo.
echo All changes completed. Please open "Windows Firewall with Advanced Security" to verify the rules.
echo.
call :color %COLOR_RESET%
pause
goto menu

:end
endlocal
exit /b
