#!/usr/bin/env pwsh
# One-command experience for the Service Platform + Learning Transport + SmokeTest example.
# Cross-platform: works with PowerShell Core (pwsh) on Windows, macOS, and Linux.
#
# What it does:
#   1. Pulls the latest images for all services that use a published image.
#   2. Builds and starts all containers (ServiceControl, Audit, Monitoring, ServicePulse,
#      RavenDB, and the containerized SmokeTest tool), waiting until they report healthy.
#   3. Opens ServicePulse in your default host browser.
#   4. Drops you straight into an interactive session of the SmokeTest tool, preconfigured
#      to use the shared Learning Transport folder, ready to send test messages.
#
# Usage:
#   pwsh ./run.ps1
#   (or, if made executable on macOS/Linux: ./run.ps1)
#
# Requirements:
#   - PowerShell Core (pwsh) - https://aka.ms/powershell
#   - Docker and Docker Compose v2 (the `docker compose` CLI plugin)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$ServicePulseUrl = 'http://localhost:9090'

Write-Host '==> Pulling latest images...'
docker compose pull
if ($LASTEXITCODE -ne 0) {
    Write-Error 'docker compose pull failed. See output above for details.'
    exit $LASTEXITCODE
}

Write-Host '==> Building and starting the Service Platform stack...'
docker compose up -d --build --wait
if ($LASTEXITCODE -ne 0) {
    Write-Error 'docker compose up failed. See output above for details.'
    exit $LASTEXITCODE
}

Write-Host '==> All services are healthy.'
Write-Host "==> Opening ServicePulse at $ServicePulseUrl..."

function Open-Browser {
    param([string]$Url)

    try {
        if ($IsWindows) {
            Start-Process $Url
        }
        elseif ($IsMacOS) {
            Start-Process 'open' -ArgumentList $Url
        }
        elseif ($IsLinux) {
            if (Get-Command 'xdg-open' -ErrorAction SilentlyContinue) {
                Start-Process 'xdg-open' -ArgumentList $Url
            }
            elseif (Get-Command 'wslview' -ErrorAction SilentlyContinue) {
                Start-Process 'wslview' -ArgumentList $Url
            }
            else {
                throw 'No suitable browser-opening command found (xdg-open/wslview).'
            }
        }
        else {
            throw 'Unrecognized OS platform.'
        }
    }
    catch {
        Write-Host "Could not open a browser automatically: $_"
        Write-Host "Please open $Url manually."
    }
}

Open-Browser -Url $ServicePulseUrl

Write-Host '==> Connecting to the SmokeTest container (Learning Transport)...'
Write-Host "==> Type 'q', 'quit', or 'exit' inside the tool to leave the interactive session."
Start-Sleep -Seconds 1

docker compose exec -it smoketest servicecontrol-smoketest learning-transport /learningtransport
