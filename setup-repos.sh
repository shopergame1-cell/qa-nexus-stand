#!/usr/bin/env bash
# TASK-55.1: створює три репозиторії, на яких побудовані всі вправи:
#   qa-releases — hosted, для ВЛАСНИХ артефактів (той, у який студент деплоїть)
#   qa-central  — proxy на Maven Central (кеш зовнішніх залежностей)
#   qa-public   — group, який об'єднує перші два (єдина точка входу для збірок)
# Ідемпотентно: повторний запуск не ламається, якщо репозиторії вже є.
set -uo pipefail

NEXUS_URL="${NEXUS_URL:-http://localhost:8081}"
NEXUS_USER="${NEXUS_USER:-admin}"
NEXUS_PASSWORD="${NEXUS_PASSWORD:-qa-stand-admin}"

echo "== чекаю, доки Nexus підніметься =="
for i in $(seq 1 60); do
  if curl -sf "$NEXUS_URL/service/rest/v1/status" >/dev/null 2>&1; then
    echo "   Nexus відповідає"
    break
  fi
  sleep 5
  [ "$i" = "60" ] && { echo "   Nexus не піднявся за 5 хвилин"; exit 1; }
done

create_repo() {
  local name="$1" payload="$2"
  local code
  code=$(curl -s -o /tmp/nexus-create.out -w '%{http_code}' -u "$NEXUS_USER:$NEXUS_PASSWORD" \
    -H 'Content-Type: application/json' -X POST "$NEXUS_URL/service/rest/v1/repositories" -d "$payload")
  if [ "$code" = "201" ]; then
    echo "   створено: $name"
  elif [ "$code" = "400" ] && grep -qi "already exists" /tmp/nexus-create.out; then
    echo "   уже існує: $name"
  else
    echo "   помилка створення $name (HTTP $code): $(head -c 200 /tmp/nexus-create.out)"
    return 1
  fi
}

echo "== створюю репозиторії =="
create_repo qa-releases '{"name":"qa-releases","online":true,"storage":{"blobStoreName":"default","strictContentTypeValidation":false,"writePolicy":"ALLOW"},"maven":{"versionPolicy":"RELEASE","layoutPolicy":"STRICT"}}'
create_repo qa-central '{"name":"qa-central","online":true,"storage":{"blobStoreName":"default","strictContentTypeValidation":false},"proxy":{"remoteUrl":"https://repo1.maven.org/maven2/","contentMaxAge":1440,"metadataMaxAge":1440},"negativeCache":{"enabled":true,"timeToLive":1440},"httpClient":{"blocked":false,"autoBlock":true},"maven":{"versionPolicy":"RELEASE","layoutPolicy":"STRICT"}}'
create_repo qa-public '{"name":"qa-public","online":true,"storage":{"blobStoreName":"default","strictContentTypeValidation":false},"group":{"memberNames":["qa-releases","qa-central"]}}'

echo "== перевіряю, що group бачить обидва члени =="
curl -s -u "$NEXUS_USER:$NEXUS_PASSWORD" "$NEXUS_URL/service/rest/v1/repositories" | \
  python3 -c "
import json,sys
repos = {r['name']: r for r in json.load(sys.stdin)}
for name in ('qa-releases','qa-central','qa-public'):
    print('  ', name, 'є' if name in repos else 'НЕМАЄ')
print('   члени qa-public:', repos.get('qa-public', {}).get('attributes', {}).get('group', {}).get('memberNames', '?'))
"
echo "Готово. Далі дивись README.md: як задеплоїти свій артефакт і як переконатись, що Maven тягне його саме зі стенда."
