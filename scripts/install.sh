#!/bin/bash
# Fujifilm Apeos C2060 macOS install (Apple Silicon + CN panel).
# Usage:
#   sudo ./install.sh [PRINTER_IP] [QUEUE_NAME]
# Env:
#   DRIVER_DMG=path/to/MacOS-26.dmg
#   INPUT_SLOT=Auto|1stTray|2ndTray|BypassTray   (default Auto)
#   SKIP_TEST=1
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IP="${1:-${PRINTER_IP:-10.16.187.200}}"
QUEUE="${2:-${QUEUE_NAME:-FUJIFILM_Apeos_C2060}}"
DMG="${DRIVER_DMG:-$ROOT/assets/MacOS-26.dmg}"
INPUT_SLOT="${INPUT_SLOT:-Auto}"
PPD_SRC="/Library/Printers/PPDs/Contents/Resources/FF Print Driver for Mac OS X.gz"
FILTER="/Library/Printers/FUJIFILM/Filter/FFACMMCFilter"
FILTER_BIN="/Library/Printers/FUJIFILM/Filter/FFACMMCFilter.bin"
BACKEND="/usr/libexec/cups/backend/lpdgbk"
URI="lpdgbk://${IP}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Re-run with sudo (needs admin for driver/filter/backend)."
  exec sudo -E "$0" "$@"
fi

echo "==> target IP=$IP queue=$QUEUE slot=$INPUT_SLOT"

# 1) Rosetta (Apple Silicon)
if [[ "$(uname -m)" == "arm64" ]]; then
  if ! arch -x86_64 /usr/bin/true 2>/dev/null; then
    echo "==> installing Rosetta 2"
    softwareupdate --install-rosetta --agree-to-license
  else
    echo "==> Rosetta OK"
  fi
fi

# 2) Vendor driver pkg from DMG
if [[ ! -f "$PPD_SRC" ]]; then
  [[ -f "$DMG" ]] || { echo "missing driver DMG: $DMG"; exit 1; }
  echo "==> mounting $DMG"
  ATTACH="$(hdiutil attach "$DMG" -nobrowse | awk '/\/Volumes\//{print $NF; exit}')"
  PKG="$(find "$ATTACH" -maxdepth 2 -name '*.pkg' | head -1)"
  [[ -n "$PKG" ]] || { echo "no .pkg in DMG"; exit 1; }
  echo "==> installer $PKG"
  installer -pkg "$PKG" -target /
  hdiutil detach "$ATTACH" >/dev/null || true
else
  echo "==> FF PPD already present"
fi
[[ -f "$PPD_SRC" ]] || { echo "PPD still missing after install"; exit 1; }

# 3) Preserve original x86 filter once, install arm64 Rosetta wrapper
if [[ -f "$FILTER" ]]; then
  FT="$(file -b "$FILTER" || true)"
  if [[ "$FT" == *x86_64* && ! -f "$FILTER_BIN" ]]; then
    echo "==> backing up vendor filter -> .bin"
    cp "$FILTER" "$FILTER_BIN"
    chmod 555 "$FILTER_BIN"
  fi
fi
[[ -f "$FILTER_BIN" ]] || { echo "missing $FILTER_BIN (vendor x86 filter)"; exit 1; }

echo "==> building Rosetta filter wrapper"
cc -O2 -arch arm64 -o /tmp/ff_wrap "$ROOT/src/ff_wrap.c"
cp /tmp/ff_wrap "$FILTER"
chmod 555 "$FILTER"
chown root:wheel "$FILTER"

echo "==> building lpdgbk backend (GBK job titles for CN panels)"
cc -O2 -arch arm64 -o /tmp/lpdgbk_bin "$ROOT/src/lpdgbk.c" -liconv
cp /tmp/lpdgbk_bin "$BACKEND"
chmod 700 "$BACKEND"
chown root:wheel "$BACKEND"
launchctl kickstart -k system/org.cups.cupsd 2>/dev/null || true
sleep 1
"$BACKEND" | grep -q lpdgbk

# 4) Queue
echo "==> adding/updating queue $QUEUE -> $URI"
lpadmin -p "$QUEUE" -E \
  -v "$URI" \
  -P "$PPD_SRC" \
  -D "FUJIFILM Apeos C2060" \
  -L "$IP" \
  -o printer-error-policy=retry-job \
  -o printer-is-shared=false || true

PPD="/etc/cups/ppd/${QUEUE}.ppd"
if [[ -f "$PPD" ]]; then
  # Ensure Auto option exists + default slot
  if ! grep -q '\*InputSlot Auto/' "$PPD"; then
    python3 - "$PPD" <<'PY'
import sys
from pathlib import Path
p = Path(sys.argv[1])
t = p.read_text(encoding="latin1")
t = t.replace("*DefaultInputSlot: 1stTray", "*DefaultInputSlot: Auto")
t = t.replace("*DefaultInputSlot: 2ndTray", "*DefaultInputSlot: Auto")
t = t.replace("*DefaultInputSlot: BypassTray", "*DefaultInputSlot: Auto")
if "*InputSlot Auto/" not in t:
    t = t.replace(
        "*DefaultInputSlot: Auto\n*InputSlot 1stTray/",
        '*DefaultInputSlot: Auto\n*InputSlot Auto/Automatically Select: ""\n*InputSlot 1stTray/',
    )
p.write_text(t, encoding="latin1")
print("ppd patched")
PY
  fi
  # Apply requested default slot
  case "$INPUT_SLOT" in
    Auto|1stTray|2ndTray|3rdTray|4thTray|BypassTray) ;;
    *) echo "bad INPUT_SLOT=$INPUT_SLOT"; exit 1 ;;
  esac
  sed -i '' "s/^\*DefaultInputSlot:.*/\*DefaultInputSlot: ${INPUT_SLOT}/" "$PPD"
fi

lpoptions -d "$QUEUE"
lpoptions -p "$QUEUE" -o PageSize=A4 -o "InputSlot=${INPUT_SLOT}" -o MediaType=Default
cupsenable "$QUEUE"
cupsaccept "$QUEUE"

echo "==> installed"
lpstat -p -d -v | sed -n "1,20p"

if [[ "${SKIP_TEST:-0}" != "1" ]]; then
  echo "==> test print (Chinese title via GBK LPD)"
  "$ROOT/scripts/print-test.sh" "$QUEUE" || true
fi

echo "done. If panel says 缺纸: reseat A4 trays / set tray to A4 普通纸, delete stuck jobs, then retest."
