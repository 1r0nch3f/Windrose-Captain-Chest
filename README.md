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

**Seaworthy check ⚓**
- Compares yer ship against Windrose's minimum and recommended specs
- **OS** — 64-bit check, Win10 (min) / Win11 (recommended)
- **CPU** — cores and clock speed vs i7-8700K (min) / i7-10700 (rec)
- **RAM** — 16 GB (min) / 32 GB (rec)
- **GPU** — tiered lookup table covering NVIDIA/AMD cards from GTX 900-series through RTX 50-series and RX 9000, with a "manual review" fallback for unknown cards
- **DirectX** — queries `dxdiag` for the version (needs DX12)
- **Storage** — checks free space on the Windrose install drive (or C: if not installed), 30 GB required
- **SSD detection** — warns if yer game drive is an HDD (Windrose strongly recommends SSD)

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
| `CaptainsLog_REDACTED.txt` | **Safe-to-share** copy with hostname/username/IPs/MACs scrubbed |
| `CaptainsLog_REDACTED.md` | Safe-to-share markdown version |
| `Manifest.csv` | PASS/WARN/FAIL/INFO findings, one per row |
| `Salvage/` | Recovered game configs and logs |
| `...zip` | The whole chest sealed for transport, next to the folder |

At the end of every run, you'll be asked whether to create the redacted copies. Post those (not the full log) when asking for help in public channels — they keep all the diagnostic data a helper needs while hiding your hostname, public IP, MAC addresses, and file paths behind `<REDACTED_*>` placeholders.

---

## 🧭 Usage

### Hoist sail (easiest — compiled exe)

Double-click `CaptainsChest.exe`.

On first run you'll see a few Windows prompts. **This is normal for unsigned community tools** — work through them and it'll stick for future runs:

1. **Windows Defender SmartScreen** — "Windows protected your PC"
   Click **More info** → **Run anyway**
2. **User Account Control (UAC)** — "Do you want to allow this app to make changes?"
   Click **Yes** (admin is needed for full firewall and event log access)
3. The pirate banner appears — chart yer course and follow the prompts

### ⚠️ Why does SmartScreen / my antivirus complain?

The exe is a PowerShell script compiled with a tool called `ps2exe`. Because some malware authors use the same tool, **Windows Defender and other AV products sometimes flag `ps2exe` output as a false positive**. Typical warnings:

- SmartScreen: "Windows protected your PC" (one-click past it)
- Defender: "Trojan:Win32/Wacatac" (false positive)
- Some AVs may silently quarantine or delete the file

**If you don't want to trust the exe, don't!** The source `CaptainsChest.ps1` is in the same zip. Open it in Notepad, read every line, and if it looks clean, run the `.ps1` directly:

```powershell
powershell -ExecutionPolicy Bypass -File .\CaptainsChest.ps1
```

The source being right there is the point — this is a community tool, not a black box.

### Alternative: run the .ps1 directly

If you'd rather skip the exe entirely:

```powershell
powershell -ExecutionPolicy Bypass -File .\CaptainsChest.ps1
```

Or unblock the file once and right-click → Run with PowerShell will work forever after:

```powershell
Unblock-File .\CaptainsChest.ps1
```

### Picking a mode

You'll be prompted to chart a course:

1. **Full voyage** — ship, shore, and sound out a distant port
2. **Quick sweep** — ship info and a quick port test
3. **Stay ashore** — ship and shore only, no remote soundings

### Non-interactive (scripted)

```powershell
.\CaptainsChest.exe -Mode Full -ServerIP 1.2.3.4 -ServerPort 7777 -NoPause
.\CaptainsChest.exe -Mode LocalOnly -NoPause
.\CaptainsChest.exe -Mode Full -ServerIP crew.example.com -SkipTraceRoute -NoPause
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
| `-Redact` | Auto-create redacted copy without prompting | off |
| `-NoRedactPrompt` | Skip the redacted-copy prompt entirely | off |

---

## 👮 Admin rights

- **Running the `.exe`**: automatically prompts for admin via UAC. Click Yes.
- **Running the `.ps1` directly**: not required, but recommended. Without admin you'll miss some firewall rule details and a chunk of event log entries. The report tells you its admin state up top so the dockmaster knows what's in the manifest.

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
| 7777 | UDP/TCP | Default game port and Direct IP host mode |
| 7778 | UDP | Secondary game port |
| 27015 | UDP/TCP | Steam query / master |
| 27036 | UDP/TCP | Steam streaming / P2P |

---

## 🆘 Direct IP fallback

If Fleet check shows Connection Services are unreachable, Windrose can still be hosted through **Direct IP** mode instead of the backend service path. The report now prints this as a fallback when the backend is fully unreachable or when partial reachability points to 3478 / ISP-side Connection Services trouble.

Use this path in game:

```
Host a Game -> Direct IP tab -> port 7777
```

Then share your public IP with your crew. This bypasses Windrose Connection Services entirely, but it still requires **port 7777** to be open on your router.

## 📋 Windrose system requirements (what Seaworthy checks against)

| Spec | Minimum | Recommended |
|---|---|---|
| OS | Windows 10 (64-bit) | Windows 11 (64-bit) |
| CPU | Intel i7-8700K / AMD Ryzen 7 2700X | Intel i7-10700 / AMD Ryzen 7 5800X |
| RAM | 16 GB | 32 GB |
| GPU | NVIDIA GTX 1080 Ti / AMD RX 6800 | NVIDIA RTX 3080 / AMD RX 6800 XT |
| DirectX | 12 | 12 |
| Storage | 30 GB (SSD recommended) | 30 GB (SSD required) |

The developers note that Windrose is in Early Access and these numbers are **not final**. Self-hosted servers need additional RAM on top. If the game updates its specs, edit `$script:WindroseSpecs` at the top of the script.

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
