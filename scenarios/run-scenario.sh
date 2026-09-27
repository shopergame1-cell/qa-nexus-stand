#!/usr/bin/env bash
# Прогін одного сценарію: зламаний стан -> перевірка падає -> еталонний розвʼязок -> перевірка проходить.
set -uo pipefail
SCENARIO="${1:?вкажи номер сценарію, наприклад 01}"
DIR="$(cd "$(dirname "$0")" && pwd)/$(ls "$(dirname "$0")" | grep "^${SCENARIO}-")"
export WORKDIR="${WORKDIR:-/tmp/qa-scenario}"

echo "=== сценарій ${SCENARIO} ==="
[ -d "$DIR" ] || { echo "✗ теки сценарію немає: $DIR"; exit 1; }

echo "--- крок 1: створюю зламаний стан"
bash "$DIR/setup.sh" || { echo "✗ setup.sh не зміг створити стан"; exit 1; }

echo "--- крок 2: перевірка мусить ПАДАТИ (стан справді зламаний)"
if bash "$DIR/check.sh" >/tmp/check-before.log 2>&1; then
  echo "✗ check.sh пройшов на зламаному стані — сценарій нічого не перевіряє"
  cat /tmp/check-before.log
  exit 1
else
  echo "   очікувано впав: $(grep -m1 '✗' /tmp/check-before.log || tail -1 /tmp/check-before.log)"
fi

echo "--- крок 3: застосовую еталонний розвʼязок"
bash "$DIR/solution/apply.sh" || { echo "✗ розвʼязок не застосувався"; exit 1; }

echo "--- крок 4: перевірка мусить ПРОЙТИ"
if bash "$DIR/check.sh"; then
  echo "✅ сценарій ${SCENARIO}: зламано -> полагоджено"
else
  echo "✗ сценарій ${SCENARIO}: після розвʼязку перевірка досі падає"
  exit 1
fi
