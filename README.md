# 🏴‍☠️ Windrose Captain's Chest

> *"A sturdy chest for any Windrose captain — full of logs, charts, and soundings to hand the port authority when things go sideways."*

A standalone PowerShell toolkit focused on the one thing that actually causes Windrose issues: networking. Run it once, open the chest, hand the contents to whoever's helping you debug.

---

## ⚓ What's in the chest

### Connection Trouble (the 90% case)

- **Port authority** — detects your ISP automatically and matches it against a table of known culprits, telling you exactly which router security feature to toggle off and where to find it
- **Fleet check** — probes all 8 Windrose backend endpoints (dual DNS, TCP) and diagnoses ISP blocks, DNS spoofing, IPv6 issues, or a genuine outage
- **Windows Firewall** — checks active profiles and Windrose/Steam app rules
- **Game install** — finds your Windrose version across all Steam library folders
- **File salvage** — copies `Config/`, `SaveProfiles/`, `ServerDescription.json`, and recent logs
- **Crash log scan** — surfaces recent Application errors tagged Windrose/Steam/R5

### Can't Reach Server

Everything in Connection Trouble, plus:

- **DNS resolution** of the target hostname
- **Ping** — ICMP with average latency
- **TCP port test** — detailed result on your target IP and port
- **Traceroute** — full path to the target

### Shipwright (dedicated server setup)

- **ServerDescription.json** — parses and validates InviteCode length, P2pProxyAddress, region field
- **WorldDescription.json** — checks presence and structure
- **SaveProfiles inventory** — lists profiles with RocksDB path check
- **Port listen test** — confirms the server process is actually listening on 7777, 27015, 27036
- **Firewall rules** — Windrose/Steam application filters
- **Crash logs** — recent server-side errors
- **Full file salvage**

---

## 🗺️ Output

Every run creates a timestamped chest at:

```
%USERPROFILE%\Desktop\WindroseCaptainChest\yyyy-MM-dd_HH-mm-ss\
```

Inside you'll find:

| File | Purpose |
|------|---------|
| `CaptainsLog.txt` | Full human-readable report |
| `CaptainsLog.md` | Markdown findings table — paste straight into Discord |
| `CaptainsLog_REDACTED.txt` | Safe-to-share copy with hostname/username/IPs/MACs scrubbed |
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

Or unblock it once and right-click, Run with PowerShell will work from then on:

```powershell
Unblock-File .\CaptainsChest.ps1
```

### Non-interactive (scripted)

```powershell
.\CaptainsChest.exe -Mode ConnectionTrouble -NoPause
.\CaptainsChest.exe -Mode CantReachServer -ServerIP 1.2.3.4 -ServerPort 7777 -NoPause
.\CaptainsChest.exe -Mode Shipwright -NoPause
```

### Parameters

| Parameter | Description | Default |
|---|---|---|
| `-OutputPath` | Where to drop the chest | `$env:USERPROFILE\Desktop\WindroseCaptainChest` |
| `-ServerIP` | Server IP or hostname to sound | prompted |
| `-ServerPort` | Port to test | `7777` |
| `-Mode` | `ConnectionTrouble`, `CantReachServer`, `Shipwright` | prompted |
| `-SkipTraceRoute` | Skip tracert (saves ~30s) | off |
| `-NoPause` | Don't wait for Enter at the end | off |
| `-Redact` | Auto-create redacted copy without prompting | off |
| `-NoRedactPrompt` | Skip the redacted-copy prompt entirely | off |

---

## 🆘 Direct IP fallback

If Fleet check shows Connection Services are unreachable, Windrose can still be hosted through Direct IP mode. The report prints this as a fallback when the backend is unreachable or when partial reachability points to ISP-side trouble on port 3478.

```
Host a Game -> Direct IP tab -> port 7777
```

Share your public IP with your crew. This bypasses Windrose Connection Services entirely but still requires port 7777 to be open on your router.

---

## 🎯 Port presets

| Port | Protocol | Purpose |
|---|---|---|
| 7777 | UDP/TCP | Default game port and Direct IP host mode |
| 27015 | UDP/TCP | Steam query / master |
| 27036 | UDP/TCP | Steam streaming / P2P |

---

## 📖 Manual reference

Prefer to run checks yourself without the script? See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — 22 sections covering every check the script runs, each with a plain English explanation, exact paste-ready PowerShell command, and guidance on reading the output. Includes the full ISP culprit table.

---

## 👮 Admin rights

Running the exe prompts for admin via UAC automatically. Without admin you'll miss some firewall rule details and event log entries. The report states its admin state at the top so helpers know what's in the manifest.

---

## 🕵️ A word on privacy

The report contains your computer name, username, local and public IP addresses, and file paths. Use the redacted copy when posting in public channels. It keeps all the diagnostic data a helper needs while scrubbing identifying info behind `<REDACTED_*>` placeholders.

---

## ⚙️ Requirements

- Windows 10 or 11
- PowerShell 5.1 or PowerShell 7+
- Internet connectivity (for public IP lookup and remote tests)

No external modules. No installs. Single file.

---

## 🤝 Contributing

Issues and pull requests welcome. If the ISP culprit table needs updating or the Windrose endpoint list changes, the relevant blocks are clearly marked at the top of the script.

---

## 📜 License

MIT — see [LICENSE](LICENSE). Fair winds.
