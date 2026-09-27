#!/usr/bin/env bash
# Перевірка сценарію 5: артефакт опубліковано у внутрішній репозиторій і шлях описаний у pom.
set -uo pipefail
. "$(dirname "$0")/../_common.sh"
need_nexus
P="$WORKDIR/05/pom.xml"
[ -f "$P" ] || fail "спочатку запусти setup.sh"

# 1) шлях публікації описано в проєкті
grep -q "distributionManagement" "$P" || fail "у pom.xml немає distributionManagement — артефакт нікуди публікувати"
pass "у pom.xml описано distributionManagement"

# 2) артефакт реально доступний іншим (його видно з внутрішнього репозиторію)
code=$(curl -s -o /dev/null -w '%{http_code}' -u "$NEXUS_USER:$NEXUS_PASSWORD" \
  "$NEXUS_URL/repository/qa-releases/qa/scenario/team-lib/1.0.2/team-lib-1.0.2.pom")
[ "$code" = "200" ] || fail "артефакт не знайдено у внутрішньому репозиторії (HTTP $code) — колега все ще не збере"
pass "артефакт доступний у внутрішньому репозиторії (HTTP 200)"

# 3) контрольна перевірка: розвʼязати в чистому кеші
rm -rf "$WORKDIR/05/clean" && mkdir -p "$WORKDIR/05/clean"
cat > "$WORKDIR/05/consumer.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>qa.scenario</groupId>
  <artifactId>team-consumer</artifactId>
  <version>1.0.0</version>
  <packaging>jar</packaging>
  <repositories>
    <repository><id>qa-releases</id><url>http://localhost:8081/repository/qa-releases/</url></repository>
  </repositories>
  <dependencies>
    <dependency><groupId>qa.scenario</groupId><artifactId>team-lib</artifactId><version>1.0.2</version></dependency>
  </dependencies>
</project>
XML
if mvn -q -B -s "$(dirname "$0")/../../settings.xml" -Dmaven.repo.local="$WORKDIR/05/clean" -f "$WORKDIR/05/consumer.xml" dependency:resolve >/dev/null 2>&1; then
  pass "чистий кеш розвʼязав артефакт — «у колеги теж працює»"
else
  fail "у чистому кеші артефакт не розвʼязується"
fi
