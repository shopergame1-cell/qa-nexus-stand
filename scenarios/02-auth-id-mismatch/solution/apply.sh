#!/usr/bin/env bash
# Еталон: id сервера = id репозиторію, пароль у вигляді, який дає mvn encrypt-password.
set -euo pipefail
WORKDIR="${WORKDIR:-/tmp/qa-scenario}"
S="$WORKDIR/02/settings.xml"
python3 - "$S" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
text = text.replace("<id>internal-releases</id>", "<id>qa-releases</id>")
# у реальному житті це результат mvn encrypt-password із ~/.m2/settings-security.xml
text = text.replace("<password>qa-stand-admin</password>", "<password>{t7Q2fmD0k1pZ8bYcVhLxN4sR}</password>")
p.write_text(text, encoding="utf-8")
print("   еталон: id вирівняно, пароль зашифровано")
PY
