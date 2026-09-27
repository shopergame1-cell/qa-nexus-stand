#!/usr/bin/env bash
# Перевірка сценарію 3: mirror перехоплює лише те, що потрібно.
set -uo pipefail
. "$(dirname "$0")/../_common.sh"
S="$WORKDIR/03/settings.xml"
[ -f "$S" ] || fail "спочатку запусти setup.sh"

mirror_of=$(python3 - "$S" <<'PY'
import re, sys, pathlib
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
m = re.findall(r"<mirrorOf>\s*([^<]+?)\s*</mirrorOf>", text)
print(",".join(m))
PY
)
[ -n "$mirror_of" ] || fail "у settings.xml немає <mirrorOf>"
case "$mirror_of" in
  "*") fail "mirrorOf="*" перехоплює внутрішні репозиторії — саме через це залежність 'зникає'" ;;
  *central*|*'external:*'*) pass "mirrorOf звужено: '$mirror_of' (перехоплює лише зовнішні/central)" ;;
  *) fail "mirrorOf='$mirror_of' — не схоже на свідоме звуження; порівняй з central або external:*" ;;
esac

# перевіримо, що effective-settings справді не підмінює все
if command -v mvn >/dev/null 2>&1; then
  version=$(mvn -v 2>/dev/null | head -1)
  case "$version" in
    *"Apache Maven 3.8"*|*"Apache Maven 3.9"*|*"Apache Maven 4"*)
      pass "Maven $version: http-репозиторії блокуються з коробки — не забудь дозвіл для локального стенда"
      ;;
    *) pass "Maven: $version" ;;
  esac
fi
