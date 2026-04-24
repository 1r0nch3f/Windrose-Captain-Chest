# 🏴‍☠️ Windrose Captain's Chest v1.4.0

**Two new tools in one release.** Captain's Chest now profiles your live network while Windrose is running and generates a ready-to-copy crew invite message. Plus a new standalone `CaptainsSignal.ps1` that does just the invite part in seconds, no hardware scan required.

## 🆕 What's new in v1.4.0

### Crow's nest — live network profile (CaptainsChest)

When you run Captain's Chest while Windrose is open, it now snapshots your live network connections and tells you what's healthy and what isn't.

```
=== Crow's nest (live network profile) ===
[PASS] Backend: contacted 3 connection service region(s): CIS, EU & NA, SEA
[PASS] UDP pool: 12 sockets open (59935-59946) - peer connections ready
[INFO] Invite code mode - relies on connection services for peer matching
[PASS] Firewall: Windrose application rule present
```

Catches things the static Fleet check misses, including whether the game actually contacted the backend, whether your P2P UDP pool is open, and whether your firewall rule is in place (it goes missing if you hit Cancel on the Windows Security prompt during Direct IP hosting).

### Send to crew — ready-to-copy invite message (CaptainsChest)

The report now generates formatted invite messages you can paste straight into a text, Discord, or iMessage. The invite code is read automatically from the game's own config file so you don't need to copy it from the in-game screen.

```
--- Copy this (text / iMessage / WhatsApp) ---
Hey! Join my Windrose server: Windrose Server (max 4)
Invite code: 4e18908b
In-game: Join a Game > Enter Code
See you on deck!

--- Copy this (Discord) ---
**Join my Windrose server - Windrose Server (max 4)!**
Go to **Join a Game > Enter Code** and use:
`4e18908b`
See you on deck!
```

Works for both invite code and Direct IP mode. Includes the server password in the message when one is set. Public IP warning included for Direct IP hosts.

### CaptainsSignal.ps1 — new standalone invite tool

Don't need a full diagnostic run? `CaptainsSignal.ps1` does just the invite part. Runs in a few seconds, outputs in colour directly to the terminal, no log files generated.

```powershell
Set-ExecutionPolicy -Scope Process Bypass
& ".\CaptainsSignal.ps1"
```

Run it while Windrose is hosting. It finds your server config automatically, checks the live network, and prints the ready-to-copy messages.

## 📥 Quick start

1. Download **CaptainsChest-v1.4.0.zip** below
2. Extract anywhere
3. For the full diagnostic: double-click `CaptainsChest.exe`
4. For just the invite: right-click `CaptainsSignal.ps1` > Run with PowerShell (as admin)

### ⚠️ Antivirus note

The exe is compiled with `ps2exe`. Windows Defender sometimes flags it as a false positive. Source `.ps1` files are in the same zip for inspection.

## 📖 See also

- [Wiki](https://github.com/1r0nch3f/Windrose-Captain-Chest/wiki) — usage guide, troubleshooting
- [Changelog](https://github.com/1r0nch3f/Windrose-Captain-Chest/blob/main/CHANGELOG.md) — full release history
- [Issues](https://github.com/1r0nch3f/Windrose-Captain-Chest/issues) — report bugs or add your ISP to the culprit table

Fair winds, Captain. 🏴‍☠️
