# Install Scheduler for Pharmacy Inventory Sync
# This script creates a Windows Scheduled Task to run the sync script automatically.

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ConfigFile = Join-Path $PSScriptRoot "config.json"
$SyncScript = Join-Path $PSScriptRoot "SyncInventory.ps1"

if (-not (Test-Path $ConfigFile)) {
    Write-Error "Configuration file not found: $ConfigFile"
    Read-Host "Press Enter To Exit"
    exit 1
}

$Config = Get-Content $ConfigFile | ConvertFrom-Json
$Interval = $Config.syncIntervalMinutes

if (-not $Interval) {
    $Interval = 120 # Default to 120 minutes if not specified
}

$TaskName = "PharmacyInventorySync"
$TaskCommand = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$SyncScript`""

Write-Host "Creating Scheduled Task: $TaskName"
Write-Host "Interval: Every $Interval minutes"
Write-Host "Command: $TaskCommand"

# Use schtasks.exe for compatibility with Windows 7, 10, and 11
$SchtasksArgs = @(
    "/Create",
    "/TN", $TaskName,
    "/TR", $TaskCommand,
    "/SC", "MINUTE",
    "/MO", $Interval,
    "/RU", "SYSTEM",
    "/F"
)

try {
    & schtasks.exe $SchtasksArgs
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nScheduled Task created successfully!" -ForegroundColor Green
        Write-Host "The sync will run automatically every $Interval minutes."
    } else {
        Write-Host "`nFailed to create Scheduled Task. Ensure you are running as Administrator." -ForegroundColor Red
    }
} catch {
    Write-Host "`nAn error occurred: $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host "`nPress Enter To Exit"
