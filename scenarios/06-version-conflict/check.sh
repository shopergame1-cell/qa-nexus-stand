#!/usr/bin/env bash
# Перевірка сценарію 6: версію зафіксовано явно, і в дереві лишається одна версія.
set -uo pipefail
. "$(dirname "$0")/../_common.sh"
P="$WORKDIR/06/pom.xml"
[ -f "$P" ] || fail "спочатку запусти setup.sh"
command -v mvn >/dev/null 2>&1 || fail "потрібен Maven"

# 1) версія зафіксована явно: dependencyManagement або exclusion
if grep -q "dependencyManagement" "$P"; then
  pass "версію зафіксовано через dependencyManagement"
elif grep -q "<exclusions>" "$P"; then
  pass "зайву транзитивну залежність виключено через exclusions"
else
  fail "у pom.xml немає ні dependencyManagement, ні exclusions — версія досі «як вийде»"
fi

# 2) у дереві справді одна версія guava
mvn -q -B -f "$P" dependency:tree -Dincludes=com.google.guava > "$WORKDIR/06/tree.log" 2>&1
versions=$(grep -oE "com.google.guava:guava:jar:[^ ]+" "$WORKDIR/06/tree.log" | sed 's/.*jar://' | sort -u | tr '\n' ' ')
count=$(echo "$versions" | wc -w)
if [ "$count" -le 1 ]; then
  pass "у дереві одна версія guava: $versions"
else
  fail "у дереві досі кілька версій: $versions — вибери одну свідомо"
fi
