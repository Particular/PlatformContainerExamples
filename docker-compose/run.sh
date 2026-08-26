#!/usr/bin/env bash
# One-command experience for the Service Platform + Learning Transport + SmokeTest example.
#
# What it does:
#   1. Builds and starts all containers (ServiceControl, Audit, Monitoring, ServicePulse,
#      RavenDB, and the containerized SmokeTest tool), waiting until they report healthy.
#   2. Opens ServicePulse in your default host browser.
#   3. Drops you straight into an interactive session of the SmokeTest tool, preconfigured
#      to use the shared Learning Transport volume, ready to send test messages.
#
# Usage:
#   ./run.sh
#
# Requirements:
#   - Docker and Docker Compose v2 (the `docker compose` CLI plugin)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SERVICEPULSE_URL="http://localhost:9090"

echo "==> Building and starting the Service Platform stack..."
docker compose up -d --build --wait

echo "==> All services are healthy."
echo "==> Opening ServicePulse at ${SERVICEPULSE_URL}..."

open_browser() {
  local url="$1"
  if command -v open >/dev/null 2>&1; then
    open "$url"                       # macOS
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url"                   # Linux
  elif command -v wslview >/dev/null 2>&1; then
    wslview "$url"                    # WSL
  elif command -v cmd.exe >/dev/null 2>&1; then
    cmd.exe /c start "" "$url"        # WSL fallback
  else
    echo "Could not detect a way to open a browser automatically."
    echo "Please open ${url} manually."
  fi
}

open_browser "$SERVICEPULSE_URL"

echo "==> Connecting to the SmokeTest container (Learning Transport)..."
echo "==> Type 'q', 'quit', or 'exit' inside the tool to leave the interactive session."
sleep 1

exec docker compose exec -it smoketest servicecontrol-smoketest learning-transport /learningtransport
