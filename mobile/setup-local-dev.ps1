# Writes dart_defines.local.json (PC Wi-Fi IP + Google client id).
param([switch]$Quiet)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$wifiIp = (
  Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object {
    $_.IPAddress -like "192.168.*" -and
    $_.IPAddress -notlike "192.168.56.*"
  } |
  Select-Object -First 1
).IPAddress

if (-not $wifiIp) {
  Write-Host "No 192.168.x Wi-Fi IP found. Turn on Wi-Fi." -ForegroundColor Red
  exit 1
}

$apiUrl = "http://${wifiIp}:8080"
$googleId = "104018292313-uashnbjvbkcf469ga6itvm4dltmfov5q.apps.googleusercontent.com"

@{
  API_BASE_URL = $apiUrl
  GOOGLE_SERVER_CLIENT_ID = $googleId
} | ConvertTo-Json | Set-Content -Path "dart_defines.local.json" -Encoding utf8

if (-not $Quiet) {
  Write-Host "Wrote dart_defines.local.json -> $apiUrl" -ForegroundColor Green
  Write-Host "Then run: .\dev.ps1" -ForegroundColor Cyan
} else {
  Write-Host "API URL: $apiUrl" -ForegroundColor Cyan
}
