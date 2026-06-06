# Local dev — one command. Start API first: go run -buildvcs=false .\cmd\api
param([string]$DeviceId = "")

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Find-Flutter {
  $cmd = Get-Command flutter -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  foreach ($root in @($env:FLUTTER_ROOT, "$env:USERPROFILE\flutter", "$env:LOCALAPPDATA\flutter", "C:\flutter", "$env:USERPROFILE\fvm\default")) {
    if (-not $root) { continue }
    $bat = Join-Path $root "bin\flutter.bat"
    if (Test-Path $bat) { return $bat }
  }
  return $null
}

function Find-Adb {
  foreach ($root in @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, "$env:LOCALAPPDATA\Android\Sdk", "$env:USERPROFILE\AppData\Local\Android\Sdk")) {
    if (-not $root) { continue }
    $adb = Join-Path $root "platform-tools\adb.exe"
    if (Test-Path $adb) { return $adb }
  }
  return $null
}

# 1. Config file
& "$PSScriptRoot\setup-local-dev.ps1" -Quiet

# 2. API up?
try {
  Invoke-WebRequest -Uri "http://127.0.0.1:8080/health" -UseBasicParsing -TimeoutSec 3 | Out-Null
} catch {
  Write-Host "Start the API first (repo root):" -ForegroundColor Red
  Write-Host "  go run -buildvcs=false .\cmd\api" -ForegroundColor Yellow
  exit 1
}

# 3. Flutter
$flutter = Find-Flutter
if (-not $flutter) {
  Write-Host "flutter not found in PATH." -ForegroundColor Red
  Write-Host "Run this from Android Studio Terminal, or add Flutter bin to PATH." -ForegroundColor Yellow
  exit 1
}

# 4. Phone
$adb = Find-Adb
if ($adb -and -not $DeviceId) {
  $lines = & $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match "\tdevice$" }
  if ($lines.Count -gt 0) {
    $DeviceId = ($lines[0] -split "\t")[0].Trim()
    Write-Host "Phone: $DeviceId" -ForegroundColor Cyan
  }
}

if (-not $DeviceId) {
  Write-Host "No phone detected. Plug in USB + enable USB debugging." -ForegroundColor Red
  Write-Host "Or: .\dev.ps1 -DeviceId YOUR_DEVICE_ID" -ForegroundColor Yellow
  exit 1
}

$apiUrl = (Get-Content "dart_defines.local.json" -Raw | ConvertFrom-Json).API_BASE_URL
Write-Host "Launching app -> $apiUrl" -ForegroundColor Green

$flutterArgs = @(
  "run",
  "-d", $DeviceId,
  "--dart-define-from-file=dart_defines.local.json"
)

& $flutter @flutterArgs
