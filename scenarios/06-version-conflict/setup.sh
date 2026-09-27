#!/usr/bin/env bash
# Сценарій 6. Ситуація: у дереві залежностей дві версії однієї бібліотеки.
# Причина: транзитивна залежність тягне іншу версію, ніж оголошена прямо.
set -uo pipefail
. "$(dirname "$0")/../_common.sh"
rm -rf "$WORKDIR/06" && mkdir -p "$WORKDIR/06"
cat > "$WORKDIR/06/pom.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>qa.scenario</groupId>
  <artifactId>conflict-demo</artifactId>
  <version>1.0.0</version>
  <packaging>jar</packaging>
  <dependencies>
    <!-- пряма залежність -->
    <dependency>
      <groupId>com.google.guava</groupId>
      <artifactId>guava</artifactId>
      <version>31.1-jre</version>
    </dependency>
    <!-- і транзитивна, яка тягне ІНШУ версію того самого -->
    <dependency>
      <groupId>com.google.cloud</groupId>
      <artifactId>google-cloud-storage</artifactId>
      <version>2.22.0</version>
    </dependency>
  </dependencies>
</project>
XML
pass "стан створено: у дереві очікуються дві версії guava"
log "подивись: mvn -f $WORKDIR/06/pom.xml dependency:tree -Dincludes=com.google.guava"
log "Maven вибере одну (найближчу), але покладатись на «як вийде» не можна — версію фіксують явно"
