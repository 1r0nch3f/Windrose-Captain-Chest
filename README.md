# 🏴‍☠️ Windrose Captain's Chest

> *"A sturdy chest for any Windrose captain — full of logs, charts, and soundings to hand the port authority when things go sideways."*

A standalone PowerShell toolkit that gathers everything you'd want to know about a Windrose crew's rig in one pasteable report. Run it once, open the chest, hand the contents to whoever's helping you debug.

---

## ⚓ What's in the chest

**Ship's papers**
- Windows version, build, architecture
- CPU (model, cores, clock)
- RAM (total GB)

**Crow's nest (GPU)**
- Name, driver version, VRAM
- Driver date and **age warning** — flags drivers over 6 months (INFO) or 12 months (WARN)

**Soundings (network)**
- Adapters, link speed, IP config, route table
- Home waters (local network profile: Public vs Private)
- **Flag on the mast** — public IP via three fallback endpoints
- Beacons to Steam, Cloudflare, and Google to confirm the sea lanes are open
- Hosts file contents

**Hold inventory (Windrose / Steam)**
- Auto-finds Windrose installs across every Steam library folder (parses `libraryfolders.vdf`)
- Hull markings — executable versions for `Windrose*.exe` / `R5*.exe`
- Salvages `Config/`, `SaveProfiles/`, `ServerDescription.json`, and up to 50 log files
- Watch posts — Steam/Windrose firewall application filters
- Crew roster — running Steam/Windrose processes
- Man overboard — recent Application log errors tagged Windrose/Steam/crash
- Powder magazine — installed Visual C++ runtimes

**Spyglass (optional remote soundings)**
- DNS resolution (if target is a hostname)
- Cannon shot — ICMP ping with average latency
- Boarding party — TCP port test on your specified port
- **Sounding the harbor** — auto-probes common ports 7777, 7778, 27015, 27036
- Ship's log — trace route (skippable)
- A straight note on UDP: PowerShell can't positively confirm UDP is open from the client side

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
| `Manifest.csv` | PASS/WARN/FAIL/INFO findings, one per row |
| `Salvage/` | Recovered game configs and logs |
| `...zip` | The whole chest sealed for transport, next to the folder |

---

## 🧭 Usage

### Hoist sail (interactive)

Right-click the script → **Run with PowerShell**, or from a PowerShell window:

```powershell
.\CaptainsChest.ps1
```

You'll be prompted to chart a course:

1. **Full voyage** — ship, shore, and sound out a distant port
2. **Quick sweep** — ship info and a quick port test
3. **Stay ashore** — ship and shore only, no remote soundings

### Non-interactive (scripted)

```powershell
.\CaptainsChest.ps1 -Mode Full -ServerIP 1.2.3.4 -ServerPort 7777 -NoPause
.\CaptainsChest.ps1 -Mode LocalOnly -NoPause
.\CaptainsChest.ps1 -Mode Full -ServerIP crew.example.com -SkipTraceRoute -NoPause
```

### Parameters

| Parameter | Description | Default |
|---|---|---|
| `-OutputPath` | Where to drop the chest | `$env:USERPROFILE\Desktop\WindroseCaptainChest` |
| `-ServerIP` | Server IP or hostname to sound | prompted |
| `-ServerPort` | Port to test | `7777` |
| `-Mode` | `Full`, `Quick`, `LocalOnly` | prompted |
| `-SkipTraceRoute` | Skip tracert (saves ~30s) | off |
| `-SkipNetworkTests` | Skip all remote tests and public IP lookup | off |
| `-NoPause` | Don't wait for Enter at the end | off |

---

## 🔒 Execution policy

If PowerShell refuses to run the script, hoist the bypass flag:

```powershell
powershell -ExecutionPolicy Bypass -File .\CaptainsChest.ps1
```

Or unblock the file once after downloading:

```powershell
Unblock-File .\CaptainsChest.ps1
```

---

## 👮 Admin rights

Not required, but **recommended**. Without admin you'll miss some firewall rule details and a chunk of event log entries. The report tells you its admin state up top so the dockmaster knows what's in the manifest.

---

## 🕵️ A word on privacy

The report contains:

- Your computer name and username
- Your local and public IP addresses
- Hardware identifiers (MAC addresses, GPU names)
- File paths on your machine
- Hosts file contents

Give `CaptainsLog.txt` a once-over before posting it in a public channel. If you need to scrub anything, the markdown summary (`CaptainsLog.md`) is usually enough for most troubleshooting without handing over the full log.

---

## 🎯 Port presets

Tested by default whenever you supply a target. Edit the `$script:WindrosePortPresets` block at the top of the script if yer charts differ.

| Port | Protocol | Purpose |
|---|---|---|
| 7777 | UDP/TCP | Default game port |
| 7778 | UDP | Secondary game port |
| 27015 | UDP/TCP | Steam query / master |
| 27036 | UDP/TCP | Steam streaming / P2P |

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
