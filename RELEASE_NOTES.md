# 🏴‍☠️ Windrose Captain's Chest v1.0.2

Privacy feature — safe-to-share redacted reports.

## 🆕 What's new

**Redacted report option.** At the end of every run, you'll now get a prompt:

```
Create redacted copy? (Y/n)
```

Say yes and you'll get two extra files in the chest: `CaptainsLog_REDACTED.txt` and `CaptainsLog_REDACTED.md`. These are copies of the full report with personal stuff replaced by `<REDACTED_*>` placeholders — but all the hardware specs, Seaworthy check results, port test outcomes, and other diagnostic info stay intact. Perfect for posting in Discord or forums without doxxing yerself.

### What gets scrubbed

- Hostname and username (in all forms, including file paths)
- Public IPv4 and IPv6 addresses
- MAC addresses
- DHCPv6 DUID and IAID
- Local host IPs (keeps network structure like `192.168.1.<REDACTED_HOST>` so gateway layout is still visible)
- DHCP lease timestamps
- User profile paths like `C:\Users\Mike` → `C:\Users\<REDACTED_USER>`

### What stays

- OS version and build
- All hardware (CPU, RAM, GPU, VRAM, storage)
- Seaworthy PASS/WARN/FAIL findings
- GPU driver versions
- Port test results
- Firewall profile states
- Steam/Windrose process names
- VC++ runtime list
- Install drive layout (e.g., `F:\SteamLibrary\...` stays visible since it's useful for diagnosing path issues)
- Well-known public DNS like 1.1.1.1 and 8.8.8.8 (not personal)

## 📥 Quick start

1. Download **CaptainsChest-v1.0.2.zip** below
2. Extract it anywhere
3. Double-click `CaptainsChest.exe` — SmartScreen "More info" → "Run anyway", then UAC → Yes
4. Pick a mode, follow the prompts
5. At the end, say **Y** when asked about the redacted copy
6. Post `CaptainsLog_REDACTED.txt` (NOT `CaptainsLog.txt`) when asking for help

### Heads up

Regex-based redaction is good but not perfect. The redacted file has a notice at the top reminding you to skim it once before posting — takes 10 seconds and catches anything weird.

### Automation flags

- `-Redact` — auto-creates redacted version without prompting
- `-NoRedactPrompt` — skip the prompt entirely (don't create one)

## ⚠️ Antivirus note

Same as previous releases: the exe is compiled with `ps2exe` which Windows Defender sometimes flags as a false positive. Source `.ps1` is in the zip for inspection.

---

See the [full changelog](https://github.com/1r0nch3f/Windrose-Captain-Chest/blob/main/CHANGELOG.md) for history.
