#!/bin/bash
# Pack this skill for copy to another Mac (zip next to skill dir).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$HOME/Desktop/fujifilm-apeos-mac-print.zip}"
cd "$(dirname "$ROOT")"
zip -r "$OUT" "$(basename "$ROOT")" \
  -x '*.DS_Store' -x '*/__pycache__/*'
ls -lh "$OUT"
echo "Copy zip to other Mac, unzip into ~/.cursor/skills/, then:"
echo "  sudo ~/.cursor/skills/fujifilm-apeos-mac-print/scripts/install.sh <PRINTER_IP>"
