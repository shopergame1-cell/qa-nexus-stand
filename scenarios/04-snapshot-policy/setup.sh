#!/usr/bin/env bash
# Сценарій 4. Ситуація: колега оновив snapshot, а в тебе збірка бере стару версію.
# Причина: політика оновлення (updatePolicy) і різниця між snapshot та release.
set -uo pipefail
. "$(dirname "$0")/../_common.sh"
rm -rf "$WORKDIR/04" && mkdir -p "$WORKDIR/04"
cat > "$WORKDIR/04/pom.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>qa.scenario</groupId>
  <artifactId>snapshot-user</artifactId>
  <version>1.0.0</version>
  <packaging>jar</packaging>
  <repositories>
    <repository>
      <id>qa-public</id>
      <url>http://localhost:8081/repository/qa-public/</url>
      <!-- ЗАВДАННЯ: чому тут лежить старий snapshot? Це питання про політику оновлення -->
      <snapshots>
        <enabled>true</enabled>
        <updatePolicy>never</updatePolicy>
      </snapshots>
    </repository>
  </repositories>
  <dependencies>
    <dependency>
      <groupId>qa.scenario</groupId>
      <artifactId>internal-lib</artifactId>
      <version>1.0.0-SNAPSHOT</version>
    </dependency>
  </dependencies>
</project>
XML
pass "стан створено: updatePolicy=never — свіжий snapshot ніколи не підтягнеться"
log "порівняй: mvn -f $WORKDIR/04/pom.xml dependency:resolve vs те саме з updatePolicy=always"
