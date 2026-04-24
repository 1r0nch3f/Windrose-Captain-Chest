# 🏴‍☠️ Windrose Captain's Chest

> *"A sturdy chest for any Windrose captain — full of logs, charts, and soundings to hand the port authority when things go sideways."*

A standalone PowerShell toolkit focused on the one thing that actually causes Windrose issues: networking. Run it once, open the chest, hand the contents to whoever's helping you debug.

Two tools ship together:

| Tool | What it does | When to use it |
|------|-------------|----------------|
| `CaptainsChest.exe` / `.ps1` | Full diagnostic — hardware, network, live session profile, crew invite | Troubleshooting connection issues |
| `CaptainsSignal.ps1` | Lightweight — reads server config, checks live network, prints crew invite | Every time you host |

---

## ⚓ What's in the chest

### Ship's papers
- Windows version, build, architecture
- CPU (model, cores, clock), RAM (total GB)
- GPU name, driver version, VRAM, driver age warning

### Seaworthy check
Compares your rig against Windrose's minimum and recommended specs:
- **OS** — Win10 (min) / Win11 (recommended)
- **CPU** — cores and clock speed vs i7-8700K (min) / i7-10700 (rec)
- **RAM** — 16 GB (min) / 32 GB (rec)
- **GPU** — tiered lookup covering NVIDIA/AMD cards from GTX 900-series through RTX 50-series and RX 9000
- **DirectX** — queries `dxdiag` for the version (needs DX12)
- **Storage** — checks free space on the Windrose install drive, 30 GB required
- **SSD detection** — warns if your game drive is an HDD

### Soundings (network)
- Adapters, link speed, IP config, route table
- Network profile (Public vs Private — Public is stricter)
- Public IP via three fallback endpoints
- Beacons to Steam, Cloudflare, and Google

### Fleet check
Probes all 8 Windrose backend endpoints and tells you whether unreachable services are an ISP block or a dev-side outage:
- `r5coopapigateway-eu-release.windrose.support` + `-2` failover (EU/NA)
- `r5coopapigateway-ru-release.windrose.support` + `-2` failover (CIS)
- `r5coopapigateway-kr-release.windrose.support` + `-2` failover (SEA)
- `sentry.windrose.support` (error reporting)
- `windrose.support:3478` (STUN/TURN P2P signaling)

ISP detection auto-identifies your provider and tells you exactly which router security feature to toggle off if it's the culprit (Spectrum Security Shield, Xfinity xFi Advanced Security, BT Web Protect, etc.).

### Crow's nest — live network profile *(new in v2.1.0)*
When Windrose is running during a chest run, snapshots the live TCP/UDP connections from `Windrose-Win64-Shipping` and analyses them:
- **Backend contacts** — which of the three regions the game actually reached
- **UDP pool** — counts P2P sockets open and ready for incoming peers
- **Hosting mode** — Direct IP (port 7777) vs invite code
- **Firewall rule check** — catches the case where you hit Cancel on the Windows Security prompt during Direct IP hosting

### Send to crew — ready-to-copy invite *(new in v2.1.0)*
Generates formatted invite messages you can paste straight into text, iMessage, WhatsApp, or Discord. The invite code is read automatically from the game's own config file.

```
--- Copy this (text / iMessage / WhatsApp) ---
Hey! Join my Windrose server: Windrose Server (max 4)
Invite code: 4e18908b
In-game: Join a Game > Enter Code
See you on deck!

--- Copy this (Discord) ---
**Join my Windrose server - Windrose Server (max 4)!**
Go to **Join a Game > Enter Code** and use:
`4e18908b`
See you on deck!
```

Works for both invite code and Direct IP mode. Includes the server password in the message when one is set. Public IP warning included for Direct IP hosts.

### Hold inventory
- Auto-finds Windrose installs across every Steam library folder
- Executable versions, salvaged configs, SaveProfiles, ServerDescription.json, logs
- Steam/Windrose firewall rules, running processes, recent crash errors
- Visual C++ runtimes

### Spyglass (optional)
- DNS resolution, ping, TCP port test, port presets, traceroute

---

## 🚦 CaptainsSignal — quick crew invite

Run this while Windrose is hosting. No log files, no hardware scan, just the invite.

```powershell
Set-ExecutionPolicy -Scope Process Bypass
& ".\CaptainsSignal.ps1"
```

Output:

```
=== Reading server config ===
[PASS] Config found: F:\SteamLibrary\steamapps\common\Windrose\R5\ServerDescription.json
  Server name:  Windrose Server
  Max players:  4  |  Region: EU  |  Direct IP: False

=== Live network check ===
[PASS] Backend: 3 connection service contact(s) detected
[PASS] UDP pool: 12 sockets open (59935-59946) - peer connections ready
[PASS] Firewall: Windrose application rule present

=== Send to crew ===
--- Copy this (text / iMessage / WhatsApp) ---
Hey! Join my Windrose server: Windrose Server (max 4)
Invite code: 4e18908b
In-game: Join a Game > Enter Code
See you on deck!
```

---

## 🗺️ Output (CaptainsChest)

Every run creates a timestamped chest at:

```
%USERPROFILE%\Desktop\WindroseCaptainChest\yyyy-MM-dd_HH-mm-ss\
```

| File | Purpose |
|------|---------|
| `CaptainsLog.txt` | Full human-readable report |
| `CaptainsLog.md` | Markdown findings table — paste straight into Discord |
| `CaptainsLog_REDACTED.txt` | Safe-to-share copy with hostname/username/IPs/MACs/password scrubbed |
| `CaptainsLog_REDACTED.md` | Safe-to-share markdown version |
| `Manifest.csv` | PASS/WARN/FAIL/INFO findings, one per row |
| `Salvage/` | Recovered game configs and logs |
| `...zip` | The whole chest sealed for transport |

At the end of every run you'll be asked whether to create the redacted copies. Post those (not the full log) when asking for help in public channels.

---

## 🧭 Usage

### Hoist sail (easiest — compiled exe)

Double-click `CaptainsChest.exe`.

On first run you'll see a few Windows prompts. This is normal for unsigned community tools:

1. **Windows Defender SmartScreen** — click **More info** then **Run anyway**
2. **User Account Control (UAC)** — click **Yes** (admin is needed for firewall and event log access)
3. The pirate banner appears — pick your mode and follow the prompts

### Why does SmartScreen or my antivirus complain?

The exe is a PowerShell script compiled with `ps2exe`. Some AV products flag `ps2exe` output as a false positive. If you don't want to trust the exe, don't. The source `CaptainsChest.ps1` is in the same zip. Open it in Notepad, read every line, and run it directly:

```powershell
powershell -ExecutionPolicy Bypass -File .\CaptainsChest.ps1
```

Or unblock it once and right-click → Run with PowerShell will work from then on:

```powershell
Unblock-File .\CaptainsChest.ps1
```

### Picking a mode

| Mode | What it does |
|------|-------------|
| Full voyage | Hardware, network, live profile, sound out a remote port |
| Quick sweep | Hardware, network, live profile, quick port test |
| Stay ashore | Hardware and network only, no remote soundings |

### Non-interactive (scripted)

```powershell
.\CaptainsChest.exe -Mode Full -ServerIP 1.2.3.4 -ServerPort 7777 -NoPause
.\CaptainsChest.exe -Mode LocalOnly -NoPause
.\CaptainsChest.exe -Mode Quick -SkipTraceRoute -Redact -NoPause
```

### Parameters

| Parameter | Description | Default |
|---|---|---|
| `-OutputPath` | Where to drop the chest | `Desktop\WindroseCaptainChest` |
| `-ServerIP` | Server IP or hostname to sound | prompted |
| `-ServerPort` | Port to test | `7777` |
| `-Mode` | `Full`, `Quick`, `LocalOnly` | prompted |
| `-SkipTraceRoute` | Skip tracert (saves ~30s) | off |
| `-SkipNetworkTests` | Skip all remote tests and public IP lookup | off |
| `-NoPause` | Don't wait for Enter at the end | off |
| `-Redact` | Auto-create redacted copy without prompting | off |
| `-NoRedactPrompt` | Skip the redacted-copy prompt entirely | off |
| `-SkipServiceCheck` | Skip the Fleet check entirely | off |

---

## 👮 Admin rights

- **Running the `.exe`**: automatically prompts for admin via UAC. Click Yes.
- **Running the `.ps1` directly**: not required but recommended. Without admin you'll miss some firewall rule details and event log entries.
- **CaptainsSignal.ps1**: needs admin to read live network connections from `Get-NetTCPConnection` and `Get-NetUDPEndpoint`.

---

## 🕵️ Privacy

The report contains your computer name, username, local and public IP, MAC addresses, hardware identifiers, and file paths. The redacted version scrubs all of these plus any server password you have set.

Give `CaptainsLog.txt` a once-over before posting publicly. When asking for help in Discord, post the `_REDACTED` version.

---

## 🎯 Port presets

| Port | Protocol | Purpose |
|---|---|---|
| 7777 | UDP/TCP | Default game port and Direct IP host mode |
| 7778 | UDP | Secondary game port |
| 27015 | UDP/TCP | Steam query / master |
| 27036 | UDP/TCP | Steam streaming / P2P |

---

## 📋 Windrose system requirements

| Spec | Minimum | Recommended |
|---|---|---|
| OS | Windows 10 (64-bit) | Windows 11 (64-bit) |
| CPU | Intel i7-8700K / AMD Ryzen 7 2700X | Intel i7-10700 / AMD Ryzen 7 5800X |
| RAM | 16 GB | 32 GB |
| GPU | NVIDIA GTX 1080 Ti / AMD RX 6800 | NVIDIA RTX 3080 / AMD RX 6800 XT |
| DirectX | 12 | 12 |
| Storage | 30 GB (SSD recommended) | 30 GB (SSD required) |

---

## ⚙️ Requirements

- Windows 10 or 11
- PowerShell 5.1 or PowerShell 7+
- Internet connectivity (for public IP lookup and remote tests)

No external modules. No installs. Single file.

---

## 🤝 Contributing

Issues and pull requests welcome. If the port presets drift or the Windrose directory layout changes, the relevant blocks are clearly marked at the top of the script.

---

## 📜 License

MIT — see [LICENSE](LICENSE). Fair winds.
