# Changelog

All notable changes to Windrose Captain's Chest will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.2.0] - 2026-04-28

Logbook scan: parse salvaged R5.log files for the server's own slow-task warnings.

### Added

- **Logbook scan section.** A new report section that runs after Salvage. It parses every salvaged `R5*.log` file for the `R5BLDalAsyncQueue::DetectProblems` slow-task warnings the dedicated server emits when its RocksDB commit pipeline is bottlenecked. These warnings are the direct cause of the at-sea rubber-banding pattern reported across every Windrose host (Nitrado, SurvivalServers, LOW.MS, etc), and they're invisible unless someone goes digging through the logs by hand.
- **Three-tier severity bucketing** based on actual ms values, so the tiers stay consistent if the engine adjusts its thresholds:
  - Slow (under 1 second)
  - Quite slow (1 to 5 seconds)
  - EXTREMELY slow (5 seconds and up, sometimes 20+)
- **Per-file breakdown** when more than one log file contains hits, plus the worst single line captured (truncated to 240 chars) so helpers can eyeball the actual offending entry.
- **Plain-English diagnosis** explaining what the warnings mean (RocksDB commit transactions blocking, server cannot confirm boat positions, snaps player back) and the three contributing factors in order of impact (Kraken backend routing, server-side resource pressure, network path issues).
- **Mitigation playbook** printed inline when WARN or FAIL grades trigger: daily restarts, build version matching, SSD requirement, 4-player cap, CPU headroom check, AV exclusions for `R5\Saved`, cross-reference to the Fleet check.

### Severity grading

- 0 hits → PASS
- Only minor "slow" hits → INFO (below visible-rubber-band threshold)
- Any "quite slow" but no extreme → INFO (mild lag possible)
- 1 to 4 EXTREMELY slow hits, worst under 10 seconds → WARN
- 5+ EXTREMELY slow hits, or worst case 10 seconds or more → FAIL

### Background

The warnings come from `R5LogBLDalAQ` and look like:

```
[2026.04.21-10.01.21:778][510]R5LogBLDalAQ: Warning: [063510]
  R5BLDalAsyncQueue::DetectProblems [s:1774: 6169: commitT]
  EXTREMELY slow task. Task was finished in 21698 ms. DebugInfo
```

A 21-second commit transaction is roughly two orders of magnitude over the engine's expected ceiling. Multiple Steam Discussion threads document exactly this pattern correlating with the boat-rubber-banding symptom, and players have been pointing each other at `R5\Saved\Logs\R5.log` for diagnosis. Captain's Chest already salvaged these logs, but until now the user had to read them manually. The Logbook scan turns that into a one-line summary plus a finding in the Captain's summary.

The case-insensitive regex matches all three observed wordings ("Slow task", "quite slow task", "EXTREMELY slow task") by anchoring on the shared `slow task. Task was finished in N ms` suffix, so the bucketing reflects the actual ms value rather than relying on the qualifier text.

## [2.1.0] - 2026-04-24

Live network profile, crew invite generator, and new standalone CaptainsSignal tool.

### Added

- **Crow's nest - live network profile section** in CaptainsChest. When Windrose is running during a chest run, the report now snapshots the live TCP and UDP connections owned by `Windrose-Win64-Shipping` and analyses them against a known-good baseline:
  - Backend connectivity check: detects which of the three connection service regions (EU/NA, SEA, CIS) Windrose contacted and in what state
  - UDP pool check: counts external UDP sockets open for P2P peer connections, with dynamic port range detection (the range shifts each session so hard-coded ranges are not used)
  - Hosting mode detection: identifies Direct IP mode (port 7777) vs invite code mode
  - Firewall rule check: catches the case where the user hit Cancel on the Windows Security prompt during Direct IP hosting, which silently breaks hosting
- **Send to crew - ready-to-copy invite message generator.** After the network profile, the report generates formatted invite messages the host can copy directly into text, iMessage, WhatsApp, or Discord. Covers all four scenarios: invite code with/without password, Direct IP with/without password.
- **Automatic invite code detection.** The invite code is read directly from `ServerDescription.json` at `<SteamLibrary>\steamapps\common\Windrose\R5\ServerDescription.json`. No need to copy it from the in-game screen. Server name, max players, region, and password also read from the same file.
- **Public IP warning** included in Direct IP invite messages.
- **Server password redaction** in redacted report versions. Password replaced with `<REDACTED_SERVER_PASSWORD>`.
- **CaptainsSignal.ps1** - new standalone lightweight tool. Runs in seconds with no hardware collection. Reads server config, checks the live network, and prints a ready-to-copy crew invite message in colour directly to the terminal.

### Fixed

- **Process name detection.** The actual shipping binary is `Windrose-Win64-Shipping`, not `Windrose`. All network profile checks now use the correct name.
- **UDP pool port range.** Detection now finds any sequential block of 10+ external UDP sockets owned by the process rather than checking a hard-coded range.

## [1.3.1] - 2026-04-19

Direct IP fallback note added to Fleet check summary.

### Added

- **Direct IP fallback note** in Fleet check summary. When Connection Services are unreachable, the report now points users to Windrose's Direct IP host mode on port 7777 as an immediate workaround.
- **Clear trigger points for the fallback.** The note appears in the failure paths where backend reachability is broken or unusable, so users get a practical path forward instead of only ISP / DNS guidance.

### Why

Windrose's Direct IP mode bypasses the backend Connection Services path entirely. Since Captain's Chest already tests port 7777 in its default port presets, the report can safely tell users when this workaround is viable.

## [1.3.0] - 2026-04-19

Automatic ISP detection and named-culprit diagnosis.

### Added

- **Port authority section** — new report section above Fleet check that identifies your ISP from your public IP via `ipinfo.io` (with `ip-api.com` fallback), matches it against a table of known culprits, and tells you *exactly* which router security feature to toggle off and where to find it.
- **Known-ISP culprit table** with 25+ entries covering:
  - **US:** Spectrum (Charter), Xfinity (Comcast), Cox, AT&T, CenturyLink/Lumen, Verizon, T-Mobile Home, Optimum (Altice), Frontier
  - **UK:** BT, Sky, Virgin Media, TalkTalk
  - **EU:** Ziggo (NL), Orange (FR/ES), Free (FR), Deutsche Telekom (DE), Telekom generic, Vodafone
  - **Canada:** Rogers, Bell, Telus
  - **Australia:** Telstra, Optus
- **Entries flagged as "confirmed to block Windrose"** where there are public reports (Spectrum, Xfinity, BT, Ziggo) versus "known to block similar P2P games" for the rest.
- **Full ISP reference table printed in the report when there's a problem.** Helps Discord helpers do a manual visual match when auto-detection misses an ISP or someone else's report doesn't have detection info.
- **Tailored fix instructions.** When the detected ISP matches a culprit, the ISP-block and partial-outage sections now lead with "LIKELY CAUSE (based on your ISP): [Name]" and give the exact toggle path for that specific ISP. No more "check your ISP app" generic advice — the report says "Open My Spectrum app → Internet → Security Shield → OFF."
- **"Hosting providers don't have this problem" clarification.** Explains that residential ISP security features are the cause, and that game hosts (SurvivalServers, LOW.MS, g-portal, etc.) running Rust/Palworld/Ark/etc. don't see these blocks because they're on business connections.

### Background

A player shared the exact list of Windrose domains Spectrum's "Security Shield" was blocking on their network, which confirmed the mechanism for dozens of similar reports. This release codifies that diagnosis into the tool — auto-detecting the ISP means the report can tell each user the specific toggle to flip rather than a general "check your ISP app" suggestion.

## [1.2.0] - 2026-04-19

Expanded Fleet check with complete endpoint list and ISP router diagnosis.

### Added

- **Four additional endpoints in Fleet check.** A Steam user on Spectrum published the complete list of Windrose domains that their router was blocking, confirming that each of the three regional gateways has a `-2` failover variant plus a `sentry.windrose.support` error-tracking endpoint. Fleet check now probes all 8 endpoints:
  - `r5coopapigateway-eu-release.windrose.support` + `-2` failover (EU/NA)
  - `r5coopapigateway-ru-release.windrose.support` + `-2` failover (CIS)
  - `r5coopapigateway-kr-release.windrose.support` + `-2` failover (SEA)
  - `sentry.windrose.support` (error reporting)
  - `windrose.support:3478` (STUN/TURN)
- **Named ISP router security features** in the diagnosis output. The single most common cause of port 3478 blocks on US cable ISPs turned out to be ISP-provided router security features that are on by default and silently flag gaming traffic. Confirmed culprits now called out by name in the report: Spectrum "Security Shield", Xfinity "xFi Advanced Security", Cox "Security Suite", BT "Web Protect", Ziggo default filtering. Instructions for toggling each off are in the report.
- **Partial-outage diagnosis is smarter.** Old output assumed partial reachability meant a dev-side regional outage. New output correctly identifies ISP router security as the #1 cause when 3478 is the failing port.

### Clarified

- **No separate North America endpoint exists.** The game's "EU & NA" bucket in the Connection Services screen uses the single `r5coopapigateway-eu-release` gateway (with `-2` as failover). Dev infrastructure is EU, CIS, and KR/SEA; NA players share the EU pool.

## [1.1.1] - 2026-04-19

Endpoint correction for Fleet check.

### Fixed

- **Third region endpoint name was wrong.** I guessed `r5coopapigateway-sea-release.windrose.support` based on the EU/RU pattern, but the actual third endpoint is `r5coopapigateway-kr-release.windrose.support` (South Korea, serving SEA). Per PC Gamer's investigation of the dedicated server code: "the server software also contains similar URLs pointing to IP addresses located in Europe and South Korea." The old SEA domain was returning NXDOMAIN because it doesn't exist. Now correctly labeled as "KR/SEA API Gateway" and pointing at the real endpoint.

## [1.1.0] - 2026-04-19

Major new feature: Fleet check for Windrose backend services.

### Added

- **Fleet check (Windrose backend service reachability).** A new section that runs in all three modes and diagnoses whether Windrose's own services are reachable from your machine. Checks four endpoints:
  - `r5coopapigateway-eu-release.windrose.support` (EU/NA API gateway, port 443)
  - `r5coopapigateway-ru-release.windrose.support` (CIS API gateway, port 443)
  - `r5coopapigateway-sea-release.windrose.support` (SEA API gateway, port 443)
  - `windrose.support:3478` (STUN/TURN for P2P signaling)
- **Dual-DNS diagnosis.** Each domain is resolved via both system DNS and Google's 8.8.8.8, so the report can distinguish between ISP blocking, DNS spoofing, timeouts, IPv6-only results, and dev-side outages.
- **Plain-English failure diagnosis with fix instructions** embedded in the report. If ISP blocking is detected, the report prints DNS switch instructions for Google/Cloudflare DNS and the exact wording to use when contacting the ISP. If DNS spoofing is detected (VPN / parental controls / NextDNS), the report explains that and offers the DNS switch. If IPv6-prioritization is detected, the report includes the registry command to force IPv4 preference.
- **`-SkipServiceCheck` parameter** for users who want to skip the backend check entirely.

### Background

The Windrose devs have publicly acknowledged that some ISPs (particularly in EU and NA) are blocking their backend services, causing the game's "Connection Services" screen to show N/A for all regions. This check turns "I don't know why the game won't connect" into a specific diagnosis: ISP block, DNS spoofing, IPv6 bug, or genuine outage. Helpers on Discord can triage much faster with this info.

### Changed

- The wiki's Troubleshooting page will want an update to reference the Fleet check — any specific fix in the report output mirrors the fixes in the wiki.

## [1.0.5] - 2026-04-19

Follow-ups from v1.0.4 testing.

### Fixed

- **Seaworthy GPU section still showed 4 GB VRAM** for large cards. The v1.0.1/1.0.4 `Get-GpuVramGB` function was implemented but the Seaworthy check wasn't actually using it — it was still reading WMI's overflowed `AdapterRAM` directly. Now calls the same registry lookup as the Crow's nest section.
- **Storage check still defaulted to C:** even on systems where the Windrose install drive is correctly detected elsewhere in the report. Root cause: PowerShell's scalar-vs-array gotcha — when `Find-WindroseInstall` returned a single-element list, downstream code checked `.Count` which doesn't exist on a scalar string. Now wraps with `@(...)` and uses the comma operator in cache returns to guarantee array shape.

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
