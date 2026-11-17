[CmdletBinding()]
param(
    [string]$Filter = ""
)
$ErrorActionPreference = "Stop"

Write-Host "===> Running Dart & Flutter Test Suite..." -ForegroundColor Cyan

$argsList = @("test", "--no-pub")
if ($Filter) {
    $argsList += @("--plain-name=$Filter")
}

flutter @argsList
