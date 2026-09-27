#!/usr/bin/env bash
# Еталон: оголошуємо внутрішній репозиторій у pom.xml (саме так це роблять у проєктах).
set -euo pipefail
WORKDIR="${WORKDIR:-/tmp/qa-scenario}"
P="$WORKDIR/01/consumer/pom.xml"
python3 - "$P" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
repos = '''  <repositories>
    <repository>
      <id>qa-releases</id>
      <url>http://localhost:8081/repository/qa-releases/</url>
    </repository>
  </repositories>
'''
if "<repositories>" not in text:
    text = text.replace("  <dependencies>", repos + "  <dependencies>", 1)
p.write_text(text, encoding="utf-8")
print("   еталон: репозиторій стенда додано в pom.xml")
PY
