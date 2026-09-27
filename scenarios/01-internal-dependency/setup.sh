#!/usr/bin/env bash
# Сценарій 1. Ситуація: приватна бібліотека є ТІЛЬКИ у внутрішньому репозиторії.
# У Central її немає — і ніколи не буде. Твоє завдання: зробити так, щоб збірка її знайшла.
set -uo pipefail
. "$(dirname "$0")/../_common.sh"
need_nexus
rm -rf "$WORKDIR/01" && mkdir -p "$WORKDIR/01/consumer"
log "створюю приватний артефакт qa.scenario:internal-lib:1.0.0 у внутрішньому репозиторії"
mkdir -p "$WORKDIR/01/lib/src/main/java/qa/scenario"
cat > "$WORKDIR/01/lib/pom.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>qa.scenario</groupId>
  <artifactId>internal-lib</artifactId>
  <version>1.0.0</version>
  <packaging>jar</packaging>
  <distributionManagement>
    <repository><id>qa-releases</id><url>http://localhost:8081/repository/qa-releases/</url></repository>
  </distributionManagement>
</project>
XML
cp "$(dirname "$0")/../../../lib/src/main/java/qa/mentorship/DemoLib.java" /dev/null 2>/dev/null || true
cat > "$WORKDIR/01/lib/src/main/java/qa/scenario/Marker.java" <<'JAVA'
package qa.scenario;

public final class Marker {
    private Marker() {}
    public static String value() { return "internal-only"; }
}
JAVA
cat > "$WORKDIR/01/consumer/pom.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>qa.scenario</groupId>
  <artifactId>consumer</artifactId>
  <version>1.0.0</version>
  <packaging>jar</packaging>
  <properties><maven.compiler.release>17</maven.compiler.release></properties>
  <!-- ЗАВДАННЯ: вкажи тут репозиторій, з якого Maven має взяти internal-lib -->
  <dependencies>
    <dependency>
      <groupId>qa.scenario</groupId>
      <artifactId>internal-lib</artifactId>
      <version>1.0.0</version>
    </dependency>
  </dependencies>
</project>
XML
log "деплою internal-lib у внутрішній репозиторій (так робить твоя команда)"
rm -rf "$WORKDIR/01/local-repo" && mkdir -p "$WORKDIR/01/local-repo"
mvn -q -B -s "$(dirname "$0")/../../settings.xml" -Dmaven.repo.local="$WORKDIR/01/local-repo" -f "$WORKDIR/01/lib/pom.xml" deploy \
  || fail "не вдалося задеплоїти артефакт у внутрішній репозиторій"
pass "стан створено: internal-lib лежить у qa-releases, у Central його немає"
log "тепер спробуй зібрати consumer: mvn -f $WORKDIR/01/consumer/pom.xml -Dmaven.repo.local=/tmp/clean-repo dependency:resolve"
log "побачиш помилку 'Could not find artifact' — це і є задача"
