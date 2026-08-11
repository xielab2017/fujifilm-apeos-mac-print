# Fujifilm Apeos macOS Print Skill

Cursor Agent skill + installer for **FUJIFILM Apeos C2060** on Apple Silicon Macs.

## Quick install

```bash
git clone git@github.com:xielab2017/fujifilm-apeos-mac-print.git ~/.cursor/skills/fujifilm-apeos-mac-print
sudo ~/.cursor/skills/fujifilm-apeos-mac-print/scripts/install.sh 10.16.187.200
```

Or unzip a release and run the same `install.sh`.

## What it fixes

- Official `MacOS-26.dmg` driver (FF Print Driver v2.6)
- Apple Silicon Rosetta wrapper for the vendor x86 CUPS filter
- `lpdgbk` backend so Chinese job titles show correctly on CN panels (not `椤圭洰…`)
- Auto paper tray + A4 defaults
- Bundled test PDF: 项目承诺书（青年项目A类）

## Docs

See [`SKILL.md`](SKILL.md) (agent instructions) and [`reference.md`](reference.md) (troubleshooting).
