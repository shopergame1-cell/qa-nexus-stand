#!/usr/bin/env bash
# Сценарій 2. Ситуація: деплой падає з 401, хоча пароль правильний.
# Причина: id сервера в settings.xml не збігається з id репозиторію в pom.xml.
set -uo pipefail
. "$(dirname "$0")/../_common.sh"
need_nexus
rm -rf "$WORKDIR/02" && mkdir -p "$WORKDIR/02"
cat > "$WORKDIR/02/settings.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0">
  <servers>
    <!-- ЗАВДАННЯ: тут id не збігається з id репозиторію в pom.xml -> Maven не знайде пароль -->
    <server>
      <id>internal-releases</id>
      <username>admin</username>
      <password>qa-stand-admin</password>
    </server>
  </servers>
</settings>
XML
cat > "$WORKDIR/02/pom.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>qa.scenario</groupId>
  <artifactId>auth-demo</artifactId>
  <version>1.0.1</version>
  <packaging>jar</packaging>
  <distributionManagement>
    <repository><id>qa-releases</id><url>http://localhost:8081/repository/qa-releases/</url></repository>
  </distributionManagement>
</project>
XML
mkdir -p "$WORKDIR/02/src/main/java/qa/scenario"
cp "$(dirname "$0")/../../lib/src/main/java/qa/mentorship/DemoLib.java" "$WORKDIR/02/src/main/java/qa/scenario/Marker.java" 2>/dev/null || true
pass "стан створено: id сервера 'internal-releases', id репозиторію 'qa-releases'"
log "спробуй: mvn -s $WORKDIR/02/settings.xml -f $WORKDIR/02/pom.xml deploy (отримаєш 401)"
