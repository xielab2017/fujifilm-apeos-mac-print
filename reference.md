# Fujifilm Apeos Mac print — reference

## Architecture (after install)

```
Preview/Word PDF
  → CUPS queue FUJIFILM_Apeos_C2060
  → Filter: FFACMMCFilter (arm64) → arch -x86_64 → FFACMMCFilter.bin
  → Backend: lpdgbk (GBK job title in LPD control file)
  → Printer LPD :515
```

## Error codes

| Code / symptom | Meaning | Action |
|----------------|---------|--------|
| Panel `椤圭洰…` | UTF-8 title decoded as GBK | Need `lpdgbk://` backend; reinstall skill |
| Filter failed / Bad CPU type | x86 filter on arm64 without Rosetta/wrapper | Install Rosetta; ensure C wrapper + `.bin` |
| `024-965` | Tray 1 empty / needed | Load Tray1 or set `INPUT_SLOT=2ndTray`/`Auto` |
| `024-951` | Tray 2 empty / needed | Load Tray2 or change slot |
| SNMP tray level `0` | Sensor empty | Reseat tray, A4 guides, tray paper settings on panel |
| CUPS `media-empty-warning` | Device reports no ready media | Fix paper on device before reprint |

## Verify paper from Mac

```bash
ping -c 2 10.16.187.200
snmpwalk -v1 -c public 10.16.187.200 1.3.6.1.2.1.43.8.2.1.10   # levels
snmpwalk -v1 -c public 10.16.187.200 1.3.6.1.2.1.43.8.2.1.13   # tray names
ipptool -tv ipp://10.16.187.200/ipp/print get-printer-attributes.test \
  | grep -iE 'media-ready|printer-state-reasons'
```

Levels must be **> 0** (or bypass loaded) before blaming the driver.

## Panel tray settings (device)

For each tray with paper: **A4 / 普通纸 / 白色** (job asks ~60–79 g/m² plain).  
Push tray fully in until it clicks.

## Useful commands

```bash
lpstat -p -d -v
lpoptions -p FUJIFILM_Apeos_C2060 -l | grep InputSlot
cancel -a FUJIFILM_Apeos_C2060
cupsenable FUJIFILM_Apeos_C2060
```

## Files installed on system

| Path | Role |
|------|------|
| `/Library/Printers/PPDs/.../FF Print Driver for Mac OS X.gz` | Vendor PPD |
| `/Library/Printers/FUJIFILM/Filter/FFACMMCFilter.bin` | Original x86 filter |
| `/Library/Printers/FUJIFILM/Filter/FFACMMCFilter` | arm64 Rosetta wrapper |
| `/usr/libexec/cups/backend/lpdgbk` | GBK LPD backend |
| `/etc/cups/ppd/FUJIFILM_Apeos_C2060.ppd` | Queue PPD (Auto slot patched) |

## Reinstall / change IP

```bash
sudo QUEUE_NAME=FUJIFILM_Apeos_C2060 \
  ~/.cursor/skills/fujifilm-apeos-mac-print/scripts/install.sh NEW.IP.HERE
```

## Assets in this skill

- `assets/MacOS-26.dmg` — vendor installer
- `assets/test-print.pdf` — 项目承诺书（青年项目A类） test file
- `src/ff_wrap.c`, `src/lpdgbk.c` — rebuildable wrappers
