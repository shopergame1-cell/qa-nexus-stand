#!/usr/bin/env bash
# Спільні дрібниці для сценаріїв: логування і перевірка передумов.
set -uo pipefail

WORKDIR="${WORKDIR:-/tmp/qa-scenario}"
NEXUS_URL="${NEXUS_URL:-http://localhost:8081}"
NEXUS_USER="${NEXUS_USER:-admin}"
NEXUS_PASSWORD="${NEXUS_PASSWORD:-qa-stand-admin}"

log()  { echo "   $*"; }
fail() { echo "   ✗ $*"; exit 1; }
pass() { echo "   ✓ $*"; }

need_nexus() {
  curl -sf "$NEXUS_URL/service/rest/v1/status" >/dev/null 2>&1 || fail "Nexus недоступний на $NEXUS_URL (підніми: docker compose up -d && bash setup-repos.sh)"
}
