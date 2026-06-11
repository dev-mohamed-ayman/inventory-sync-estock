@echo off
:: This batch file runs the SyncInventory.ps1 script as Administrator with Bypass Execution Policy.
:: Improved to handle paths with spaces and ensure window stays open.

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_PATH=%SCRIPT_DIR%SyncInventory.ps1"

echo ==================================================
echo   Pharmacy Inventory Sync - Admin Runner
echo ==================================================
echo.

:: Check for Administrator privileges
echo Checking for Administrator privileges...
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Running with Administrator privileges.
    echo.
    
    if not exist "%SCRIPT_PATH%" (
        echo [ERROR] PowerShell script not found at:
        echo "%SCRIPT_PATH%"
        echo.
        goto :END
    )

    echo Executing PowerShell script...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"
    
    echo.
    echo --------------------------------------------------
    echo Execution Finished.
    goto :END
) else (
    echo [INFO] Administrator privileges NOT detected.
    echo Attempting to restart with Administrator privileges...
    echo.
    
    :: Use PowerShell to restart this batch file as Admin
    :: The double quotes and backticks are to handle spaces in the path
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    
    if %errorLevel% neq 0 (
        echo [ERROR] Failed to request Administrator privileges.
        echo Please right-click this file and select 'Run as Administrator'.
    ) else (
        echo [OK] Elevation request sent. You can close this window if it doesn't close automatically.
    )
)

:END
echo.
echo Press any key to exit...
pause >nul
