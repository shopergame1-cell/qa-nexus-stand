#!/usr/bin/env bash
# Перевірка сценарію 4: політика оновлення дозволяє підтягувати свіжі snapshot.
set -uo pipefail
. "$(dirname "$0")/../_common.sh"
P="$WORKDIR/04/pom.xml"
[ -f "$P" ] || fail "спочатку запусти setup.sh"

policy=$(python3 - "$P" <<'PY'
import re, sys, pathlib
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
m = re.search(r"<updatePolicy>\s*([^<]+?)\s*</updatePolicy>", text)
print(m.group(1) if m else "")
PY
)
case "$policy" in
  always|daily|interval:*) pass "політика оновлення дозволяє брати свіжі snapshot: '$policy'" ;;
  never) fail "updatePolicy=never: snapshot ніколи не оновиться, колега деплоїть — а в тебе стара версія" ;;
  "") fail "не знайдено <updatePolicy> — політика не задана явно" ;;
  *) fail "неочікувана політика: '$policy'" ;;
esac

grep -q "SNAPSHOT" "$P" && pass "задача справді про snapshot (а не release)" || fail "залежність більше не snapshot — перевір умову"
