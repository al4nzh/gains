# USB tunnel to local API — bypasses Wi-Fi / firewall / router isolation.
# Phone must be plugged in with USB debugging on.
# Usage: .\run-android-usb.ps1
#        .\run-android-usb.ps1 -DeviceId 9b689cee

param(
  [string]$DeviceId = "",
  [string]$GoogleClientId = "104018292313-uashnbjvbkcf469ga6itvm4dltmfov5q.apps.googleusercontent.com"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$adb = $null
$candidates = @(
  "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
  "$env:USERPROFILE\AppData\Local\Android\Sdk\platform-tools\adb.exe"
)
foreach ($c in $candidates) {
  if (Test-Path $c) { $adb = $c; break }
}
if (-not $adb) {
  Write-Host "adb not found. Install Android SDK platform-tools or run from Android Studio terminal." -ForegroundColor Red
  exit 1
}

$adbArgs = @()
if ($DeviceId) { $adbArgs += @("-s", $DeviceId) }

Write-Host "USB reverse: phone localhost:8080 -> PC :8080" -ForegroundColor Cyan
& $adb @adbArgs reverse tcp:8080 tcp:8080
& $adb @adbArgs reverse --list

$apiUrl = "http://127.0.0.1:8080"
Write-Host "API URL: $apiUrl (via USB — not Wi-Fi)" -ForegroundColor Green

$flutterArgs = @(
  "run",
  "--dart-define=API_BASE_URL=$apiUrl",
  "--dart-define=GOOGLE_SERVER_CLIENT_ID=$GoogleClientId"
)
if ($DeviceId) { $flutterArgs += @("-d", $DeviceId) }

& flutter @flutterArgs
