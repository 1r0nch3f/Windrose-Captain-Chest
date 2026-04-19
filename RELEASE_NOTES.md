# 🏴‍☠️ Windrose Captain's Chest v1.0.1

Bug-fix release — four issues surfaced during first-run testing.

## 🔧 What's fixed

- **OS version** — Windows 11 systems were being reported as "Windows 10 Pro" due to a quirk in `Get-ComputerInfo`. Now reads from the registry and cross-checks the build number.
- **GPU VRAM** — cards larger than 4GB (RX 7900 XTX, RTX 3080+, etc.) were showing 4GB due to a 32-bit integer overflow in WMI. Now pulls the real value from the DirectX registry.
- **VC++ runtime check** — no longer errors on uninstall registry keys that lack a DisplayName.
- **Windrose auto-detect** — now finds installs in custom Steam library locations (e.g., `F:\SteamLibrary`), not just the primary Steam install. Checks every fixed drive for common library folder names and falls back to reading existing Windrose firewall rules if needed.

## 📥 Quick start

1. Download **CaptainsChest-v1.0.1.zip** below
2. Extract it anywhere
3. Double-click `CaptainsChest.exe` — accept SmartScreen ("More info" → "Run anyway") and the UAC prompt
4. Pick a mode, follow the prompts

### ⚠️ Antivirus note

The exe is compiled with `ps2exe`, which Windows Defender sometimes flags as a false positive. The source `.ps1` is in the zip if you'd rather inspect and run it directly:

```powershell
powershell -ExecutionPolicy Bypass -File .\CaptainsChest.ps1
```

---

See the [full changelog](https://github.com/1r0nch3f/Windrose-Captain-Chest/blob/main/CHANGELOG.md) for details. v1.0.0 release notes apply for what the tool does overall.
