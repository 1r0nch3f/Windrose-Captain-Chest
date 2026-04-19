# 🏴‍☠️ Windrose Captain's Chest v1.3.1

**Small but useful follow-up.** Adds a Direct IP fallback note to the Fleet check summary so users have an immediate workaround when Windrose Connection Services are unreachable.

## 🆕 What's new in v1.3.1

### Direct IP fallback in Fleet check summary

When the backend path is down or unusable, the report now tells users to switch to Windrose's built-in Direct IP host mode instead of stopping at ISP or DNS guidance.

Example report text:

```
=== Fallback: Direct IP mode ===

Connection Services unreachable? You can host without them.

Host a Game -> Direct IP tab -> port 7777
Share your public IP with your crew

This bypasses Windrose Connection Services entirely.
Requires port 7777 to be open on your router (tested above).
```

### Why this belongs in the tool

- Captain's Chest already tests port **7777** in its default presets
- Direct IP mode bypasses the Windrose backend path entirely
- Users with ISP-level filtering now get a practical workaround in the report itself

## 📥 Quick start

1. Download **CaptainsChest-v1.3.1.zip** below
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
