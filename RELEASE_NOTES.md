# 🏴‍☠️ Windrose Captain's Chest v1.3.0

**The big one.** Bundles the Fleet check feature (v1.1.0–v1.2.0) with the new ISP auto-detection and named-culprit diagnosis. If Windrose won't connect, this release tells you *exactly* which setting on *your specific ISP* to change.

## 🆕 What's new in v1.3.0

### Port authority — ISP auto-detection

A new report section identifies your ISP from your public IP and — if they're on the known-culprit list — tells you the exact router security feature to toggle off. No more Googling, no more guessing.

Example output if you're on Spectrum:

```
=== Port authority (your ISP) ===
ISP:      AS20115 Spectrum
ASN:      AS20115
City:     Dalton
Country:  US

*** HEADS UP: your ISP ships routers with a security feature that ***
*** commonly blocks legitimate gaming traffic, including Windrose. ***

ISP:              Spectrum (Charter)
Feature to check: Security Shield
Where to toggle:  My Spectrum app > Internet > Security Shield > OFF

** This ISP has been CONFIRMED to block Windrose specifically. **
Turning this feature off has fixed the issue for other players on
this same ISP.
```

### 25+ named ISPs with specific fix instructions

| Region | Covered ISPs |
|--------|-------------|
| 🇺🇸 US | Spectrum, Xfinity, Cox, AT&T, CenturyLink/Lumen, Verizon, T-Mobile Home, Optimum, Frontier |
| 🇬🇧 UK | BT, Sky, Virgin Media, TalkTalk |
| 🇪🇺 EU | Ziggo (NL), Orange (FR), Free (FR), Deutsche Telekom, Vodafone |
| 🇨🇦 CA | Rogers, Bell, Telus |
| 🇦🇺 AU | Telstra, Optus |

Each entry includes the specific "security feature" name and step-by-step toggle instructions.

### Everything from v1.1.0 and v1.2.0 — Fleet check

If you're installing fresh, you also get:

- **Fleet check** — probes 8 Windrose backend endpoints (all three regional gateways + failovers + sentry + STUN/TURN) and diagnoses whether issues are ISP blocking, DNS spoofing, IPv6 prioritization, dev-side outages, or just you
- **Dual-DNS diagnosis** — each endpoint resolved via both system DNS and Google 8.8.8.8 so the tool can distinguish ISP block from genuine outage
- **Inline fix instructions** — DNS switch commands, ISP whitelist template, IPv6-to-IPv4 registry command, all printed in the report
- **"EU & NA shared gateway" clarification** — the game's in-game list combines EU and NA for a reason; there's no separate NA endpoint

## 📥 Quick start

1. Download **CaptainsChest-v1.3.0.zip** below
2. Extract anywhere
3. Double-click `CaptainsChest.exe` — SmartScreen "More info" → "Run anyway", then UAC → Yes
4. Pick any mode — Fleet check and ISP detection run in all three

### ⚠️ Antivirus note

Same as always — the exe is compiled with `ps2exe`, Windows Defender sometimes flags it as a false positive. Source `.ps1` is in the same zip for inspection.

## 💬 A note on hosting providers

If you've wondered "if SurvivalServers / LOW.MS / g-portal can host Rust and Palworld fine, why does Windrose fail?" — the answer is: **they do work fine on those hosts.** The block is on your residential ISP side, not the host's. Dedicated-server hosts run on business-grade connections without consumer router security filters. This release now explains that directly in the report.

## 📖 See also

- [Wiki](https://github.com/1r0nch3f/Windrose-Captain-Chest/wiki) — usage guide, troubleshooting
- [Changelog](https://github.com/1r0nch3f/Windrose-Captain-Chest/blob/main/CHANGELOG.md) — full release history
- [Issues](https://github.com/1r0nch3f/Windrose-Captain-Chest/issues) — report bugs or add your ISP to the culprit table

Fair winds, Captain. 🏴‍☠️
