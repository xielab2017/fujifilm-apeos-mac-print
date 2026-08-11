---
name: fujifilm-apeos-mac-print
description: >-
  Installs and configures FUJIFILM Apeos C2060 printing on macOS (Apple Silicon):
  MacOS-26.dmg driver, Rosetta filter wrapper, GBK LPD backend for Chinese job
  names, Auto/tray paper source, and test PDF. Use when setting up Fujifilm/Apeos
  printers on Mac, fixing 乱码 job titles, 024-965/024-951 paper errors, LPD
  print, or cloning this printer setup to another Mac.
---

# Fujifilm Apeos macOS print setup

Portable skill for **FUJIFILM Apeos C2060** (and same FF Print Driver v2.6 stack).

## When to run

User asks to: add Apeos/Fujifilm printer on Mac, install `MacOS-26.dmg`, fix panel **乱码**, fix **缺纸/024-965/024-951**, or **clone setup to another Mac**.

## Defaults

| Item | Value |
|------|--------|
| IP | `10.16.187.200` (override with arg/env) |
| Queue | `FUJIFILM_Apeos_C2060` |
| Protocol | `lpdgbk://` (LPD + GBK job title) |
| Driver | `assets/MacOS-26.dmg` → FF Print Driver v2.6 |
| Paper | A4, `InputSlot=Auto` |
| Test PDF | `assets/test-print.pdf` |

Vendor rule: use **LPD** with FF PPD (not IPP/Socket for the proprietary driver).

## Agent workflow

Copy this checklist:

```
- [ ] Confirm IP reachable (ping)
- [ ] Run install.sh with sudo (Rosetta + pkg + wrappers + queue)
- [ ] Run print-test.sh
- [ ] If 乱码: verify device-uri is lpdgbk:// and backend exists
- [ ] If 缺纸: hardware/tray — see reference.md (do not keep reprinting)
```

### 1. Install on this Mac

```bash
SKILL="$HOME/.cursor/skills/fujifilm-apeos-mac-print"
sudo "$SKILL/scripts/install.sh" 10.16.187.200
# optional:
# sudo INPUT_SLOT=2ndTray "$SKILL/scripts/install.sh" 10.16.187.200
# SKIP_TEST=1 sudo "$SKILL/scripts/install.sh" 10.16.187.200 MyQueue
```

Needs admin password (osascript/`sudo`): driver pkg, `/Library/Printers/FUJIFILM/Filter`, `/usr/libexec/cups/backend`.

### 2. Test print

```bash
"$SKILL/scripts/print-test.sh"
# or: "$SKILL/scripts/print-test.sh" FUJIFILM_Apeos_C2060 /path/to.pdf
```

Panel job name must be readable Chinese (e.g. `项目承诺书…`), **not** `椤圭洰…`.

### 3. Clone to another Mac

```bash
"$SKILL/scripts/pack.sh" ~/Desktop/fujifilm-apeos-mac-print.zip
# On other Mac:
#   unzip into ~/.cursor/skills/fujifilm-apeos-mac-print
#   sudo ~/.cursor/skills/fujifilm-apeos-mac-print/scripts/install.sh <IP>
```

Or copy the whole skill folder (includes DMG + test PDF + sources).

## What the install fixes

1. **Apple Silicon + vendor x86 filter** → arm64 wrapper `exec arch -x86_64 FFACMMCFilter.bin` (CUPS sandbox cannot use bash wrappers).
2. **CN panel 乱码** → custom `lpdgbk` backend encodes LPD `J`/`N` as **GBK** (UTF-8 misread as GBK → `椤圭洰`).
3. **Forced Tray1 empty** → PPD `InputSlot Auto` + default Auto (override with `INPUT_SLOT`).
4. **One queue** → avoid duplicate IPP + LPD queues fighting each other.

## Do not

- Use IPP with the FF PPD (vendor: LPD only for that driver).
- Keep reprinting when SNMP/IPP reports `media-empty` / tray level 0.
- Leave multiple queues to the same IP.

## More

- Troubleshooting codes & tray checks: [reference.md](reference.md)
