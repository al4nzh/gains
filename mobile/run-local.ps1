# Local dev — 3 steps. No Wi-Fi. No firewall popup.
#
# 1. Phone: USB plugged in, USB debugging ON
# 2. Terminal A (repo root):  go run -buildvcs=false .\cmd\api
# 3. Terminal B (this folder): .\run-local.ps1
#
# App defaults to http://127.0.0.1:8080 in debug (after adb reverse).

param(
  [string]$DeviceId = "",
  [string]$GoogleClientId = "104018292313-uashnbjvbkcf469ga6itvm4dltmfov5q.apps.googleusercontent.com"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Find-Adb {
  foreach ($root in @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, "$env:LOCALAPPDATA\Android\Sdk", "$env:USERPROFILE\AppData\Local\Android\Sdk")) {
    if (-not $root) { continue }
    $adb = Join-Path $root "platform-tools\adb.exe"
    if (Test-Path $adb) { return $adb }
  }
  return $null
}

try {
  Invoke-WebRequest -Uri "http://127.0.0.1:8080/health" -UseBasicParsing -TimeoutSec 3 | Out-Null
} catch {
  Write-Host "API not running. In repo root run: go run -buildvcs=false .\cmd\api" -ForegroundColor Red
  exit 1
}

$adb = Find-Adb
if (-not $adb) {
  Write-Host "Run this from Android Studio Terminal (has adb)." -ForegroundColor Red
  exit 1
}

if (-not $DeviceId) {
  $lines = & $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match "\tdevice$" }
  if ($lines.Count -eq 0) {
    Write-Host "No phone on USB. Enable USB debugging + accept RSA prompt." -ForegroundColor Red
    exit 1
  }
  $DeviceId = ($lines[0] -split "\t")[0].Trim()
}

& $adb -s $DeviceId reverse tcp:8080 tcp:8080 | Out-Null
Write-Host "Device $DeviceId -> 127.0.0.1:8080 (USB tunnel)" -ForegroundColor Green
Write-Host "On login screen: tap USB preset, then Test /health. No --dart-define needed." -ForegroundColor Cyan

$args = @("run", "-d", $DeviceId, "--dart-define=GOOGLE_SERVER_CLIENT_ID=$GoogleClientId")
& flutter @args
