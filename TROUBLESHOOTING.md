# Windrose Troubleshooting — Manual Diagnostic Commands

Each section below matches a check that CaptainsChest.ps1 runs automatically.
Paste the commands individually into a PowerShell window when you want to run
a specific check without the full tool.

---

## 1. Your public IP

**What it checks:** Your public-facing IP address as seen by the internet.  
**Why it matters:** Used to identify your ISP and match you against the known-culprit table. Without a valid public IP, ISP detection won't work.

```powershell
(Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing -TimeoutSec 5).Content.Trim()
```

**How to read the output:** Returns a plain IPv4 address like `203.0.113.42`. If you get an error or empty output your machine has no outbound internet access — check basic connectivity first.

---

## 2. ISP identification

**What it checks:** Which internet service provider owns your public IP.  
**Why it matters:** Several ISPs ship routers with built-in security features that silently block Windrose. Knowing your ISP tells you exactly which feature to look for.

```powershell
$ip = (Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing -TimeoutSec 5).Content.Trim()
(Invoke-WebRequest -Uri "https://ipinfo.io/$ip/json" -UseBasicParsing -TimeoutSec 5).Content | ConvertFrom-Json | Select-Object org, city, country
```

**How to read the output:** The `org` field is your ISP name and ASN — for example `AS11351 Charter Communications Inc`. Match it against the ISP table at the end of this document to see if your ISP is a known culprit.

---

## 3. Fleet endpoint DNS — system DNS

**What it checks:** Whether your system's configured DNS server can resolve Windrose backend hostnames.  
**Why it matters:** If your ISP blocks Windrose, this is the most common failure point. The domain resolves fine on other DNS servers but your system DNS returns nothing.

```powershell
# Test the primary EU/NA gateway (repeat for other endpoints if needed)
Resolve-DnsName -Name 'r5coopapigateway-eu-release.windrose.support' -Type A
```

Other endpoints to test the same way:
- `r5coopapigateway-eu-release-2.windrose.support`
- `r5coopapigateway-ru-release.windrose.support`
- `r5coopapigateway-kr-release.windrose.support`
- `sentry.windrose.support`
- `windrose.support`

**How to read the output:** You want a result with `Type : A` and a real IP address. If you get a "DNS name does not exist" error (NXDOMAIN), your DNS is blocking the domain. Run the Google DNS check below to confirm the domain itself is fine.

---

## 4. Fleet endpoint DNS — Google DNS bypass

**What it checks:** The same hostname, but resolved through Google's public DNS (8.8.8.8) instead of your ISP's DNS.  
**Why it matters:** If your system DNS fails (check 3) but this succeeds, your ISP is blocking the domain at the DNS level. The domain is fine — only your DNS path is broken.

```powershell
Resolve-DnsName -Name 'r5coopapigateway-eu-release.windrose.support' -Type A -Server '8.8.8.8'
```

**How to read the output:**
- System DNS fails + Google DNS succeeds → ISP DNS block. Fix: switch DNS to `8.8.8.8` / `8.8.4.4`, or toggle off the ISP security feature listed in section 2.
- Both fail → Domain is genuinely down. Check Windrose status channels.
- Both succeed → DNS is fine. The problem is elsewhere (TCP connectivity, firewall, etc.).

---

## 5. Fleet endpoint TCP connectivity

**What it checks:** Whether a TCP connection can actually be made to a Windrose endpoint after DNS resolves.  
**Why it matters:** DNS success alone doesn't mean you can reach the service. A firewall or ISP security feature can block the TCP connection even when DNS works.

```powershell
# API gateway (port 443)
Test-NetConnection -ComputerName 'r5coopapigateway-eu-release.windrose.support' -Port 443

# STUN/TURN P2P signaling (port 3478) — the most commonly blocked endpoint
Test-NetConnection -ComputerName 'windrose.support' -Port 3478
```

**How to read the output:** Look for `TcpTestSucceeded : True`. If it's False, the DNS resolved but the connection was blocked — check ISP security features (especially Security Shield, xFi Advanced Security) and Windows Firewall.

---

## 6. Port 3478 — P2P signaling

**What it checks:** Whether the STUN/TURN port that Windrose uses to connect players to each other is reachable.  
**Why it matters:** This is the single most commonly blocked port. If port 3478 is closed, the game may show Connection Services as OK but players still cannot join each other.

```powershell
Test-NetConnection -ComputerName 'windrose.support' -Port 3478 -InformationLevel Detailed
```

**How to read the output:** `TcpTestSucceeded : True` means P2P signaling is reachable. False means port 3478 is being blocked. On US cable ISPs, the fix is almost always:
- Spectrum: My Spectrum app > Internet > **Security Shield** > OFF  
- Xfinity: Xfinity app > WiFi > See Network > **Advanced Security** > OFF  
- Others: look for "Security", "Threat Protection", or "Safe Browsing" in your ISP's app.

---

## 7. Hosts file

**What it checks:** The local hosts file, which can manually override DNS for specific domains.  
**Why it matters:** Some antivirus or parental control software silently adds entries to the hosts file to block domains. This overrides DNS entirely and can block Windrose with no other symptoms.

```powershell
Get-Content "$env:WINDIR\System32\drivers\etc\hosts" | Where-Object { $_ -notmatch '^\s*#' -and $_ -match '\S' }
```

**How to read the output:** Only non-comment, non-blank lines are shown. If you see `windrose.support` or any `r5coop*` hostname listed, that entry is blocking the domain. Delete it by opening the hosts file in Notepad as Administrator (`C:\Windows\System32\drivers\etc\hosts`).

---

## 8. Windows Firewall profiles

**What it checks:** Which Windows Firewall profile is active and what it blocks.  
**Why it matters:** The "Public" profile blocks more traffic than "Private". A misconfigured firewall with "Block" for outbound connections will prevent the game from reaching the internet entirely.

```powershell
Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
```

**How to read the output:** Three profiles are shown: Domain, Private, and Public. Check which profile your active network adapter is using (Settings > Network & Internet > the active connection shows the profile). If outbound is "Block" on your active profile, Windrose cannot reach any server. If the profile is "Public", your firewall may be blocking inbound connections the game needs for hosting.

---

## 9. Steam and Windrose firewall rules

**What it checks:** Whether Windows Firewall has app-specific allow rules for Steam or Windrose.  
**Why it matters:** The game needs firewall exceptions. If you clicked "Block" when Windows asked "Do you want to allow this app?", the game's traffic is silently dropped. Missing rules are a common cause of connection failures that look fine from the network side.

```powershell
Get-NetFirewallApplicationFilter | Where-Object { $_.Program -match 'Steam|Windrose|R5' } | Select-Object Program, @{N='Action';E={ (Get-NetFirewallRule -AssociatedNetFirewallApplicationFilter $_ -ErrorAction SilentlyContinue | Select-Object -First 1).Action }}
```

**How to read the output:** You want to see `steam.exe`, `Windrose.exe`, or similar with `Action : Allow`. Empty output means no app-specific rules exist. To add them: Windows Security > Firewall & network protection > Allow an app through firewall > Allow another app > browse to the exe.

---

## 10. Game install location

**What it checks:** Whether Windrose is installed and where.  
**Why it matters:** Confirms the game exists on disk and where its config and save files live. Install detection failures often mean the Steam library was moved without updating Steam's registry entry.

```powershell
# Check the most common install paths
@(
    'C:\Program Files (x86)\Steam\steamapps\common\Windrose',
    'C:\Steam\steamapps\common\Windrose'
) | ForEach-Object { if (Test-Path $_) { Write-Host "Found: $_" } else { Write-Host "Not found: $_" } }
```

To check Steam's registered library folders:
```powershell
$vdf = 'C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf'
if (Test-Path $vdf) { Select-String -Path $vdf -Pattern '"path"' }
```

**How to read the output:** If no install is found at the common paths, check your Steam library list (Steam > Settings > Storage) for the drive where Windrose is installed, then append `\steamapps\common\Windrose` to that path.

---

## 11. Game version

**What it checks:** The file version of the Windrose executable.  
**Why it matters:** Version mismatches between client and server cause "version mismatch" disconnects. After a patch, both the client and dedicated server must be on the same version.

```powershell
$installPath = 'C:\Program Files (x86)\Steam\steamapps\common\Windrose'  # adjust if needed
$exe = Get-ChildItem $installPath -Recurse -Include '*.exe' -ErrorAction SilentlyContinue |
       Where-Object { $_.Name -match 'Windrose|R5' } | Select-Object -First 1
if ($exe) { Write-Host "$($exe.FullName) | $($exe.VersionInfo.FileVersion)" } else { Write-Host 'No Windrose/R5 exe found.' }
```

**How to read the output:** A version string like `1.0.0.12345`. Compare the number from the client machine against the dedicated server's same command. If they differ, the older one needs to update via Steam.

---

## 12. Recent crash logs (Windows Event Log)

**What it checks:** Windows Application Event Log for errors from Windrose, Steam, or Windows Error Reporting.  
**Why it matters:** Crashes appear in the Event Log even if the game closes silently with no dialog. This tells you whether recent failures were actual crashes vs. clean exits.

```powershell
Get-WinEvent -LogName Application -MaxEvents 250 -ErrorAction SilentlyContinue |
    Where-Object {
        $_.LevelDisplayName -in @('Error','Critical') -and (
            $_.ProviderName -match 'Application Error|Windows Error Reporting|Steam|Windrose' -or
            $_.Message      -match 'Windrose|R5|steam'
        )
    } |
    Select-Object -First 25 TimeCreated, ProviderName, Id, Message |
    Format-List
```

**How to read the output:** Look at `ProviderName`:
- `Application Error` — a program crashed. The `Message` field names the faulting module (e.g. `Windrose.exe` or a DLL).
- `Windows Error Reporting` — Windows collected a crash dump. The game almost certainly hard-crashed.
- No results — no detected crashes. The disconnections may be network-level, not app crashes.

---

## 13. DNS resolution of a specific server (mode 2)

**What it checks:** Whether a server's hostname resolves to an IP address.  
**Why it matters:** If you're connecting by hostname (not IP), DNS must work first. A hostname that doesn't resolve produces a "server not found" error before any game traffic is sent.

```powershell
Resolve-DnsName -Name 'your.server.hostname' -ErrorAction SilentlyContinue
```

**How to read the output:** You want `Type : A` records with IPv4 addresses. `Type : AAAA` records only (no A records) means the server only has an IPv6 address — Windrose may not be able to connect. No results at all means DNS lookup failed entirely.

---

## 14. Ping a server (mode 2)

**What it checks:** Basic network-layer reachability and latency to the server.  
**Why it matters:** Ping tells you whether the route exists and how long it takes. High latency (>150 ms) causes rubber-banding. Ping failure alone does not mean the server is down — most servers block ICMP.

```powershell
Test-Connection -TargetName '1.2.3.4' -Count 4
```

**How to read the output:** `Latency` shows round-trip time in milliseconds. Under 60 ms is excellent, under 120 ms is fine, over 150 ms will feel laggy. All four packets failing means either ICMP is blocked (common) or the route is genuinely broken — run a traceroute to check.

---

## 15. Traceroute to a server (mode 2)

**What it checks:** The hop-by-hop network path from your machine to the server.  
**Why it matters:** Shows which provider or router is dropping or delaying packets, which helps narrow down whether the problem is your ISP, an intermediate network, or the server's hosting provider.

```powershell
tracert 1.2.3.4
```

Or in PowerShell:
```powershell
Test-NetConnection -ComputerName '1.2.3.4' -TraceRoute
```

**How to read the output:** Each line is one router hop. `* * *` means that router doesn't respond to traceroute — this is normal for most hops and doesn't mean the path is broken. Look for hops where latency suddenly jumps by 50 ms or more (that's where the slow link is). If all hops after a certain point show `* * *` and the destination is unreachable, the path is blocked at that point.

---

## 16. TCP port test to a specific server (mode 2)

**What it checks:** Whether the server's game port is accepting TCP connections.  
**Why it matters:** Confirms the port is open from your network. Windrose uses UDP for most game traffic, but if TCP is blocked, UDP is very likely blocked too (same firewall rules usually cover both). A TCP failure points to a port-forwarding or server-firewall problem.

```powershell
Test-NetConnection -ComputerName '1.2.3.4' -Port 7777 -InformationLevel Detailed
```

**How to read the output:** `TcpTestSucceeded : True` means the port is open and something answered. False means the port is closed or filtered. If you're the server admin, check that:
1. The server process is running and bound to port 7777
2. Port 7777 is forwarded on the router (if behind NAT)
3. Windows Firewall allows inbound on port 7777

---

## 17. ServerDescription.json (Shipwright)

**What it checks:** The dedicated server's identity and connection configuration file.  
**Why it matters:** A missing or malformed ServerDescription.json is the most common reason a server starts but players cannot connect by invite code. The invite code must be at least 6 alphanumeric characters.

```powershell
# Replace path with your actual server install location
$sd = Get-Content 'C:\WindroseServer\ServerDescription.json' -Raw | ConvertFrom-Json
$sd | Select-Object InviteCode, ServerName, MaxPlayerCount, IsPasswordProtected, P2pProxyAddress
```

To check just whether the invite code is long enough:
```powershell
$sd = Get-Content 'C:\WindroseServer\ServerDescription.json' -Raw | ConvertFrom-Json
if ($sd.InviteCode.Length -ge 6) { 'InviteCode OK' } else { "InviteCode too short: $($sd.InviteCode.Length) chars (need 6+)" }
```

**How to read the output:**
- `InviteCode` — must be 6+ alphanumeric characters, case-sensitive. Players type this exactly.
- `MaxPlayerCount` — hard cap on simultaneous players.
- `IsPasswordProtected` — if `True`, make sure `Password` is also set.
- `P2pProxyAddress` — leave at `127.0.0.1` unless you have a specific reason to change it.

If `ConvertFrom-Json` throws an error, the file is malformed JSON. Open it in VS Code or Notepad++ with JSON syntax highlighting to find the problem (usually a missing comma, extra brace, or unmatched quote).

---

## 18. WorldDescription.json (Shipwright)

**What it checks:** Whether the world configuration file exists.  
**Why it matters:** A missing WorldDescription.json causes the server to use defaults. A malformed one can prevent the world from loading entirely.

```powershell
# Check it exists and parses
$wd = Get-Content 'C:\WindroseServer\WorldDescription.json' -Raw -ErrorAction SilentlyContinue
if ($wd) { $wd | ConvertFrom-Json } else { 'WorldDescription.json not found - server will use defaults.' }
```

**How to read the output:** If the file exists and parses without errors, it's valid. If `ConvertFrom-Json` throws, the file is malformed — delete it and let the server regenerate it with defaults.

---

## 19. Save profiles (Shipwright)

**What it checks:** Whether the server's save data directory exists and contains world data.  
**Why it matters:** If you're restoring a save from another machine or after a reinstall, the save data must be in the right location. Wrong path = server starts fresh instead of loading the existing world.

```powershell
$savePath = 'C:\WindroseServer\R5\Saved\SaveProfiles'  # adjust to your install path
if (Test-Path $savePath) {
    $files     = Get-ChildItem $savePath -Recurse -File
    $totalSize = [math]::Round(($files | Measure-Object Length -Sum).Sum / 1MB, 2)
    Write-Host "Files: $($files.Count)  Total: $totalSize MB"
    # Check for RocksDB world data
    if (Test-Path (Join-Path $savePath 'Default\RocksDB')) {
        Write-Host 'RocksDB world data found.'
    } else {
        Write-Host 'No RocksDB data found - world may not have been created yet.'
    }
} else {
    Write-Host 'SaveProfiles folder not found.'
}
```

**How to read the output:** For a live server, you expect files under `SaveProfiles\Default\RocksDB\<version>\Worlds\`. If you copied saves from another machine, verify the folder structure matches. A fresh server (never been started) will have an empty or missing SaveProfiles directory — that's normal.

---

## 20. Server log — last 100 lines (Shipwright)

**What it checks:** The tail of the server's main log file.  
**Why it matters:** The log is the single most useful artifact for diagnosing server problems. It shows startup errors, player join events, world initialization, and crash callstacks.

```powershell
Get-Content 'C:\WindroseServer\R5\Saved\Logs\R5.log' -Tail 100 -ErrorAction SilentlyContinue
```

**How to read the output:**
- A clean startup ends with lines about world initialization and a "ready" or "listening" message.
- Player join attempts show up as connection events — if they fail, the log often says why.
- A crash produces a callstack starting with `ASSERTION FAILED` or `Fatal error`. The lines immediately above the callstack usually name the cause.
- An abrupt end with no shutdown message means the process was killed or crashed with no log flush — check the Windows Event Log (check 12) for the corresponding crash entry.

---

## 21. Which ports the server is listening on (Shipwright)

**What it checks:** Whether the server process is actually bound to its expected ports.  
**Why it matters:** If port 7777 isn't in the list, the server either hasn't started, crashed silently, or is bound to a different port than expected. Port-forwarding a port the server isn't listening on does nothing.

```powershell
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
    Where-Object { $_.LocalPort -in @(7777, 27015, 27036) } |
    Select-Object LocalPort, LocalAddress, State, OwningProcess |
    Sort-Object LocalPort
```

To identify which process owns a port:
```powershell
$pid = (Get-NetTCPConnection -LocalPort 7777 -State Listen -ErrorAction SilentlyContinue).OwningProcess
if ($pid) { Get-Process -Id $pid -ErrorAction SilentlyContinue | Select-Object Id, ProcessName, Path }
```

**How to read the output:** You want port 7777 with `State : Listen`. `LocalAddress` of `0.0.0.0` means the server is listening on all interfaces (correct). `127.0.0.1` means it's only listening locally and players on the internet cannot connect. If nothing shows up for 7777, the server is not running or has crashed.

---

## 22. Firewall rules for the dedicated server (Shipwright)

**What it checks:** Whether Windows Firewall has allow rules for the server executable.  
**Why it matters:** Even if the server is running and ports are listening, Windows Firewall silently drops inbound connections if no allow rule exists for the server process.

```powershell
Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue |
    Where-Object { $_.Program -match 'Windrose|R5' } |
    ForEach-Object {
        $rule = Get-NetFirewallRule -AssociatedNetFirewallApplicationFilter $_ -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($rule) { "$($rule.DisplayName) | Dir: $($rule.Direction) | Action: $($rule.Action) | Profile: $($rule.Profile)" }
    }
```

**How to read the output:** You want `Action : Allow` rules for both `Direction : Inbound` and `Direction : Outbound`, covering at least the `Private` profile (or `Any`). If you see `Action : Block` or no rules at all, add them manually: Windows Security > Firewall & network protection > Advanced settings > Inbound Rules > New Rule > Program > browse to the server exe > Allow the connection.

---

## ISP known-culprit reference table

ISPs confirmed to block Windrose:

| ISP | Feature to disable | Where |
|-----|--------------------|-------|
| Spectrum (Charter) | Security Shield | My Spectrum app > Internet > Security Shield > OFF |
| Xfinity (Comcast) | xFi Advanced Security | Xfinity app > WiFi > See Network > Advanced Security > OFF |
| BT | Web Protect | my.bt.com > Broadband > Manage Web Protect > OFF |
| Ziggo (NL) | Default domain filter | mijn.ziggo.nl > Security/router settings |

ISPs known to block similar P2P games (Rust, Palworld, Ark):

| ISP | Feature | Where |
|-----|---------|-------|
| Cox | Cox Security Suite | Cox webmail/panel > Security Suite |
| AT&T | ActiveArmor | Smart Home Manager app > ActiveArmor |
| CenturyLink/Lumen | Connection Shield | centurylink.com/myaccount > Internet |
| Verizon | Network Protection | My Verizon app > Services > Digital Secure |
| T-Mobile Home Internet | Network Protection | T-Life app > Home Internet > Network settings |
| Optimum (Altice) | Optimum Internet Protection | optimum.net account > Internet Security |
| Frontier | Secure (Whole-Home) | frontier.com/helpcenter > Internet Security |
| Sky | Broadband Shield | sky.com/mysky > Broadband Shield > set to None |
| Virgin Media | Web Safe | virginmedia.com/my-account > Web Safe |
| TalkTalk | HomeSafe | my.talktalk.co.uk > HomeSafe |
| Orange (FR/ES) | Livebox parental/security | Livebox admin 192.168.1.1 > Security |
| Free (FR) | Freebox security | freebox.fr > Securite |
| Deutsche Telekom | Default firewall | Speedport admin > Firewall |
| Vodafone (EU) | Secure Net | My Vodafone app > Secure Net |
| Rogers (CA) | Shield | MyRogers app > Internet > Shield |
| Bell (CA) | Internet Security | MyBell account > Internet > Security |
| Telus (CA) | Online Security | My Telus account > Internet |
| Telstra (AU) | Smart Modem security | My Telstra app > Home Internet |
| Optus (AU) | Internet Security | My Optus app > Internet > Security |

**Note:** Dedicated server hosting providers (SurvivalServers, LOW.MS, g-portal, etc.) run on business-grade connections that do not have these consumer security filters. If your hosted server works fine but players on certain ISPs can't connect, the block is on the player's residential end, not the server or Windrose's backend.
