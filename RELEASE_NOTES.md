# 🏴‍☠️ Windrose Captain's Chest v1.0.5

Two final polishes from real-world testing. Fixes applied to spots where the fix from v1.0.4 was present but being bypassed.

## 🔧 What's fixed

- **Seaworthy GPU now reports correct VRAM.** The v1.0.4 VRAM registry lookup was working — but the Seaworthy section was reading WMI directly instead of using it. Large cards (RX 7900 XTX, RTX 3080+, etc.) now show their real VRAM in the spec comparison line.
- **Storage check now actually uses the install drive.** PowerShell's scalar-vs-array gotcha was making the "is the install list empty?" check fail, so the code was falling through to the C: default. Now properly handles single-item arrays.

## 📥 Quick start

Download `CaptainsChest-v1.0.5.zip`, extract, double-click the exe, accept SmartScreen/UAC, pick a mode.

See the [full changelog](https://github.com/1r0nch3f/Windrose-Captain-Chest/blob/main/CHANGELOG.md) for release history.
