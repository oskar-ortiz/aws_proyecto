<#
.SYNOPSIS
  Builds the Next.js static export for /dashboard.

.DESCRIPTION
  Runs npm ci (or install) and next build in frontend/. Output: frontend/out/
  Sync that directory to EC2 at /opt/university/frontend/out (see docs/DASHBOARD_DEPLOY.md).
#>
param(
    [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$fe = Join-Path $root "frontend"

if (-not (Test-Path $fe)) {
    throw "frontend/ directory not found at $fe"
}

Push-Location $fe
try {
    if (-not $SkipInstall) {
        if (Test-Path "package-lock.json") {
            npm ci
        } else {
            npm install
        }
    }
    npm run build
    Write-Host ""
    Write-Host "Build OK. Static files: $fe\out" -ForegroundColor Green
    Write-Host "Deploy to EC2: sync contents of out\ to /opt/university/frontend/out/ on instances." -ForegroundColor Cyan
} finally {
    Pop-Location
}
