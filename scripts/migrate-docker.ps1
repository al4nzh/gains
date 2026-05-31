# Run DB migrations without a local migrate.exe (avoids AV false positives on Windows).
# Requires Docker Desktop.
param(
    [Parameter(Position = 0)]
    [ValidateSet("up", "down", "version")]
    [string]$Command = "up"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$envFile = Join-Path $root ".env"
if (-not (Test-Path $envFile)) {
    Write-Error ".env not found at $envFile"
}

$dbUrl = $null
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*DATABASE_URL=(.+)$') {
        $dbUrl = $matches[1].Trim()
    }
}
if (-not $dbUrl) {
    Write-Error "DATABASE_URL not set in .env"
}

# Inside Docker, localhost is the container — reach host Postgres via host.docker.internal
$dbUrl = $dbUrl -replace '@localhost:', '@host.docker.internal:'
$dbUrl = $dbUrl -replace '@127\.0\.0\.1:', '@host.docker.internal:'

$migrations = Join-Path $root "migrations"
if ($Command -eq "version") {
    docker run --rm -v "${migrations}:/migrations" migrate/migrate `
        -path=/migrations -database $dbUrl version
} else {
    docker run --rm -v "${migrations}:/migrations" migrate/migrate `
        -path=/migrations -database $dbUrl $Command
}
