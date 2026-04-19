# 🏴‍☠️ Windrose Captain's Chest v1.0.0

*"A sturdy chest for any Windrose captain — full of logs, charts, and soundings."*

First stable release. One standalone PowerShell script that gathers everything you'd want to know about a Windrose crew's rig into a single pasteable report.

## 📥 Quick start

1. Download **CaptainsChest-v1.0.0.zip** below
2. Extract it anywhere
3. Right-click `CaptainsChest.ps1` → **Run with PowerShell**
4. Pick a mode, follow the prompts
5. Find your sealed chest on the Desktop under `WindroseCaptainChest/`

If PowerShell blocks the script:
```powershell
powershell -ExecutionPolicy Bypass -File .\CaptainsChest.ps1
```

## ⚓ What it checks

- **Ship's papers** — OS, CPU, RAM, GPU (with driver age warning)
- **Seaworthy check** — compares yer ship against Windrose's minimum and recommended specs (CPU, RAM, GPU tier, DirectX, disk space, SSD detection)
- **Soundings** — network adapters, local IP, public IP via three-endpoint fallback
- **Hold inventory** — auto-finds Windrose installs across every Steam library, copies configs and logs
- **Watch posts** — firewall profiles and Steam/Windrose rules
- **Crew roster** — running Steam/Windrose processes
- **Man overboard** — recent Application log errors
- **Spyglass** — optional remote server reachability (DNS, ping, TCP, port presets, tracert)

## 📋 Specs checked against

| Spec | Minimum | Recommended |
|---|---|---|
| OS | Windows 10 64-bit | Windows 11 64-bit |
| CPU | Intel i7-8700K / AMD Ryzen 7 2700X | Intel i7-10700 / AMD Ryzen 7 5800X |
| RAM | 16 GB | 32 GB |
| GPU | NVIDIA GTX 1080 Ti / AMD RX 6800 | NVIDIA RTX 3080 / AMD RX 6800 XT |
| DirectX | 12 | 12 |
| Storage | 30 GB (SSD recommended) | 30 GB (SSD required) |

*Source: windrosewiki.org/requirements. Windrose is in Early Access; numbers subject to change.*

## 📤 Output

Every run creates a timestamped chest on your Desktop containing:

- `CaptainsLog.txt` — full human-readable report
- `CaptainsLog.md` — Discord-pasteable markdown findings table
- `Manifest.csv` — PASS/WARN/FAIL/INFO findings in a spreadsheet
- `Salvage/` — copied game configs and logs
- `Chest_<timestamp>.zip` — everything sealed for transport

## 🔒 Privacy heads-up

The report contains your computer name, username, local/public IPs, MAC addresses, and file paths. Review `CaptainsLog.txt` before posting it anywhere public.

## ⚙️ Requirements

- Windows 10 or 11
- PowerShell 5.1 or 7+
- No external modules. No installs. Single file.

---

Fair winds, Captain. 🏴‍☠️
