# 🛠️ Troubleshooting

Common problems, from most to least frequent.

## Game shows "Connection Services: N/A" for EU & NA / SEA / CIS

**What it looks like:** in-game, the Connection Services screen shows N/A for some or all regions. You can't connect to any multiplayer.

**What's happening:** nine times out of ten, a security feature on your ISP's router is blocking the ports or domains Windrose needs. Other possibilities: DNS spoofing, IPv6 prioritization, or a genuine dev-side outage.

**What to do:** run the Chest (any mode). It has two sections that tell you specifically what's wrong:

### 🎯 Port authority (ISP auto-detection)

Near the top of the report, the Chest looks up your ISP from your public IP and — if you're on one of 25+ known-culprit ISPs — tells you the exact router security feature to toggle off and where to find it. Example:

```
ISP:              Spectrum (Charter)
Feature to check: Security Shield
Where to toggle:  My Spectrum app > Internet > Security Shield > OFF
```

**Toggle off whatever it names, restart Windrose, try again.** This fix works for most players hitting connection issues.

### 🔭 Fleet check (endpoint reachability)

Below Port authority, the Chest probes 8 Windrose endpoints and shows which ones are reachable. If your ISP auto-detection found a culprit AND Fleet check shows problems, the diagnosis in the report will be personalized: "LIKELY CAUSE: [your ISP name] - toggle off [feature name]."

### Supported ISPs (auto-detected)

The Chest recognizes these ISPs and names the specific security feature to disable:

**US:** Spectrum (Charter), Xfinity (Comcast), Cox, AT&T, CenturyLink/Lumen, Verizon Fios, T-Mobile Home Internet, Optimum (Altice), Frontier

**UK:** BT, Sky, Virgin Media, TalkTalk

**EU:** Ziggo (NL), Orange (FR), Free (FR), Deutsche Telekom, Vodafone

**Canada:** Rogers, Bell, Telus

**Australia:** Telstra, Optus

If your ISP isn't on this list, the report still tells you to check your ISP's app for a "security" or "threat protection" toggle. The pattern is universal across consumer ISPs — they almost all ship some variant of this feature.

### Other possible causes (covered in the Fleet check diagnosis)

- **DNS spoofing** — VPN, parental controls, or NextDNS intercepting Windrose domains. Fix: disconnect the VPN / disable filtering / switch to Google DNS 8.8.8.8.
- **IPv6-only result** — Windrose is IPv4-only. The report prints the exact registry command to prioritize IPv4 without disabling IPv6 entirely.
- **All services down** — Genuine dev-side outage. Check the official Windrose Discord's #status channel or [playwindrose.com](https://playwindrose.com).

### Why dedicated servers work but my home connection doesn't

Dedicated server hosts (SurvivalServers, LOW.MS, g-portal, Apex, indifferent broccoli) run on business-grade datacenter connections without consumer router security filters. The blocks you're hitting don't exist on their side — they're on your residential ISP side.

---

## "Windows protected your PC" SmartScreen warning

**What it looks like:** a blue box pops up saying "Microsoft Defender SmartScreen prevented an unrecognized app from starting" with a **Don't run** button front and center.

**Why it happens:** the exe isn't code-signed with a commercial certificate (those cost hundreds of dollars per year). Windows treats unsigned executables from the internet as unknown publishers. This is completely normal for community tools.

**What to do:** click the **More info** link on the SmartScreen dialog, then click **Run anyway**. You only need to do this once — Windows remembers your choice for that specific file.

## Antivirus flagged it as a virus (usually "Wacatac")

**What it looks like:** Windows Defender or another AV quarantines the exe with a name like `Trojan:Win32/Wacatac.B!ml` or similar.

**Why it happens:** the exe is compiled from a PowerShell script using a tool called `ps2exe`. Because some malware authors use the same tool, AV heuristic engines flag `ps2exe` output as suspicious even when the underlying script is harmless.

**What to do, in order of preference:**

1. **Don't trust the exe, run the `.ps1` directly.** The source script is in the same zip as the exe. Open it in Notepad, read it, and if it looks clean run it with:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\CaptainsChest.ps1
   ```

2. **Add an exception.** In Windows Security → Virus & Threat Protection → Manage Settings → Exclusions → Add exclusion → File → pick `CaptainsChest.exe`.

3. **Report it to your AV vendor as a false positive.** For Microsoft Defender: [submit the file here](https://www.microsoft.com/en-us/wdsi/filesubmission) — Microsoft usually reviews within 72 hours and removes the flag for everyone.

## "Running scripts is disabled on this system" (execution policy)

**What it looks like:** red error text mentioning `UnauthorizedAccess` when you try to run the `.ps1` directly.

**What to do:**

```powershell
powershell -ExecutionPolicy Bypass -File .\CaptainsChest.ps1
```

The `-ExecutionPolicy Bypass` flag tells PowerShell to run this one script without changing your system-wide policy.

Or, unblock the file once (the download flag on the file is the real problem):

```powershell
Unblock-File .\CaptainsChest.ps1
```

Right-click → Run with PowerShell will work forever after that.

## "No Windrose install auto-detected" (but it IS installed)

**What's happening:** the Chest looks for Windrose in these places:
- Default Steam install folders
- Every Steam library listed in `libraryfolders.vdf`
- Every fixed drive, looking for common folder names (`SteamLibrary`, `Steam`, `Games\SteamLibrary`, `Games\Steam`)
- Existing Windrose firewall rules

If all four miss, your install lives somewhere unusual.

**What to do:** the Chest will still produce a useful report — it just won't copy your Config or log files into the Salvage folder. If you want those files included in a help request, zip them manually from:

```
<your Steam library>\steamapps\common\Windrose\R5\Saved\Config
<your Steam library>\steamapps\common\Windrose\R5\Saved\SaveProfiles
```

If you think the auto-detection should have found your install, [open an issue](https://github.com/1r0nch3f/Windrose-Captain-Chest/issues) with your install path and I'll add a case for it.

## The window closes before I can read anything

**What's happening:** an error caused PowerShell to bail before reaching the final pause. The window closes immediately so you can't read the error.

**What to do:** open a PowerShell window first, then run the script from inside it — that way the error stays visible:

```powershell
cd C:\path\to\extracted\folder
.\CaptainsChest.exe
```

Or for the `.ps1`:

```powershell
cd C:\path\to\extracted\folder
cmd /c powershell -ExecutionPolicy Bypass -File .\CaptainsChest.ps1
```

Paste whatever error you see into a [GitHub issue](https://github.com/1r0nch3f/Windrose-Captain-Chest/issues) and I can help diagnose.

## VRAM showing wrong / GPU section looks weird

**What's happening:** Windows has multiple registry locations where it stores GPU memory info, and different AMD/NVIDIA driver versions write to different ones. Some edge cases slip through.

**What to do:** check that your release is v1.0.5 or newer (the VRAM detection was rewritten across several releases). If you're on the latest and still seeing odd values, run this in PowerShell and share the output:

```powershell
Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\Video" -Recurse -ErrorAction SilentlyContinue |
  Where-Object { $_.Property -contains 'DriverDesc' } |
  ForEach-Object {
    $p = Get-ItemProperty $_.PSPath
    [PSCustomObject]@{
      Desc = $p.DriverDesc
      MemProps = ($p.PSObject.Properties.Name | Where-Object { $_ -match 'Memory' }) -join ', '
    }
  }
```

That tells me what property names your GPU driver actually uses.

## DirectX section shows "unknown" or takes forever

**What's happening:** the Chest runs `dxdiag /t` to a temp file and parses the output. On some machines `dxdiag` is slow to produce its report, or is blocked by group policy.

**What to do:** not much — the DirectX check is informational. If it's taking more than 20-30 seconds, wait it out. If it consistently fails, your DirectX install might actually be broken — run `dxdiag` manually from Start → Run and see if it opens normally.

## The redacted version still has personal data in it

**What's happening:** the regex-based redaction catches common patterns but isn't infallible. Unusual formats can slip through.

**What to do:** open `CaptainsLog_REDACTED.txt` in Notepad and skim it once before posting. If you see anything that looks personal — edit it out. Then [open an issue](https://github.com/1r0nch3f/Windrose-Captain-Chest/issues) with a sample of what slipped through (sanitized, obviously) so I can tighten the regex for future runs.

## For devs / forking

Source lives at [github.com/1r0nch3f/Windrose-Captain-Chest](https://github.com/1r0nch3f/Windrose-Captain-Chest). Highlights for contributors:

- **Main script:** `CaptainsChest.ps1` — one file, ~1,400 lines, heavily commented
- **Spec values:** `$script:WindroseSpecs` block near the top. Edit when the game's requirements update.
- **GPU tier table:** `$script:GpuTierTable` — regex patterns mapping card names to performance tiers. Add entries for new cards.
- **Port presets:** `$script:WindrosePortPresets` — edit if Windrose changes its default ports.
- **Build tooling:**
  - `push.bat` — git init/add/commit/push
  - `build-exe.bat` — compiles `.ps1` to `.exe` via `ps2exe`
  - `release.bat` — tags and publishes a GitHub release (uses `gh` CLI if installed)

PRs welcome. Open an issue first for anything non-trivial so we can discuss approach before you sink time into it.

## Still stuck?

Open an issue with:
- Which release you're on
- What you ran (exe or `.ps1`, which mode, which flags)
- The full error message if any
- Attach the redacted `CaptainsLog_REDACTED.txt` if you got that far

[github.com/1r0nch3f/Windrose-Captain-Chest/issues](https://github.com/1r0nch3f/Windrose-Captain-Chest/issues)
