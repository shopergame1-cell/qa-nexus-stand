#!/usr/bin/env bash
# Сценарій 5. Ситуація: у тебе збірка проходить, у колеги — ні.
# Причина: артефакт лежить лише у твоєму локальному ~/.m2, його ніхто більше не має.
set -uo pipefail
. "$(dirname "$0")/../_common.sh"
need_nexus
rm -rf "$WORKDIR/05" && mkdir -p "$WORKDIR/05/src/main/java/qa/scenario"
cat > "$WORKDIR/05/pom.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>qa.scenario</groupId>
  <artifactId>team-lib</artifactId>
  <version>1.0.2</version>
  <packaging>jar</packaging>
  <!-- ЗАВДАННЯ: колега не бачить цей артефакт. Зроби так, щоб побачив — і щоб шлях був описаний у проєкті -->
</project>
XML
cp "$(dirname "$0")/../../lib/src/main/java/qa/mentorship/DemoLib.java" "$WORKDIR/05/src/main/java/qa/scenario/Marker.java"
rm -rf "$WORKDIR/05/only-local" && mkdir -p "$WORKDIR/05/only-local"
mvn -q -B -Dmaven.repo.local="$WORKDIR/05/only-local" -f "$WORKDIR/05/pom.xml" install \
  || fail "не вдалося встановити артефакт у локальний кеш"
pass "стан створено: team-lib:1.0.2 є ТІЛЬКИ у локальному кеші $WORKDIR/05/only-local"
