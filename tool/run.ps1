[CmdletBinding()]
param(
    [string]$Config = "config/supabase.json",
    [switch]$Release
)
$ErrorActionPreference = "Stop"

Write-Host "===> Starting notes_here on Windows..." -ForegroundColor Cyan

$defineArg = @()
if (Test-Path $Config) {
    Write-Host "Using configuration from: $Config" -ForegroundColor Green
    $defineArg = @("--dart-define-from-file=$Config")
} else {
    Write-Warning "Configuration '$Config' not found. Starting in Guest Offline Mode."
}

$modeArg = if ($Release) { "--release" } else { "--debug" }
flutter run -d windows $modeArg @defineArg
