# Windrose Captain's Chest v2.0.0

**Complete rebuild.** Hardware diagnostics are gone. Shipwright is in. The tool now does exactly two things: diagnose your connection, and manage your dedicated server.

## What changed

Captain's Chest has been rebuilt from scratch around the one thing that actually causes Windrose issues: networking.

Hardware diagnostics are gone entirely. No GPU/CPU/RAM info, no dxdiag, no VCRuntime check, no Seaworthy spec comparison. The tool is faster, shorter, and focused.

## Three modes

**ConnectionTrouble** (the 90% case)
ISP detection and culprit matching, full fleet endpoint check (all 8 endpoints, dual DNS), Windows Firewall state, game install and version, file salvage, crash log scan.

**CantReachServer**
Everything in ConnectionTrouble plus DNS resolution, ping, detailed TCP port test, and traceroute to a target IP.

**Shipwright**
Dedicated server setup and save management:
- **Setup** - finds your game install, copies WindroseServer to a location you choose, warns if you pick a path inside the game folder (per the official docs), runs the server once to generate config, then lets you set name/players/region/password interactively.
- **Save transfer** - moves worlds between your local game and a dedicated server. Backs up both sides before touching anything. Validates the World ID triple-match after transfer and updates ServerDescription.json automatically.
- **Validate config** - read-only check of all three World IDs that must match. Tells you if the server is pointing at a world that doesn't exist (which causes it to generate a fresh world on every start).

## New: TROUBLESHOOTING.md

A 22-section manual reference that mirrors every check the script runs. Each section has a plain English explanation of what it's checking and why, the exact PowerShell command to paste, and what good vs bad output looks like. Ends with the full ISP culprit table.

For users who want to run checks individually without downloading or running the script.

## Download

1. Grab **CaptainsChest-v2.0.0.zip** below
2. Extract anywhere
3. Double-click `CaptainsChest.exe` - SmartScreen "More info" > "Run anyway", then UAC > Yes

## Antivirus note

Compiled with ps2exe. Windows Defender may flag it as a false positive. Source `.ps1` is in the same zip for inspection.

## See also

- [Changelog](https://github.com/1r0nch3f/Windrose-Captain-Chest/blob/main/CHANGELOG.md) - full release history
- [Issues](https://github.com/1r0nch3f/Windrose-Captain-Chest/issues) - report bugs or add your ISP to the culprit table

Fair winds, Captain.
