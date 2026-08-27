#!/usr/bin/env pwsh
# One-command experience for the Service Platform + Learning Transport + SmokeTest example.
# Cross-platform: works with PowerShell Core (pwsh) on Windows, macOS, and Linux.
#
# What it does:
#   1. Validates the requested ServiceControl / ServicePulse versions (if any) against
#      what's actually published in the registry. Defaults to "latest" when omitted.
#   2. Pulls the images for all services that use a published image.
#   3. Builds and starts all containers (ServiceControl, Audit, Monitoring, ServicePulse,
#      RavenDB, and the containerized SmokeTest tool), waiting until they report healthy.
#   4. Opens ServicePulse in your default host browser.
#   5. Drops you straight into an interactive session of the SmokeTest tool, preconfigured
#      to use the shared Learning Transport folder, ready to send test messages.
#   6. When the SmokeTest session ends (q/quit/exit), tears everything down: stops and
#      removes all containers/volumes (`docker compose down -v`) and deletes the
#      bind-mounted `learningtransport` folder, so every run starts from a clean slate.
#
# Usage:
#   pwsh ./run.ps1
#   pwsh ./run.ps1 -ServiceControlVersion 6.6.1 -ServicePulseVersion 2.3.1
#   pwsh ./run.ps1 -ServiceControlVersion 6.6.1-beta.3
#
# Parameters:
#   -ServiceControlVersion  Tag to use for ServiceControl, ServiceControl.Audit,
#                           ServiceControl.Monitoring, and the matching RavenDB image.
#                           Any tag accepted by the registry is valid (semantic or not,
#                           e.g. a beta/RC/date-based build). Defaults to "latest".
#   -ServicePulseVersion    Tag to use for ServicePulse. Same rules as above.
#                           Defaults to "latest".
#
# Requirements:
#   - PowerShell Core (pwsh) - https://aka.ms/powershell
#   - Docker and Docker Compose v2 (the `docker compose` CLI plugin)
#   - Network access to Docker Hub, to validate the requested tags exist

[CmdletBinding()]
param(
    [string]$ServiceControlVersion = 'latest',
    [string]$ServicePulseVersion = 'latest'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$ServicePulseUrl = 'http://localhost:9090'
$LearningTransportPath = Join-Path $ScriptDir 'learningtransport'

function Test-ImageTagPublished {
    param(
        [string]$Repository,   # e.g. "particular/servicecontrol"
        [string]$Tag
    )

    $uri = "https://hub.docker.com/v2/repositories/$Repository/tags/$Tag"
    try {
        $null = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop
        return $true
    }
    catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        if ($statusCode -eq 404) {
            return $false
        }
        # Network error, registry unreachable, or another unexpected failure.
        throw "Could not reach the image registry to validate tag '$Tag' for '$Repository': $_"
    }
}

function Assert-VersionAvailable {
    param(
        [string]$Repository,
        [string]$Tag,
        [string]$FriendlyName
    )

    Write-Host "==> Checking that $FriendlyName version '$Tag' is published..."

    if ($Tag -eq 'latest') {
        if (-not (Test-ImageTagPublished -Repository $Repository -Tag 'latest')) {
            Write-Error "No published versions were found for $FriendlyName ($Repository). Nothing has been deployed."
            exit 1
        }
        return
    }

    if (-not (Test-ImageTagPublished -Repository $Repository -Tag $Tag)) {
        Write-Error "$FriendlyName version '$Tag' was not found in the image registry ($Repository). Nothing has been deployed."
        exit 1
    }
}

Assert-VersionAvailable -Repository 'particular/servicecontrol' -Tag $ServiceControlVersion -FriendlyName 'ServiceControl'
Assert-VersionAvailable -Repository 'particular/servicepulse' -Tag $ServicePulseVersion -FriendlyName 'ServicePulse'

# The RavenDB image version always tracks the ServiceControl version (compose.yml
# already references particular/servicecontrol-ravendb:${SERVICECONTROL_TAG}), so
# no separate user-facing parameter or validation is needed for it.
$env:SERVICECONTROL_TAG = $ServiceControlVersion
$env:SERVICEPULSE_TAG = $ServicePulseVersion

Write-Host "==> Using ServiceControl version: $ServiceControlVersion"
Write-Host "==> Using ServicePulse version: $ServicePulseVersion"

Write-Host '==> Pulling images...'
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

Write-Host '==> SmokeTest session ended. Tearing down the stack...'
docker compose down -v
if ($LASTEXITCODE -ne 0) {
    Write-Warning 'docker compose down failed. You may need to run "docker compose down -v" manually.'
}

if (Test-Path $LearningTransportPath) {
    Write-Host "==> Removing learning transport folder at $LearningTransportPath..."
    Remove-Item -Path $LearningTransportPath -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host '==> Done. All containers, volumes, and the learningtransport folder have been removed.'
