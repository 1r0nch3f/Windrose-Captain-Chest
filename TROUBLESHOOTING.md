# Windrose Troubleshooting Guide

Step-by-step manual checks for connection and server issues.
Every command here mirrors what **Captain's Chest** does automatically.
If you want the automated version, grab it from the repo.

---

## Quick start: which section do you need?

| Symptom | Go to |
|---------|-------|
| Loads then kicked back to main menu | [Section 1](#1-check-windrose-backend-endpoints) then [Section 2](#2-identify-your-isp-security-feature) |
| Connection Services shows N/A in-game | [Section 1](#1-check-windrose-backend-endpoints) |
| Can't connect to a specific hosted/private server | [Section 5](#5-cant-reach-a-specific-server) |
| Friends can connect but I can't | [Section 2](#2-identify-your-isp-security-feature) then [Section 3](#3-check-port-3478-specifically) |
| Dedicated server world keeps resetting / progress lost | [Section 7](#7-dedicated-server-world-id-validation) |
| Transferring a save to a dedicated server | [Section 8](#8-manual-save-transfer) |

---

## 1. Check Windrose backend endpoints

**What this tells you:** whether the Windrose Connection Services are reachable from your machine. If any of these fail while Google DNS can resolve them, your ISP is blocking them.

Open PowerShell and paste this entire block:

```powershell
$endpoints = @(
    @{ Label = 'EU/NA Gateway (primary)';   Host = 'r5coopapigateway-eu-release.windrose.support';    Port = 443  }
    @{ Label = 'EU/NA Gateway (failover)';  Host = 'r5coopapigateway-eu-release-2.windrose.support';  Port = 443  }
    @{ Label = 'CIS Gateway (primary)';     Host = 'r5coopapigateway-ru-release.windrose.support';    Port = 443  }
    @{ Label = 'CIS Gateway (failover)';    Host = 'r5coopapigateway-ru-release-2.windrose.support';  Port = 443  }
    @{ Label = 'SEA Gateway (primary)';     Host = 'r5coopapigateway-kr-release.windrose.support';    Port = 443  }
    @{ Label = 'SEA Gateway (failover)';    Host = 'r5coopapigateway-kr-release-2.windrose.support';  Port = 443  }
    @{ Label = 'Sentry (error reporting)';  Host = 'sentry.windrose.support';                         Port = 443  }
    @{ Label = 'STUN/TURN (P2P signaling)'; Host = 'windrose.support';                               Port = 3478 }
)

Write-Host "`n=== Windrose endpoint check ===" -ForegroundColor Cyan

foreach ($ep in $endpoints) {
    # Check system DNS vs Google DNS
    $sysDns = try {
        $r = Resolve-DnsName -Name $ep.Host -Type A -QuickTimeout -ErrorAction Stop
        $ips = @($r | Where-Object { $_.Type -eq 'A' } | Select-Object -ExpandProperty IPAddress -Unique)
        if ($ips) { "OK -> $($ips -join ', ')" } else { "NXDOMAIN" }
    } catch { "NXDOMAIN" }

    $googleDns = try {
        $r = Resolve-DnsName -Name $ep.Host -Type A -Server '8.8.8.8' -QuickTimeout -ErrorAction Stop
        $ips = @($r | Where-Object { $_.Type -eq 'A' } | Select-Object -ExpandProperty IPAddress -Unique)
        if ($ips) { "OK -> $($ips -join ', ')" } else { "NXDOMAIN" }
    } catch { "NXDOMAIN" }

    # TCP reachability
    $tcpOk = $false
    if ($sysDns -like 'OK*') {
        try {
            $tcp = [System.Net.Sockets.TcpClient]::new()
            $tcpOk = $tcp.BeginConnect($ep.Host, $ep.Port, $null, $null).AsyncWaitHandle.WaitOne(3000) -and $tcp.Connected
            $tcp.Close()
        } catch { }
    }

    $color = if ($tcpOk) { 'Green' } else { 'Red' }
    $status = if ($tcpOk) { 'REACHABLE' } else { 'BLOCKED/DOWN' }

    Write-Host "`n$($ep.Label)" -ForegroundColor Cyan
    Write-Host "  System DNS: $sysDns"
    Write-Host "  Google DNS: $googleDns"
    Write-Host "  TCP $($ep.Port): $status" -ForegroundColor $color

    if ($sysDns -eq 'NXDOMAIN' -and $googleDns -like 'OK*') {
        Write-Host "  *** ISP BLOCKING: resolves on Google DNS but not your system DNS ***" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Done ===" -ForegroundColor Cyan
```

**Reading the results:**

- **All REACHABLE** - backend is up on your end. Move to [Section 4](#4-check-windows-firewall) for other causes.
- **STUN/TURN :3478 BLOCKED** with everything else OK - ISP security feature blocking P2P signaling. Go to [Section 2](#2-identify-your-isp-security-feature).
- **System DNS: NXDOMAIN, Google DNS: OK** - your ISP DNS is blocking the domain. Go to [Section 2](#2-identify-your-isp-security-feature).
- **ALL blocked** - either the backend is down (check playwindrose.com and Discord #status) or your firewall is blocking all outbound HTTPS.

---

## 2. Identify your ISP security feature

**What this tells you:** which specific feature on your ISP's router is likely blocking the connection, and exactly where to turn it off.

### Step 1 - find your public IP

```powershell
(Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing).Content
```

### Step 2 - look up your ISP

```powershell
$ip = (Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing).Content.Trim()
(Invoke-WebRequest -Uri "https://ipinfo.io/$ip/json" -UseBasicParsing).Content | ConvertFrom-Json | Select-Object org, city, country
```

### Step 3 - match your ISP to the table below

Find your ISP and follow the toggle instructions:

| ISP | Feature to disable | Where to find it | Confirmed Windrose block? |
|-----|--------------------|-----------------|--------------------------|
| **Spectrum (Charter)** | Security Shield | My Spectrum app > Internet > Security Shield > OFF | YES |
| **Xfinity (Comcast)** | xFi Advanced Security | Xfinity app > WiFi > See Network > Advanced Security > OFF | YES |
| **BT** | Web Protect | my.bt.com > Broadband > Manage Web Protect > OFF | YES |
| **Ziggo (NL)** | Default domain filter | mijn.ziggo.nl > Security/router settings | YES |
| Cox | Security Suite | Cox panel > Security Suite > disable | Likely |
| AT&T | ActiveArmor | Smart Home Manager app > ActiveArmor > Internet Security > OFF | Likely |
| CenturyLink/Lumen | Connection Shield | centurylink.com/myaccount > Internet > Connection Shield | Likely |
| Verizon | Network Protection | My Verizon app > Services > Digital Secure | Likely |
| T-Mobile Home | Network Protection | T-Life app > Home Internet > Network settings | Likely |
| Optimum (Altice) | Internet Protection | optimum.net > Internet Security > disable | Likely |
| Frontier | Secure Whole-Home | frontier.com/helpcenter > Internet Security > disable | Likely |
| Sky (UK) | Broadband Shield | sky.com/mysky > Broadband Shield > None | Likely |
| Virgin Media (UK) | Web Safe | virginmedia.com/my-account > Web Safe > disable | Likely |
| TalkTalk (UK) | HomeSafe | my.talktalk.co.uk > HomeSafe > disable | Likely |
| Orange (FR/ES) | Livebox security | Livebox admin 192.168.1.1 > Security > OFF | Likely |
| Vodafone (EU) | Secure Net | My Vodafone app > Secure Net > disable | Likely |
| Rogers (CA) | Shield | MyRogers app > Internet > Shield > OFF | Likely |
| Bell (CA) | Internet Security | MyBell account > Internet > Security > disable | Likely |
| Telstra (AU) | Smart Modem security | My Telstra app > Home Internet > security settings | Likely |

**If your ISP isn't listed:** look for any "Security", "Threat Protection", "Safe Browsing", or "Parental Controls" feature in your ISP's app or router admin page (usually 192.168.1.1 or 192.168.0.1) and try disabling it.

**Quick test to confirm it's the ISP:** switch to your phone's mobile hotspot and try the game. If it works on hotspot, it's your ISP or home router blocking the connection, not your PC.

---

## 3. Check port 3478 specifically

Port 3478 is the STUN/TURN port used for P2P connection establishment. Without it, the game literally cannot connect players to each other.

```powershell
# Test TCP on port 3478
try {
    $tcp = [System.Net.Sockets.TcpClient]::new()
    $r   = $tcp.BeginConnect('windrose.support', 3478, $null, $null)
    $ok  = $r.AsyncWaitHandle.WaitOne(3000) -and $tcp.Connected
    $tcp.Close()
    if ($ok) {
        Write-Host 'Port 3478 REACHABLE' -ForegroundColor Green
    } else {
        Write-Host 'Port 3478 BLOCKED - this is the P2P signaling port. See Section 2 to fix.' -ForegroundColor Red
    }
} catch {
    Write-Host "Port 3478 test failed: $($_.Exception.Message)" -ForegroundColor Red
}
```

If 3478 is blocked: disable your ISP's security feature (Section 2), or as a workaround try hosting via **Direct IP mode** (Host a Game > Direct IP tab > port 7777) which bypasses the Connection Services path entirely.

---

## 4. Check Windows Firewall

**What this tells you:** whether Windows Firewall has rules for Windrose and Steam, and whether the firewall itself could be the blocker.

```powershell
# Check firewall profile states
Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction | Format-Table -AutoSize
```

```powershell
# Check for Windrose/Steam application rules
Get-NetFirewallApplicationFilter |
    Where-Object { $_.Program -match 'Steam|Windrose|R5' } |
    Select-Object Program, @{N='Action';E={$_.Action}} |
    Format-Table -AutoSize
```

**If no rules appear for Windrose or Steam:** they may not have been added yet. Run the game once, accept any firewall prompts, then check again.

**To temporarily disable Windows Firewall for testing** (re-enable after):

```powershell
# Disable (run as admin)
Set-NetFirewallProfile -All -Enabled False

# Re-enable (do this after testing)
Set-NetFirewallProfile -All -Enabled True
```

If the game works with the firewall off but not on, you need to add exceptions for `Windrose.exe` and `steam.exe`.

---

## 5. Can't reach a specific server

Use these commands when you have a server IP or hostname and can't connect to it specifically.

### DNS resolution

```powershell
# Replace server.example.com with the server IP or hostname
Resolve-DnsName -Name 'server.example.com' | Where-Object { $_.IPAddress } | Select-Object Name, IPAddress
```

### Ping

```powershell
Test-Connection -TargetName 'server.example.com' -Count 4
```

Note: some servers block ICMP (ping). A failed ping does not mean the server is down.

### TCP port test

```powershell
# Test the default game port (replace 7777 and the IP/hostname as needed)
Test-NetConnection -ComputerName 'server.example.com' -Port 7777 -InformationLevel Detailed
```

### Test all Windrose port presets

```powershell
$target = 'server.example.com'   # change this
$ports  = @(
    @{ Port = 7777;  Protocol = 'UDP/TCP'; Purpose = 'Default game port / Direct IP' }
    @{ Port = 7778;  Protocol = 'UDP';     Purpose = 'Secondary game port' }
    @{ Port = 27015; Protocol = 'UDP/TCP'; Purpose = 'Steam query / master' }
    @{ Port = 27036; Protocol = 'UDP/TCP'; Purpose = 'Steam streaming / P2P' }
)
foreach ($p in $ports) {
    $r = Test-NetConnection -ComputerName $target -Port $p.Port -WarningAction SilentlyContinue
    $state = if ($r.TcpTestSucceeded) { 'OPEN (TCP)' } else { 'closed/filtered' }
    Write-Host ("{0,-6} {1,-10} {2,-38} -> {3}" -f $p.Port, $p.Protocol, $p.Purpose, $state)
}
Write-Host '(UDP results cannot be confirmed from the client side)'
```

### Traceroute

Shows the network hops between you and the server. Useful for identifying where packets are being dropped.

```powershell
tracert server.example.com
```

---

## 6. Check DNS and hosts file

### View your hosts file

Malware or software sometimes adds entries to the hosts file that redirect game domains to 127.0.0.1, which silently breaks connections.

```powershell
Get-Content "$env:WINDIR\System32\drivers\etc\hosts"
```

Look for any lines containing `windrose` or `r5coop`. If you find any, remove them (you need to edit the file as admin).

### Check how your system resolves a Windrose domain

```powershell
# Compare system DNS vs Google DNS for a Windrose endpoint
$host = 'r5coopapigateway-eu-release.windrose.support'

Write-Host 'System DNS:'
Resolve-DnsName -Name $host -Type A -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress }

Write-Host "`nGoogle DNS (8.8.8.8):"
Resolve-DnsName -Name $host -Type A -Server '8.8.8.8' -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress }
```

If system DNS returns nothing but Google DNS returns an IP, your ISP is blocking the domain at the DNS level. Fix: switch your DNS to Google (`8.8.8.8` / `8.8.4.4`) or Cloudflare (`1.1.1.1`):

1. Settings > Network & Internet > your connection > Properties
2. Edit DNS server assignment > Manual > IPv4 ON
3. Preferred: `8.8.8.8`  Alternate: `8.8.4.4`
4. Save, then flush: `ipconfig /flushdns`

### Check for IPv6 prioritization issues

Windrose is IPv4-only. If your system prefers IPv6 for Windrose domains, connections will silently fail.

```powershell
Resolve-DnsName -Name 'r5coopapigateway-eu-release.windrose.support' | Select-Object Type, IPAddress
```

If you only see `AAAA` (IPv6) records and no `A` (IPv4) records, run this as admin to force IPv4 preference:

```powershell
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" /v DisabledComponents /t REG_DWORD /d 32 /f
```

Then restart your PC. To revert: run the same command with `/d 0` instead.

---

## 7. Dedicated server World ID validation

**What this tells you:** whether the three IDs that must match are actually matching. Mismatches cause the server to generate a fresh world on every start instead of loading your saved one.

The three values that must all be identical:
1. The world **folder name** in `...\Worlds\{WorldID}`
2. The `islandId` field inside `WorldDescription.json` inside that folder
3. The `WorldIslandId` field in `ServerDescription.json`

### Read what world your server is configured to load

```powershell
# Update the path to match your server install location
$serverPath = 'C:\WindroseServer'
$descFile   = Join-Path $serverPath 'ServerDescription.json'

$sd = Get-Content $descFile -Raw | ConvertFrom-Json
Write-Host "Configured WorldIslandId: $($sd.ServerDescription_Persistent.WorldIslandId)"
```

### List all world folders on the server and check their IDs

```powershell
$serverPath  = 'C:\WindroseServer'   # update to your server path
$saveRoot    = Join-Path $serverPath 'R5\Saved\SaveProfiles\Default\RocksDB'
$serverDesc  = Join-Path $serverPath 'ServerDescription.json'

$configuredId = (Get-Content $serverDesc -Raw | ConvertFrom-Json).ServerDescription_Persistent.WorldIslandId
Write-Host "ServerDescription.json WorldIslandId: $configuredId`n"

Get-ChildItem -Path $saveRoot -Filter 'WorldDescription.json' -Recurse | ForEach-Object {
    $folderId = Split-Path $_.DirectoryName -Leaf
    $wd       = Get-Content $_.FullName -Raw | ConvertFrom-Json
    $descId   = $wd.WorldDescription.islandId

    Write-Host "World folder: $folderId"
    Write-Host "  islandId in WorldDescription.json: $descId"
    Write-Host "  World name: $($wd.WorldDescription.WorldName)"

    if ($folderId -ne $descId) {
        Write-Host "  [FAIL] Folder name != islandId - MISMATCH" -ForegroundColor Red
    } else {
        Write-Host "  [OK  ] Folder matches islandId" -ForegroundColor Green
    }

    if ($folderId -eq $configuredId) {
        Write-Host "  [OK  ] This is the ACTIVE world" -ForegroundColor Green
    } else {
        Write-Host "  [INFO] Not the active world (server will load '$configuredId')" -ForegroundColor Gray
    }
    Write-Host ''
}
```

### Fix a mismatch

If the IDs don't match, the safest fix is to update `ServerDescription.json` to match the existing folder name (do NOT rename the folder - the database uses it as a key):

```powershell
$serverPath   = 'C:\WindroseServer'   # update
$descFile     = Join-Path $serverPath 'ServerDescription.json'
$correctId    = 'PASTE_THE_CORRECT_FOLDER_NAME_HERE'

$sd = Get-Content $descFile -Raw | ConvertFrom-Json
$sd.ServerDescription_Persistent.WorldIslandId = $correctId
Set-Content -Path $descFile -Value ($sd | ConvertTo-Json -Depth 10)
Write-Host "WorldIslandId updated to: $correctId"
```

---

## 8. Manual save transfer

Always back up before moving saves. Always do this with both the server AND game client fully stopped.

### Check for running processes first

```powershell
Get-Process | Where-Object { $_.ProcessName -match 'WindroseServer|Windrose|R5' } | Select-Object ProcessName, Id
```

If anything shows up, close it before continuing.

### Backup a world folder before transferring

```powershell
# Replace paths as needed
$source = 'C:\path\to\your\world\folder'
$backup = "$env:USERPROFILE\Desktop\WindroseBackup_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
Copy-Item -Path $source -Destination $backup -Recurse
Write-Host "Backup created: $backup"
```

### Client to server

```powershell
# Update all four paths to match your setup
$worldId     = 'YOUR_WORLD_FOLDER_NAME_HERE'     # exact folder name from client saves
$gameVersion = '0.10.0'                           # match your game version folder
$clientWorld = "$env:LOCALAPPDATA\R5\Saved\SaveProfiles\YOUR_PROFILE_ID\RocksDB\$gameVersion\Worlds\$worldId"
$serverPath  = 'C:\WindroseServer'
$destRoot    = "$serverPath\R5\Saved\SaveProfiles\Default\RocksDB\$gameVersion\Worlds"
$destPath    = "$destRoot\$worldId"

# Step 1: back up destination if it exists
if (Test-Path $destPath) {
    $backup = "$env:USERPROFILE\Desktop\WindroseBackup_server_$worldId_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
    Copy-Item -Path $destPath -Destination $backup -Recurse
    Write-Host "Destination backed up to: $backup"
}

# Step 2: copy the world
New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
Copy-Item -Path $clientWorld -Destination $destPath -Recurse -Force
Write-Host "World copied to server."

# Step 3: update ServerDescription.json
$descFile = "$serverPath\ServerDescription.json"
$sd = Get-Content $descFile -Raw | ConvertFrom-Json
$sd.ServerDescription_Persistent.WorldIslandId = $worldId
Set-Content -Path $descFile -Value ($sd | ConvertTo-Json -Depth 10)
Write-Host "ServerDescription.json updated - WorldIslandId set to $worldId"
```

### Server to client

```powershell
$worldId     = 'YOUR_WORLD_FOLDER_NAME_HERE'
$gameVersion = '0.10.0'
$serverWorld = "C:\WindroseServer\R5\Saved\SaveProfiles\Default\RocksDB\$gameVersion\Worlds\$worldId"
$profileId   = 'YOUR_STEAM_PROFILE_ID'           # the folder name under SaveProfiles
$destRoot    = "$env:LOCALAPPDATA\R5\Saved\SaveProfiles\$profileId\RocksDB\$gameVersion\Worlds"
$destPath    = "$destRoot\$worldId"

# Back up destination if it exists
if (Test-Path $destPath) {
    $backup = "$env:USERPROFILE\Desktop\WindroseBackup_client_$worldId_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
    Copy-Item -Path $destPath -Destination $backup -Recurse
    Write-Host "Destination backed up to: $backup"
}

New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
Copy-Item -Path $serverWorld -Destination $destPath -Recurse -Force
Write-Host "World copied to client. Choose 'local' saves when starting the game if prompted."
```

---

## 9. Check running processes and game version

### What's currently running

```powershell
Get-Process | Where-Object { $_.ProcessName -match 'steam|Windrose|R5' } |
    Select-Object ProcessName, Id, @{N='Version';E={$_.FileVersion}}, Path |
    Format-List
```

### Find the game install and check exe version

```powershell
# Find Windrose in Steam libraries
$steamRoot = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -ErrorAction SilentlyContinue).InstallPath
if ($steamRoot) {
    Get-ChildItem "$steamRoot\steamapps\common\Windrose" -Recurse -Include *.exe -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'Windrose|R5' } |
        Select-Object FullName, @{N='Version';E={$_.VersionInfo.FileVersion}} |
        Format-List
}
```

### Check recent crash events

```powershell
Get-WinEvent -LogName Application -MaxEvents 250 -ErrorAction SilentlyContinue |
    Where-Object {
        $_.LevelDisplayName -in @('Error','Critical') -and (
            $_.ProviderName -match 'Application Error|Windows Error Reporting' -or
            $_.Message      -match 'Windrose|R5'
        )
    } |
    Select-Object -First 10 TimeCreated, ProviderName, Message |
    Format-List
```

---

## 10. CGNAT (can't host, others can join fine)

CGNAT means your ISP puts multiple customers behind one shared public IP. You don't have a real public IP of your own, so the game can't punch through to establish a hosted session.

**To check if you're behind CGNAT:**

```powershell
# Your public IP
$public = (Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing).Content.Trim()

# Your router's IP (your default gateway)
$gateway = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' | Sort-Object RouteMetric | Select-Object -First 1).NextHop

Write-Host "Public IP (what the internet sees): $public"
Write-Host "Gateway IP (your router): $gateway"
Write-Host ''
Write-Host "If these are in completely different ranges and your public IP is in"
Write-Host "100.64.x.x - 100.127.x.x, you are behind CGNAT."
```

**Workarounds for CGNAT:**
- Use **Direct IP mode** with a VPN or reverse proxy (some players use ZeroTier or Tailscale)
- Rent a cheap VPS and run the dedicated server there instead
- Call your ISP and ask for a static public IP (some charge extra)
- Use a third-party server host (SurvivalServers, LOW.MS, g-portal) - they're not affected because they have real business IPs

---

## Still stuck?

1. Run **Captain's Chest** for a full automated report to share with helpers
2. Post the redacted report in the Discord `#help` channel
3. Include: your ISP, your country, whether hotspot works vs home network

Fair winds, Captain.
