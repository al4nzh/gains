# Run app against production API (no local server needed).
# Usage: .\run-prod.ps1
#        .\run-prod.ps1 -DeviceId 9b689cee

param(
  [string]$DeviceId = "",
  [string]$GoogleClientId = "104018292313-uashnbjvbkcf469ga6itvm4dltmfov5q.apps.googleusercontent.com"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$apiUrl = "https://api.gainsai.net"
Write-Host "flutter run -> $apiUrl" -ForegroundColor Green

$args = @(
  "run",
  "--dart-define=API_BASE_URL=$apiUrl",
  "--dart-define=GOOGLE_SERVER_CLIENT_ID=$GoogleClientId"
)
if ($DeviceId) { $args += @("-d", $DeviceId) }

& flutter @args
