#!/usr/bin/env bash
# Перевірка сценарію 2: id збігаються, пароль не лежить у git і деплой проходить.
set -uo pipefail
. "$(dirname "$0")/../_common.sh"
need_nexus
S="$WORKDIR/02/settings.xml"
P="$WORKDIR/02/pom.xml"
[ -f "$S" ] && [ -f "$P" ] || fail "спочатку запусти setup.sh"

server_id=$(python3 - "$S" <<'PY'
import re, sys, pathlib
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
ids = re.findall(r"<server>\s*<id>([^<]+)</id>", text)
print(ids[0] if ids else "")
PY
)
repo_id=$(python3 - "$P" <<'PY'
import re, sys, pathlib
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
ids = re.findall(r"<repository>\s*<id>([^<]+)</id>", text)
print(ids[0] if ids else "")
PY
)
[ -n "$server_id" ] || fail "у settings.xml немає жодного <server><id>"
[ "$server_id" = "$repo_id" ] || fail "id сервера '$server_id' не збігається з id репозиторію '$repo_id' — Maven не знайде пароль (401)"
pass "id сервера і репозиторію збігаються: $server_id"

if grep -qi "encrypt" "$S" || grep -qE '\{[A-Za-z0-9+/=]{20,}\}' "$S"; then
  pass "пароль у settings.xml зашифрований"
else
  fail "пароль лежить відкритим — у реальному проєкті його шифрують (mvn encrypt-password) і не тримають у git"
fi

if mvn -q -B -s "$S" -Dmaven.repo.local="$WORKDIR/02/local-repo" -f "$P" deploy > "$WORKDIR/02/deploy.log" 2>&1; then
  pass "деплой проходить без 401"
else
  fail "деплой усе ще падає: $(grep -m1 -iE '401|unauthorized|could not' "$WORKDIR/02/deploy.log" || tail -3 "$WORKDIR/02/deploy.log")"
fi
