#!/bin/bash
# Test print with Chinese job title (exercises lpdgbk GBK path).
# Usage: ./print-test.sh [QUEUE] [PDF]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QUEUE="${1:-FUJIFILM_Apeos_C2060}"
PDF="${2:-$ROOT/assets/test-print.pdf}"
TITLE="${TEST_TITLE:-项目承诺书（青年项目A类）}"

[[ -f "$PDF" ]] || { echo "missing PDF: $PDF"; exit 1; }
lpstat -p "$QUEUE" >/dev/null

# Prefer ASCII temp path for CUPS argv stability; title still Chinese
TMP="/tmp/ff-test-print.pdf"
cp "$PDF" "$TMP"

echo "printing -> $QUEUE title=$TITLE"
JOB="$(lp -d "$QUEUE" -t "$TITLE" -o PageSize=A4 "$TMP" | awk '{print $NF}' | tr -d '()')"
echo "job=$JOB"
for i in 1 2 3 4 5 6 7 8 9 10; do
  sleep 1
  if ! lpstat -o "$QUEUE" 2>/dev/null | grep -q .; then
    break
  fi
done
lpstat -W completed -l -o 2>/dev/null | head -8 || true
lpstat -p "$QUEUE" || true
echo "Check panel: job name should be readable Chinese (not 椤圭洰…)."
echo "If 024-965/024-951: paper sensor/tray — not the Mac driver."
