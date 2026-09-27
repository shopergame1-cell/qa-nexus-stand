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

echo "== пароль адміністратора =="
# У цій версії Nexus пароль адміністратора НЕ береться зі змінної середовища: він генерується
# і кладеться у /nexus-data/admin.password (файл існує лише до першої зміни пароля).
# Тому не «пробуємо» різні паролі (кожна невдала спроба наближає блокування IP анти-брутфорсом),
# а діємо однозначно: є файл -> читаємо і зводимо до пароля стенда; немає -> пароль уже наш.
INITIAL=""
if command -v docker >/dev/null 2>&1; then
  INITIAL=$(docker compose -f "$(dirname "$0")/docker-compose.yml" exec -T "$COMPOSE_SERVICE" \
    cat /nexus-data/admin.password 2>/dev/null | tr -d '\r\n' || true)
fi

if [ -n "$INITIAL" ]; then
  log "файл адмін-пароля знайдено — зводжу пароль до пароля стенда (одна спроба, без вгадувань)"
  code=$(curl -s -o /tmp/nexus-pw.out -w '%{http_code}' -u "$NEXUS_USER:$INITIAL" \
    -X PUT "$NEXUS_URL/service/rest/v1/security/users/admin/change-password" \
    -H 'Content-Type: application/json' -d "{\"newPassword\":\"$STAND_PASSWORD\"}")
  case "$code" in
    204|200) log "пароль адміністратора зведено до пароля стенда" ;;
    *) echo "   ✗ не вдалося змінити пароль (HTTP $code): $(head -c 200 /tmp/nexus-pw.out)"; exit 1 ;;
  esac
else
  log "файлу немає — вважаємо, що пароль стенда вже діє (том з попереднього запуску)"
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

echo "== перевіряю, що репозиторій приймає ЗАПИС (саме це робить деплой) =="
# Важливо: читати список репозиторіїв може навіть анонімний користувач, тому перевіряти
# пароль читанням — оманливо. Єдина надійна перевірка — спробувати записати.
write_code() {
  curl -s -o /tmp/nexus-put.out -w '%{http_code}' -u "admin:$1" -X PUT \
    --data-binary "@$0" "$NEXUS_URL/repository/qa-releases/qa/mentorship/probe/probe.txt"
}
code=$(write_code "$STAND_PASSWORD")
case "$code" in
  200|201|204) log "qa-releases приймає записи паролем стенда (HTTP $code)" ;;
  *)
    echo "   ✗ пароль стенда НЕ дає запису (HTTP $code) — саме це ламає деплой"
    # пробуємо початковий пароль із файлу: якщо він дає запис, зводимо до пароля стенда
    INITIAL2=$(docker compose -f "$(dirname "$0")/docker-compose.yml" exec -T "$COMPOSE_SERVICE" \
      cat /nexus-data/admin.password 2>/dev/null | tr -d '\r\n' || true)
    if [ -n "$INITIAL2" ] && [ "$(curl -s -o /dev/null -w '%{http_code}' -u "admin:$INITIAL2" -X PUT --data-binary "@$0" "$NEXUS_URL/repository/qa-releases/qa/mentorship/probe/probe2.txt")" != "401" ]; then
      log "початковий пароль із файлу дає запис — зводжу його до пароля стенда"
      curl -s -o /dev/null -w '   зміна пароля: HTTP %{http_code}\n' -u "admin:$INITIAL2" \
        -X PUT "$NEXUS_URL/service/rest/v1/security/users/admin/change-password" \
        -H 'Content-Type: application/json' -d "{\"newPassword\":\"$STAND_PASSWORD\"}"
      code=$(write_code "$STAND_PASSWORD")
      case "$code" in
        200|201|204) log "тепер пароль стенда дає запис (HTTP $code)" ;;
        *) echo "   ✗ усе ще не дає запису (HTTP $code)"; exit 1 ;;
      esac
    else
      echo "   ✗ жоден із паролів не дає запису — проблема не в паролі"
      exit 1
    fi
    ;;
esac

echo "Готово. Далі дивись README.md: як задеплоїти свій артефакт і як переконатись, що Maven тягне його саме зі стенда."
