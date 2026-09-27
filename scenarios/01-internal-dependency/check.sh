#!/usr/bin/env bash
# Перевірка сценарію 1: чи справді збірка тягне залежність із внутрішнього репозиторію.
set -uo pipefail
. "$(dirname "$0")/../_common.sh"
need_nexus
POM="$WORKDIR/01/consumer/pom.xml"
[ -f "$POM" ] || fail "спочатку запусти setup.sh"

# 1) у pom мусить бути оголошений репозиторій, який указує на стенд
grep -q "qa-releases\|qa-public" "$POM" || fail "у consumer/pom.xml немає репозиторію стенда — залежність узяти нізвідки"
pass "у pom.xml оголошено репозиторій стенда"

# 2) збірка в чистому локальному кеші мусить пройти
rm -rf "$WORKDIR/01/clean-repo" && mkdir -p "$WORKDIR/01/clean-repo"
if mvn -q -B -s "$(dirname "$0")/../../settings.xml" -Dmaven.repo.local="$WORKDIR/01/clean-repo" \
      -f "$POM" dependency:resolve > "$WORKDIR/01/resolve.log" 2>&1; then
  pass "залежність розвʼязалась у чистому кеші — збірка проходить"
else
  fail "збірка не проходить: $(grep -m1 -i 'could not' "$WORKDIR/01/resolve.log" || tail -3 "$WORKDIR/01/resolve.log")"
fi
