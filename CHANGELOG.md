# Changelog

All notable changes to Windrose Captain's Chest will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-04-24

Complete rebuild. Networking focused, hardware removed, Shipwright added.

### Added

- **Shipwright mode** (mode 3) - dedicated server toolkit running interactively inside Captain's Chest:
  - **Setup wizard** - auto-detects game install, copies WindroseServer out of game files to a user-chosen location, warns when path is inside the game folder (per official docs), runs server once to generate ServerDescription.json, then walks through name/max players/region/password config interactively.
  - **Save transfer** - client-to-server and server-to-client world transfers with automatic backup of both source and destination, pre-flight process check (both game and server must be stopped), post-transfer World ID triple-match validation, and automatic ServerDescription.json update.
  - **Config validator** - read-only check of the three IDs that must match (world folder name, islandId in WorldDescription.json, WorldIslandId in ServerDescription.json). Flags mismatches and warns when the configured ID doesn't match any world folder (which causes fresh world generation on server start).
- **TROUBLESHOOTING.md** - 22-section manual reference that mirrors every check the script runs. Each section has a plain English explanation, the exact PowerShell command to paste, and guidance on reading the output. Ends with the full ISP culprit table. For users who want to run checks individually without downloading or running the script.
- **Colored output helpers** - Write-Ok (green), Write-Warn (yellow), Write-Fail (red), Write-Info (gray) used consistently throughout all output.
- **TROUBLESHOOTING.md included in release zip** via updated release.bat.

### Removed

- **All hardware diagnostics** - GPU tier table (~200 lines), dxdiag call, CPU/RAM Seaworthy check, VCRuntime check, driver age check all removed entirely. Hardware is almost never the cause of Windrose issues; networking always is. The tool is faster and the report is shorter and more actionable.
- **WindroseQuickCheck.ps1** - functionality folded into mode 1 (ConnectionTrouble). No longer a separate script.

### Changed

- **Three-mode menu** replaces the old Full/Quick/LocalOnly structure:
  - Mode 1: ConnectionTrouble - ISP detection, fleet check, firewall, hosts file, game version, crash logs. The 90% case, runs in ~20 seconds.
  - Mode 2: CantReachServer - everything in mode 1 plus DNS resolution, ping, TCP port tests, and traceroute to a specific server IP or hostname.
  - Mode 3: Shipwright - interactive dedicated server toolkit (no log file produced).
- **build-exe.bat** version string updated to 2.0.0.0.
- **release.bat** now includes TROUBLESHOOTING.md in the distribution zip.

### Background

Hardware diagnostics were cut because every real support case in the Windrose community has been a networking problem (ISP security features, port 3478 blocks, DNS filtering, CGNAT) not a spec problem. Removing them cuts the script from ~2096 lines to ~700 and makes the report much faster to read. Shipwright fills the gap for dedicated server operators who previously had no tooling for save management and config validation.

---

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
- **Tailored fix instructions.** When the detected ISP matches a culprit, the ISP-block and partial-outage sections now lead with "LIKELY CAUSE (based on your ISP): [Name]" and give the exact toggle path for that specific ISP.
- **"Hosting providers don't have this problem" clarification.** Explains that residential ISP security features are the cause, and that game hosts (SurvivalServers, LOW.MS, g-portal, etc.) running Rust/Palworld/Ark/etc. don't see these blocks because they're on business connections.

### Background

A player shared the exact list of Windrose domains Spectrum's "Security Shield" was blocking on their network, which confirmed the mechanism for dozens of similar reports. This release codifies that diagnosis into the tool.

## [1.2.0] - 2026-04-19

Expanded Fleet check with complete endpoint list and ISP router diagnosis.

### Added

- **Four additional endpoints in Fleet check.** Fleet check now probes all 8 endpoints:
  - `r5coopapigateway-eu-release.windrose.support` + `-2` failover (EU/NA)
  - `r5coopapigateway-ru-release.windrose.support` + `-2` failover (CIS)
  - `r5coopapigateway-kr-release.windrose.support` + `-2` failover (SEA)
  - `sentry.windrose.support` (error reporting)
  - `windrose.support:3478` (STUN/TURN)
- **Named ISP router security features** in the diagnosis output.
- **Partial-outage diagnosis is smarter.** Now correctly identifies ISP router security as the #1 cause when 3478 is the failing port.

### Clarified

- **No separate North America endpoint exists.** NA players share the EU pool (`r5coopapigateway-eu-release`).

## [1.1.1] - 2026-04-19

Endpoint correction for Fleet check.

### Fixed

- **Third region endpoint name was wrong.** Corrected from `r5coopapigateway-sea-release` (does not exist) to `r5coopapigateway-kr-release.windrose.support` (South Korea, serving SEA).

## [1.1.0] - 2026-04-19

Major new feature: Fleet check for Windrose backend services.

### Added

- **Fleet check** — probes all Windrose backend endpoints and diagnoses reachability.
- **Dual-DNS diagnosis** — each domain resolved via system DNS and Google 8.8.8.8 to distinguish ISP blocking from DNS spoofing from genuine outages.
- **Plain-English failure diagnosis with fix instructions** embedded in the report.
- **`-SkipServiceCheck` parameter**.

## [1.0.5] - 2026-04-19

Follow-ups from v1.0.4 testing.

## [1.0.4] - 2026-04-19

Multiple detection fixes — found while testing v1.0.3.

### Fixed

- **Drive-scan fallback wasn't finding custom Steam libraries.**
- **Storage check was checking C: instead of the Windrose install drive.**
- **GPU VRAM still showing 4GB on large cards.**

## [1.0.3] - 2026-04-19

Fix bugs introduced by the install-detection changes in v1.0.1.

### Fixed

- **Doubled install paths.**
- **Empty drive letter in storage check.**
- **Windrose.exe not detected even when present.**

## [1.0.2] - 2026-04-19

Privacy feature added — safe-to-share redacted reports.

### Added

- **Redacted report output** with `-Redact` and `-NoRedactPrompt` flags.

## [1.0.1] - 2026-04-19

Bug-fix release.

### Fixed

- OS version reporting on Windows 11.
- GPU VRAM for cards larger than 4GB.
- VC++ runtime listing errors.
- Windrose install auto-detection for custom Steam library locations.

## [1.0.0] - 2026-04-19

First stable release.

### Added

- Consolidated diagnostic script replacing two earlier scripts.
- Ship's papers, Seaworthy check, public IP lookup, port presets, salvage collection, firewall enumeration, crash log scan.
- Three run modes, three output formats, sealed chest zip.
- One-click push.bat and release.bat.

[2.0.0]: https://github.com/1r0nch3f/Windrose-Captain-Chest/releases/tag/v2.0.0
[1.0.0]: https://github.com/1r0nch3f/Windrose-Captain-Chest/releases/tag/v1.0.0
