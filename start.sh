#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"

mkdir -p ./data/postgres

echo "Starting Zabbix pilot stack from: $here"
docker compose up -d

echo
echo "Status:"
docker compose ps

echo
echo "UI should be available on: http://127.0.0.1/"
