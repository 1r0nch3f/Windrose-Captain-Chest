# Changelog

All notable changes to Windrose Captain's Chest will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.4] - 2026-04-19

Multiple detection fixes — found while testing v1.0.3.

### Fixed

- **Drive-scan fallback wasn't finding custom Steam libraries.** The array initializer in `Get-SteamLibraries` used comma-separated `Join-Path` calls which PowerShell parsed as one big argument list to the first `Join-Path` instead of four separate expressions. Result: `Test-Path` was called on garbage paths and always returned false. On systems where Steam's own `libraryfolders.vdf` didn't include all libraries (or where the registry lookup failed), this meant no libraries were found at all. Fixed by wrapping each `Join-Path` in parentheses.
- **Storage check was checking C: instead of the Windrose install drive.** Side-effect of the above — since the first call to `Find-WindroseInstall` in `Test-Seaworthy` found no installs, the storage check defaulted to C:. With this fix, the storage check now checks the drive Windrose is actually installed on.
- **GPU VRAM still showing 4GB on large cards.** The v1.0.1 registry fallback was looking in the wrong registry location (`HKLM:\SOFTWARE\Microsoft\DirectX` doesn't have the data on most Windows versions). Now checks three locations in order: `HKLM:\SYSTEM\CurrentControlSet\Control\Video\{GUID}\000X\HardwareInformation.qwMemorySize` (primary), the older DirectX path (fallback), and finally detects UInt32 overflow as a last-resort sentinel.

### Changed

- `Get-SteamLibraries` now uses `System.Collections.Generic.List[string]` instead of raw PowerShell arrays for more predictable behavior.
- `Find-WindroseInstall` result is now cached within a single run so both `Test-Seaworthy` and `Get-GameVersionInfo` always agree.

## [1.0.3] - 2026-04-19

Fix bugs introduced by the install-detection changes in v1.0.1.

### Fixed

- **Doubled install paths.** The firewall-walk detection added in v1.0.1 could produce duplicate entries that weren't deduped properly (e.g., `F:\SteamLibrary\steamapps\common\WindroseF:\SteamLibrary\steamapps\common\Windrose`). Switched to a generic list with explicit case-insensitive HashSet deduplication and path normalization via `Resolve-Path`.
- **Empty drive letter in storage check.** When the install path was garbled (see above), `.Substring(0,1)` could return an empty string, producing "Could not read drive :". Now uses a regex to extract a valid drive letter and falls back to C: if nothing sensible can be parsed.
- **Windrose.exe not detected even when present.** Fallout from the doubled-path bug — `Get-ChildItem` was being handed a non-existent concatenated path. With dedupe fixed this now works.

### Changed

- `Find-WindroseInstall` now always returns a plain `string[]` array (via `@(...)` wrap), preventing PowerShell's automatic unrolling from confusing downstream callers.

## [1.0.2] - 2026-04-19

Privacy feature added — safe-to-share redacted reports.

### Added

- **Redacted report output.** At the end of every run, the script now prompts "Create redacted copy? (Y/n)". Answering yes produces `CaptainsLog_REDACTED.txt` and `CaptainsLog_REDACTED.md` alongside the full reports, with personal/identifying data replaced by `<REDACTED_*>` placeholders. All diagnostic data (OS, hardware, Seaworthy findings, port tests, firewall state, etc.) is preserved. The redacted files get added to the sealed zip.
- **What gets scrubbed:** hostname, username (in all forms including file paths), public IPv4/IPv6 addresses, MAC addresses, DHCPv6 DUID/IAID, local host IPs (keeps network shape like `192.168.1.<REDACTED_HOST>` so gateway structure is still visible), DHCP lease timestamps, user profile paths.
- **What's preserved:** OS version/build, CPU/RAM/GPU details, VRAM, driver versions, Seaworthy PASS/WARN/FAIL findings, port test results (without target IP), Steam/Windrose process names, firewall profile state, VC++ runtimes, install drive layout (e.g., `F:\SteamLibrary\...`), well-known public DNS servers (1.1.1.1, 8.8.8.8).
- **Automation flags:** `-Redact` creates the redacted version automatically without prompting. `-NoRedactPrompt` skips the prompt entirely.

### Notes

Regex-based redaction is never perfect. The script adds a notice at the top of redacted files reminding users to skim once before posting, in case anything specific to their setup slipped through.

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
