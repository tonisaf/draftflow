[CmdletBinding()]
param(
    [ValidateSet("Release", "Debug")]
    [string]$Mode = "Release",
    [string]$Config = "config/supabase.json"
)
$ErrorActionPreference = "Stop"

Write-Host "===> Building Windows $Mode Binary..." -ForegroundColor Cyan

$defineArg = @()
if (Test-Path $Config) {
    Write-Host "Embedding configuration: $Config" -ForegroundColor Green
    $defineArg = @("--dart-define-from-file=$Config")
} else {
    Write-Warning "No config specified. Building with default guest configuration."
}

$modeFlag = if ($Mode -eq "Debug") { "--debug" } else { "--release" }
flutter build windows $modeFlag @defineArg

$outDir = "build\windows\x64\runner\$Mode"
if (Test-Path "$outDir\notes_here.exe") {
    Write-Host "Build Successful! Executable: $outDir\notes_here.exe" -ForegroundColor Green
} else {
    Write-Error "Build failed: output executable not found."
}
