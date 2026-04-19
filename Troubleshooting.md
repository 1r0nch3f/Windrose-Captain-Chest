# 🛠️ Troubleshooting

Common problems, from most to least frequent.

## Game shows "Connection Services: N/A" for EU & NA / SEA / CIS

**What it looks like:** in-game, the Connection Services screen shows N/A for some or all regions. You can't connect to any multiplayer.

**What's happening:** either (a) your ISP is blocking Windrose's backend services, (b) your DNS is misconfigured or being spoofed, (c) your system is prioritizing IPv6 which Windrose doesn't support, or (d) Windrose's backend is genuinely down on the dev side.

**What to do:** run the Chest (any mode). The **Fleet check** section tells you which of these it is and includes the specific fix inline. Common outcomes:

### ISP blocking

The Chest detected that Google's DNS can resolve the Windrose endpoints but your system DNS can't. Your ISP or router is filtering these domains. The devs have publicly acknowledged this is happening on some EU/NA ISPs.

**Fix 1 — switch DNS to Google or Cloudflare.** In Settings → Network & Internet → your active connection → Properties → Edit DNS server assignment:
- Manual / IPv4 on
- Preferred: `8.8.8.8`  Alternate: `8.8.4.4` (Google)
- Or: `1.1.1.1` / `1.0.0.1` (Cloudflare)

Then run `ipconfig /flushdns` in PowerShell.

**Fix 2 — try a VPN.** If it works with a VPN on, ISP block is confirmed.

**Fix 3 — contact your ISP.** Ask them to whitelist:
- Domain: `*.windrose.support` (all subdomains)
- Port: `3478`
- Protocols: UDP and TCP
- Say it's STUN/TURN for a legitimate game application

Known affected ISPs include Ziggo (Netherlands) and various others in EU/NA. NextDNS with default filtering also blocks these domains.

### DNS spoofing

Your DNS is returning 127.0.0.1 or a null address for Windrose domains — typically caused by VPN, parental controls, or custom DNS providers.

**Fix:** disconnect the VPN / disable parental controls / switch DNS as above.

### IPv6-only result

Your system prefers IPv6 but Windrose is IPv4-only. The Chest's report includes the exact registry command to keep IPv6 enabled but prioritize IPv4:

```
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" /v DisabledComponents /t REG_DWORD /d 32 /f
```

(Run in an elevated Command Prompt, then reboot.)

### All services down / partial outage

Not your fault. Check the official Windrose Discord's status channel or [playwindrose.com](https://playwindrose.com) for announcements.

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
