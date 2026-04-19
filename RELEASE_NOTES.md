# 🏴‍☠️ Windrose Captain's Chest v1.0.3

Bug-fix release — cleans up issues introduced in v1.0.1's install-detection code.

## 🔧 What's fixed

- **Doubled install paths** like `F:\SteamLibrary\steamapps\common\WindroseF:\SteamLibrary\steamapps\common\Windrose`. Proper case-insensitive dedupe + path normalization via `Resolve-Path`.
- **Storage check showing empty drive letter** ("Could not read drive :"). Now uses a regex to extract a valid drive letter from install paths, falls back to C: if parsing fails.
- **`Windrose.exe` not detected** even when obviously present. Was a side-effect of the doubled-path bug feeding `Get-ChildItem` a non-existent path.

## 📥 Quick start

Same as before — download `CaptainsChest-v1.0.3.zip`, extract, double-click the exe, accept SmartScreen/UAC, pick a mode.

Includes all features from v1.0.0 through v1.0.2:
- Consolidated hardware + network + game diagnostic
- Seaworthy check against Windrose min/recommended specs
- Public IP lookup
- GPU driver age check
- Windrose port presets
- **Redacted report option** (v1.0.2) — strips personal data for safe Discord sharing

See the [full changelog](https://github.com/1r0nch3f/Windrose-Captain-Chest/blob/main/CHANGELOG.md) for release history.

## ⚠️ Antivirus note

Same as previous releases: the exe is compiled with `ps2exe` which Defender sometimes flags as a false positive. The source `.ps1` is in the zip if you'd rather inspect and run it directly.
