#!/usr/bin/env bash
# Еталон: описуємо шлях публікації в pom і реально публікуємо артефакт у внутрішній репозиторій.
set -euo pipefail
WORKDIR="${WORKDIR:-/tmp/qa-scenario}"
P="$WORKDIR/05/pom.xml"
python3 - "$P" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
dm = '''  <distributionManagement>
    <repository>
      <id>qa-releases</id>
      <url>http://localhost:8081/repository/qa-releases/</url>
    </repository>
  </distributionManagement>
'''
if "<distributionManagement>" not in text:
    text = text.replace("</project>", dm + "</project>", 1)
p.write_text(text, encoding="utf-8")
print("   еталон: distributionManagement додано")
PY
mvn -q -B -s "$(dirname "$0")/../../../settings.xml" -Dmaven.repo.local="$WORKDIR/05/local-repo" -f "$P" deploy
echo "   еталон: артефакт опубліковано у внутрішній репозиторій"
