# 🏴‍☠️ Windrose Captain's Chest

> *"A sturdy chest for any Windrose captain — full of logs, charts, and soundings to hand the port authority when things go sideways."*

A standalone PowerShell toolkit that gathers everything about your Windrose rig into one pasteable report. Run it once, open the chest, hand the contents to whoever's helping you debug.

## 📥 [Download the latest release →](https://github.com/1r0nch3f/Windrose-Captain-Chest/releases/latest)

---

## What it does

The Chest runs a series of diagnostic checks on your PC and produces a clean report you can share when asking for help:

- **Ship's papers** — OS, CPU, RAM, GPU, driver versions
- **Seaworthy check** — does your rig meet Windrose's minimum and recommended specs?
- **Port authority** — auto-detects your ISP and, if it's on the known-culprit list (Spectrum, Xfinity, Cox, BT, Ziggo, etc.), tells you the exact router security feature to toggle off
- **Fleet check** — probes Windrose's backend services and diagnoses ISP blocking vs DNS spoofing vs IPv6 prioritization vs genuine outage
- **Soundings** — network adapters, local IP, public IP, DNS
- **Hold inventory** — auto-finds your Windrose install, salvages config files and logs
- **Watch posts** — firewall profile, Steam/Windrose rules
- **Crew roster** — running Steam/Windrose processes
- **Man overboard** — recent crashes and errors
- **Spyglass** — optional remote server reachability testing

## What's in the chest after a run

Every run creates a timestamped folder on your Desktop containing:

| File | What it is |
|------|-----------|
| `CaptainsLog.txt` | Full human-readable report |
| `CaptainsLog.md` | Markdown version for pasting into Discord |
| `CaptainsLog_REDACTED.txt` | Same as above, **with personal data scrubbed** — safe to post publicly |
| `CaptainsLog_REDACTED.md` | Redacted markdown version |
| `Manifest.csv` | PASS/WARN/FAIL findings in spreadsheet form |
| `Salvage/` | Copies of your Windrose Config, SaveProfiles, and log files |
| `...zip` | Everything sealed for transport |

## Who's this for

- **Windrose players** hitting connection issues, crashes, or performance problems
- **Server hosts** helping crew members diagnose "why can't I connect?"
- **Anyone curious** whether their rig meets spec before buying the game

## Why should I trust it

- Open source — every line is in the repo, inspect it before running
- Read-only — it gathers info, it doesn't change anything on your system
- No network transmission — everything stays on your machine unless you choose to share the report
- The source `.ps1` ships alongside the compiled `.exe` in every release so you can verify they match

## Next steps

- 📖 **[Usage](Usage)** — how to run it, what each mode does
- 🛠️ **[Troubleshooting](Troubleshooting)** — SmartScreen, antivirus, common problems
- 💻 **[Latest release](https://github.com/1r0nch3f/Windrose-Captain-Chest/releases/latest)** — download the exe
- 🐛 **[Issues](https://github.com/1r0nch3f/Windrose-Captain-Chest/issues)** — report bugs or request features
