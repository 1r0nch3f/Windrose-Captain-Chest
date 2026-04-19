# 🏴‍☠️ Windrose Captain's Chest v1.0.4

One more detection bug fix — found while testing v1.0.3.

## 🔧 What's fixed

- **Storage check was hitting C: instead of the Windrose drive.** On setups where Steam is on one drive and the game library on another, the storage check was defaulting to C: instead of using the install drive.
- **Custom Steam library folders weren't being detected** by the drive-scan fallback. A PowerShell array-literal syntax bug was turning what should have been four path candidates into one malformed argument list. Classic PowerShell gotcha.
- **GPU VRAM still showing 4GB on cards with more than 4GB.** The v1.0.1 registry fallback was looking in the wrong registry location. Now queries three different locations, with the primary one being the standard Windows video adapter config (`HKLM:\SYSTEM\CurrentControlSet\Control\Video`). Cards like the RX 7900 XTX (24GB) should now report their actual VRAM.

With these fixes, install detection should now work reliably on:
- Steam installed to default location, game in default library ✅
- Steam on C:, library on F: (or any other drive) ✅
- Manually created SteamLibrary folders not yet registered with Steam ✅
- Large GPUs (anything >4GB VRAM) ✅

## 📥 Quick start

Same as before — download `CaptainsChest-v1.0.4.zip`, extract, double-click the exe, accept SmartScreen/UAC, pick a mode.

All features from v1.0.0 through v1.0.3 included:
- Hardware + network + game diagnostic
- Seaworthy check against Windrose min/recommended specs
- Public IP lookup
- GPU driver age check
- Windrose port presets
- Redacted report option for safe Discord sharing

See the [full changelog](https://github.com/1r0nch3f/Windrose-Captain-Chest/blob/main/CHANGELOG.md) for release history.
