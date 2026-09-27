#!/usr/bin/env bash
# Сценарій 3. Ситуація: після додавання mirror перестали розвʼязуватись внутрішні залежності.
# Причина: mirrorOf="*" перехоплює ВСЕ, включно з внутрішнім репозиторієм.
set -uo pipefail
. "$(dirname "$0")/../_common.sh"
rm -rf "$WORKDIR/03" && mkdir -p "$WORKDIR/03"
cat > "$WORKDIR/03/settings.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0">
  <mirrors>
    <!-- ЗАВДАННЯ: перехоплюється геть усе, разом із внутрішнім репозиторієм -->
    <mirror>
      <id>wide-mirror</id>
      <url>http://localhost:8081/repository/qa-public/</url>
      <mirrorOf>*</mirrorOf>
    </mirror>
  </mirrors>
</settings>
XML
pass "стан створено: mirror з mirrorOf=* перехоплює і зовнішні, і внутрішні репозиторії"
log "спробуй: mvn -s $WORKDIR/03/settings.xml help:effective-settings і подивись, скільки репозиторіїв підмінено"
