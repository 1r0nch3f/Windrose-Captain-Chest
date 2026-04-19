# Changelog

All notable changes to Windrose Captain's Chest will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-04-19

Bug-fix release. Four real-world issues surfaced by first-run testing.

### Fixed

- **OS version now reports correctly on Windows 11.** `Get-ComputerInfo`'s `WindowsProductName` occasionally returns "Windows 10 Pro" on Windows 11 systems. Switched to reading the registry's ProductName and DisplayVersion, cross-referenced with build number (build 22000+ = Win 11).
- **GPU VRAM now reads correctly for cards larger than 4GB.** The WMI `AdapterRAM` field is a 32-bit integer that overflows for modern GPUs (e.g., RX 7900 XTX reporting 4GB instead of 24GB). Added registry fallback via `HKLM:\SOFTWARE\Microsoft\DirectX` which stores VRAM as a 64-bit value.
- **VC++ runtime listing no longer errors on uninstall keys with no DisplayName.** Added a null-safe filter before the name match.
- **Windrose install auto-detection now finds custom Steam library locations.** The old detection only checked the primary Steam install's `libraryfolders.vdf`. The new version: (a) reads Steam's install path from the registry, (b) scans all fixed drives for `SteamLibrary`, `Steam`, `Games\SteamLibrary`, and `Games\Steam` folders, and (c) falls back to parsing existing Windrose firewall rules to locate the install if all else fails.

## [1.0.0] - 2026-04-19

First stable release. A single standalone PowerShell diagnostic for Windrose crews.

### Added

- **Consolidated script** — one `CaptainsChest.ps1` replaces the two earlier scripts (connection checker + diagnostics collector).
- **Ship's papers** — OS, CPU, RAM, and GPU info with VRAM and driver version.
- **GPU driver age check** — flags drivers over 6 months as INFO, over 12 months as WARN.
- **Seaworthy check** — compares yer ship against Windrose's minimum/recommended specs:
  - OS (Windows 10/11 64-bit)
  - CPU (cores + clock vs i7-8700K min / i7-10700 rec)
  - RAM (16 GB min / 32 GB rec)
  - GPU via a tier lookup table covering NVIDIA GTX 900-series through RTX 50-series and AMD RX 400-series through RX 9000-series
  - DirectX version via `dxdiag`
  - Free disk space on the Windrose install drive (or C: fallback)
  - SSD vs HDD detection (Windrose strongly recommends SSD)
- **Public IP lookup** — three-endpoint fallback (ipify → ifconfig.me → icanhazip).
- **Windrose port presets** — auto-probes common ports 7777, 7778, 27015, 27036.
- **Steam library auto-discovery** — parses `libraryfolders.vdf` to find Windrose installs across every Steam library.
- **Salvage collection** — copies `Config/`, `SaveProfiles/`, `ServerDescription.json`, and up to 50 log files from the Saved directory.
- **Firewall rule enumeration** — lists Steam/Windrose application filters.
- **Recent crash log scan** — surfaces Application errors matching Windrose/Steam/R5 patterns.
- **Three run modes** — Full (local + remote), Quick (port test only), LocalOnly (no remote tests).
- **Three output formats** — `CaptainsLog.txt` (human-readable), `CaptainsLog.md` (Discord-pasteable markdown table), `Manifest.csv` (filterable findings list).
- **Sealed chest** — everything auto-zipped with a timestamp.
- **Pirate-themed UI** — ASCII banner, themed section headers ("Crow's nest", "Cannon shot", "Boarding party", etc.).
- **Command-line parameters** — `-ServerIP`, `-ServerPort`, `-Mode`, `-SkipTraceRoute`, `-SkipNetworkTests`, `-NoPause`, `-OutputPath` for automation.
- **One-click `push.bat`** — handles git init, commit, remote setup, and push.
- **One-click `release.bat`** — cuts tagged releases, builds clean distribution zip, optionally publishes to GitHub Releases via `gh` CLI.

### Known limitations

- UDP port testing is inherently limited client-side in plain PowerShell — a closed/filtered UDP port is not conclusive.
- Laptop GPUs are rated the same tier as their desktop counterparts, which is generous. Edit `$script:GpuTierTable` if this affects your crew.
- Specs sourced from windrosewiki.org; Windrose is in Early Access and the devs state these numbers are subject to change.

[1.0.0]: https://github.com/1r0nch3f/Windrose-Captain-Chest/releases/tag/v1.0.0
