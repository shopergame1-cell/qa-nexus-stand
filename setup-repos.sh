#!/usr/bin/env bash
# TASK-55.1: готує стенд до роботи.
#
# Важливо про пароль: Nexus 3.70 НЕ бере пароль адміністратора зі змінної середовища —
# він генерує випадковий і кладе його у /nexus-data/admin.password. Тому після старту
# ми читаємо цей файл і один раз зводимо пароль до відомого пароля стенда,
# щоб приклади в README і settings.xml були однакові для всіх.
#
# Ідемпотентно: повторний запуск не ламається, якщо репозиторії вже є.

set -uo pipefail

NEXUS_URL="${NEXUS_URL:-http://localhost:8081}"
NEXUS_USER="${NEXUS_USER:-admin}"
STAND_PASSWORD="${STAND_PASSWORD:-qa-stand-admin}"
COMPOSE_SERVICE="${COMPOSE_SERVICE:-nexus}"
PASSWORD_FILE="$(dirname "$0")/.nexus-password"

log() { echo "   $*"; }

echo "== чекаю, доки Nexus підніметься =="
for i in $(seq 1 60); do
  if curl -sf "$NEXUS_URL/service/rest/v1/status" >/dev/null 2>&1; then
    log "Nexus відповідає"
    break
  fi
  sleep 5
  if [ "$i" = "60" ]; then echo "   ✗ Nexus не піднявся за 5 хвилин"; exit 1; fi
done

echo "== зводжу пароль адміністратора до пароля стенда =="
if curl -sf -u "$NEXUS_USER:$STAND_PASSWORD" "$NEXUS_URL/service/rest/v1/status/check" >/dev/null 2>&1; then
  log "пароль стенда вже діє"
else
  INITIAL=""
  # 1) спосіб для локального запуску: файл у контейнері
  if command -v docker >/dev/null 2>&1; then
    INITIAL=$(docker compose -f "$(dirname "$0")/docker-compose.yml" exec -T "$COMPOSE_SERVICE" \
      cat /nexus-data/admin.password 2>/dev/null | tr -d '\r\n' || true)
  fi
  # 2) спосіб для CI: пароль переданий через змінну (коли файл недоступний)
  INITIAL="${INITIAL:-${NEXUS_INITIAL_PASSWORD:-}}"

  if [ -z "$INITIAL" ]; then
    echo "   ✗ не вдалося дістати початковий пароль адміністратора"
    echo "     локально: docker compose exec nexus cat /nexus-data/admin.password"
    exit 1
  fi

  code=$(curl -s -o /tmp/nexus-pw.out -w '%{http_code}' -u "$NEXUS_USER:$INITIAL" \
    -X PUT "$NEXUS_URL/service/rest/v1/security/users/admin/change-password" \
    -H 'Content-Type: application/json' -d "{\"newPassword\":\"$STAND_PASSWORD\"}")
  if [ "$code" = "204" ] || [ "$code" = "200" ]; then
    log "пароль адміністратора змінено на пароль стенда"
  else
    echo "   ✗ не вдалося змінити пароль (HTTP $code): $(head -c 200 /tmp/nexus-pw.out)"
    exit 1
  fi
fi

echo "$NEXUS_USER:$STAND_PASSWORD" > "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"

AUTH="-u $NEXUS_USER:$STAND_PASSWORD"

create_repo() {
  local name="$1" payload="$2" label="$3"
  local code
  code=$(curl -s -o /tmp/nexus-create.out -w '%{http_code}' $AUTH \
    -H 'Content-Type: application/json' -X POST "$NEXUS_URL/service/rest/v1/repositories" -d "$payload")
  if [ "$code" = "201" ]; then
    log "створено: $label"
  elif [ "$code" = "400" ] && grep -qi "already exists" /tmp/nexus-create.out; then
    log "уже існує: $label"
  else
    echo "   ✗ помилка створення $label (HTTP $code): $(head -c 300 /tmp/nexus-create.out)"
    return 1
  fi
}

echo "== створюю репозиторії =="
create_repo qa-releases '{"name":"qa-releases","online":true,"storage":{"blobStoreName":"default","strictContentTypeValidation":false,"writePolicy":"ALLOW"},"maven":{"versionPolicy":"RELEASE","layoutPolicy":"STRICT"}}' "qa-releases (hosted)" || exit 1
create_repo qa-central '{"name":"qa-central","online":true,"storage":{"blobStoreName":"default","strictContentTypeValidation":false},"proxy":{"remoteUrl":"https://repo1.maven.org/maven2/","contentMaxAge":1440,"metadataMaxAge":1440},"negativeCache":{"enabled":true,"timeToLive":1440},"httpClient":{"blocked":false,"autoBlock":true},"maven":{"versionPolicy":"RELEASE","layoutPolicy":"STRICT"}}' "qa-central (proxy на Central)" || exit 1
create_repo qa-public '{"name":"qa-public","online":true,"storage":{"blobStoreName":"default","strictContentTypeValidation":false},"group":{"memberNames":["qa-releases","qa-central"]},"maven":{"versionPolicy":"MIXED","layoutPolicy":"PERMISSIVE"}}' "qa-public (group)" || exit 1

echo "== перевіряю, що все на місці (інакше падаю голосно) =="
curl -s $AUTH "$NEXUS_URL/service/rest/v1/repositories" | python3 -c "
import json, sys
repos = {r['name']: r for r in json.load(sys.stdin)}
missing = [n for n in ('qa-releases', 'qa-central', 'qa-public') if n not in repos]
for name in ('qa-releases', 'qa-central', 'qa-public'):
    print('  ', name, 'є' if name in repos else 'НЕМАЄ')
print('   члени qa-public:', repos.get('qa-public', {}).get('attributes', {}).get('group', {}).get('memberNames', '?'))
if missing:
    print('   ✗ не створено:', ', '.join(missing)); sys.exit(1)
"

echo "== перевіряю, що репозиторій приймає деплой (порожній пробний PUT) =="
code=$(curl -s -o /tmp/nexus-put.out -w '%{http_code}' $AUTH -X PUT \
  -H 'Content-Type: application/xml' --data '<probe/>' \
  "$NEXUS_URL/repository/qa-releases/qa/mentorship/probe/probe.xml")
case "$code" in
  200|201|204) log "qa-releases приймає записи (HTTP $code)" ;;
  401|403) echo "   ✗ репозиторій не приймає авторизований запис (HTTP $code) — саме це ламає деплой"; exit 1 ;;
  *) log "qa-releases відповів HTTP $code на пробний PUT (не критично)" ;;
esac

echo "Готово. Далі дивись README.md: як задеплоїти свій артефакт і як переконатись, що Maven тягне його саме зі стенда."
