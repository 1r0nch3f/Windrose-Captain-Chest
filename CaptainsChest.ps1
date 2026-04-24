<#
.SYNOPSIS
    Captain's Chest - diagnostic and server toolkit for Windrose crews.

.DESCRIPTION
    Three modes of operation:

      1. Connection trouble  - ISP detection, fleet endpoint check, firewall,
                               game version, recent errors, hosts file.
                               The 90% case. Runs in ~20 seconds.

      2. Can't reach server  - Everything in mode 1, plus DNS resolution,
                               ping, TCP port tests, and traceroute to a
                               specific server IP or hostname.

      3. Shipwright          - Dedicated server wizard:
                                 - Setup: find game install, copy server out
                                 - Save transfer: client <-> server with
                                   backup, ID triple-match validation, and
                                   pre-flight process check
                                 - Validate: check config IDs without moving files

    Outputs a timestamped chest on the Desktop:
      CaptainsLog.txt           - full human-readable report
      CaptainsLog.md            - pasteable markdown for Discord/forums
      CaptainsLog_REDACTED.txt  - optional scrubbed copy safe to post publicly
      CaptainsLog_REDACTED.md   - optional scrubbed markdown
      Manifest.csv              - pass/warn/fail findings
      Salvage/                  - collected game config and log files
      Chest_<timestamp>.zip     - the whole chest sealed for transport

    Shipwright mode does NOT produce a log - it is interactive only.

.PARAMETER OutputPath
    Root folder for the chest. Default: Desktop\WindroseCaptainChest

.PARAMETER ServerIP
    Server IP or hostname to test against (mode 2 only).

.PARAMETER ServerPort
    Port to test. Default: 7777.

.PARAMETER Mode
    ConnectionTrouble | CantReachServer | Shipwright | ''
    Default: prompts interactively.

.PARAMETER SkipTraceRoute
    Skip tracert in mode 2 (saves ~30 seconds).

.PARAMETER SkipNetworkTests
    Skip all remote network tests including fleet check.

.PARAMETER NoPause
    Don't wait for Enter at the end. Useful for automation.

.PARAMETER Redact
    Automatically create redacted copy without prompting.

.PARAMETER NoRedactPrompt
    Skip the redacted-copy prompt entirely.

.EXAMPLE
    .\CaptainsChest.ps1
    .\CaptainsChest.ps1 -Mode ConnectionTrouble -NoPause
    .\CaptainsChest.ps1 -Mode CantReachServer -ServerIP 1.2.3.4 -NoPause
    .\CaptainsChest.ps1 -Mode Shipwright
#>

param(
    [string]$OutputPath = "$env:USERPROFILE\Desktop\WindroseCaptainChest",
    [string]$ServerIP   = '',
    [int]   $ServerPort = 7777,
    [ValidateSet('ConnectionTrouble','CantReachServer','Shipwright','')]
    [string]$Mode = '',
    [switch]$SkipTraceRoute,
    [switch]$SkipNetworkTests,
    [switch]$NoPause,
    [switch]$Redact,
    [switch]$NoRedactPrompt
)

$ErrorActionPreference = 'SilentlyContinue'
Set-StrictMode -Version Latest

# -------------------------------------------------------------------------------
# Configuration - edit these if Windrose changes their infrastructure
# -------------------------------------------------------------------------------

$script:WindrosePortPresets = @(
    [pscustomobject]@{ Port = 7777;  Protocol = 'UDP/TCP'; Purpose = 'Default game / Direct IP host' }
    [pscustomobject]@{ Port = 7778;  Protocol = 'UDP';     Purpose = 'Secondary game port' }
    [pscustomobject]@{ Port = 27015; Protocol = 'UDP/TCP'; Purpose = 'Steam query / master' }
    [pscustomobject]@{ Port = 27036; Protocol = 'UDP/TCP'; Purpose = 'Steam streaming / P2P' }
)

$script:WindroseServiceEndpoints = @(
    [pscustomobject]@{ Name = 'EU/NA Gateway (primary)';   Host = 'r5coopapigateway-eu-release.windrose.support';    Port = 443;  Region = 'EU & NA' }
    [pscustomobject]@{ Name = 'EU/NA Gateway (failover)';  Host = 'r5coopapigateway-eu-release-2.windrose.support';  Port = 443;  Region = 'EU & NA' }
    [pscustomobject]@{ Name = 'CIS Gateway (primary)';     Host = 'r5coopapigateway-ru-release.windrose.support';    Port = 443;  Region = 'CIS' }
    [pscustomobject]@{ Name = 'CIS Gateway (failover)';    Host = 'r5coopapigateway-ru-release-2.windrose.support';  Port = 443;  Region = 'CIS' }
    [pscustomobject]@{ Name = 'SEA Gateway (primary)';     Host = 'r5coopapigateway-kr-release.windrose.support';    Port = 443;  Region = 'SEA' }
    [pscustomobject]@{ Name = 'SEA Gateway (failover)';    Host = 'r5coopapigateway-kr-release-2.windrose.support';  Port = 443;  Region = 'SEA' }
    [pscustomobject]@{ Name = 'Sentry (error reporting)';  Host = 'sentry.windrose.support';                         Port = 443;  Region = 'Global' }
    [pscustomobject]@{ Name = 'STUN/TURN (P2P signaling)'; Host = 'windrose.support';                               Port = 3478; Region = 'Global' }
)

$script:IspCulpritTable = @(
    # United States
    @{ Match = 'Spectrum|Charter';      Name = 'Spectrum (Charter)';     Feature = 'Security Shield';        Toggle = 'My Spectrum app > Internet > Security Shield > OFF';             KnownBlocksWindrose = $true  }
    @{ Match = 'Comcast|Xfinity';       Name = 'Xfinity (Comcast)';      Feature = 'xFi Advanced Security';  Toggle = 'Xfinity app > WiFi > See Network > Advanced Security > OFF';     KnownBlocksWindrose = $true  }
    @{ Match = 'Cox Communications';    Name = 'Cox';                    Feature = 'Security Suite';         Toggle = 'Cox panel > Security Suite > disable';                            KnownBlocksWindrose = $false }
    @{ Match = 'AT&T|AT&amp;T';         Name = 'AT&T';                   Feature = 'ActiveArmor';            Toggle = 'Smart Home Manager app > ActiveArmor > Internet Security > OFF'; KnownBlocksWindrose = $false }
    @{ Match = 'CenturyLink|Lumen';     Name = 'CenturyLink/Lumen';      Feature = 'Connection Shield';      Toggle = 'centurylink.com/myaccount > Internet > Connection Shield';        KnownBlocksWindrose = $false }
    @{ Match = 'Verizon';               Name = 'Verizon';                Feature = 'Network Protection';     Toggle = 'My Verizon app > Services > Digital Secure';                     KnownBlocksWindrose = $false }
    @{ Match = 'T-Mobile';              Name = 'T-Mobile Home Internet'; Feature = 'Network Protection';     Toggle = 'T-Life app > Home Internet > Network settings';                  KnownBlocksWindrose = $false }
    @{ Match = 'Optimum|Cablevision';   Name = 'Optimum (Altice)';       Feature = 'Internet Protection';    Toggle = 'optimum.net > Internet Security > disable';                      KnownBlocksWindrose = $false }
    @{ Match = 'Frontier';              Name = 'Frontier';               Feature = 'Secure Whole-Home';      Toggle = 'frontier.com/helpcenter > Internet Security > disable';           KnownBlocksWindrose = $false }
    # United Kingdom
    @{ Match = 'British Telecom|BT ';   Name = 'BT';                     Feature = 'Web Protect';            Toggle = 'my.bt.com > Broadband > Manage Web Protect > OFF';               KnownBlocksWindrose = $true  }
    @{ Match = 'Sky UK|Sky Broadband';  Name = 'Sky';                    Feature = 'Broadband Shield';       Toggle = 'sky.com/mysky > Broadband Shield > None';                        KnownBlocksWindrose = $false }
    @{ Match = 'Virgin Media';          Name = 'Virgin Media';           Feature = 'Web Safe';               Toggle = 'virginmedia.com/my-account > Web Safe > disable';                KnownBlocksWindrose = $false }
    @{ Match = 'TalkTalk';              Name = 'TalkTalk';               Feature = 'HomeSafe';               Toggle = 'my.talktalk.co.uk > HomeSafe > disable';                         KnownBlocksWindrose = $false }
    # Europe
    @{ Match = 'Ziggo|VodafoneZiggo';   Name = 'Ziggo (NL)';             Feature = 'Default domain filter'; Toggle = 'mijn.ziggo.nl > Security/router settings';                       KnownBlocksWindrose = $true  }
    @{ Match = 'Orange ';               Name = 'Orange (FR/ES)';         Feature = 'Livebox security';       Toggle = 'Livebox admin 192.168.1.1 > Security > OFF';                     KnownBlocksWindrose = $false }
    @{ Match = 'Free SAS|Free ';        Name = 'Free (FR)';              Feature = 'Freebox security';       Toggle = 'freebox.fr > Securite > adjust filtering';                        KnownBlocksWindrose = $false }
    @{ Match = 'Deutsche Telekom';      Name = 'Deutsche Telekom (DE)';  Feature = 'Default firewall';       Toggle = 'Speedport admin > Firewall > customize';                         KnownBlocksWindrose = $false }
    @{ Match = 'Vodafone';              Name = 'Vodafone (EU)';          Feature = 'Secure Net';             Toggle = 'My Vodafone app > Secure Net > disable';                         KnownBlocksWindrose = $false }
    # Canada
    @{ Match = 'Rogers Communications'; Name = 'Rogers (CA)';            Feature = 'Shield';                 Toggle = 'MyRogers app > Internet > Shield > OFF';                         KnownBlocksWindrose = $false }
    @{ Match = 'Bell Canada';           Name = 'Bell (CA)';              Feature = 'Internet Security';      Toggle = 'MyBell account > Internet > Security > disable';                 KnownBlocksWindrose = $false }
    @{ Match = 'Telus';                 Name = 'Telus (CA)';             Feature = 'Online Security';        Toggle = 'My Telus > Internet > Online Security';                          KnownBlocksWindrose = $false }
    # Australia
    @{ Match = 'Telstra';               Name = 'Telstra (AU)';           Feature = 'Smart Modem security';  Toggle = 'My Telstra app > Home Internet > security settings';             KnownBlocksWindrose = $false }
    @{ Match = 'Optus';                 Name = 'Optus (AU)';             Feature = 'Internet Security';      Toggle = 'My Optus app > Internet > Security > disable';                   KnownBlocksWindrose = $false }
)

$script:ServerSaveRoot = 'R5\Saved\SaveProfiles\Default\RocksDB'
$script:ServerDescFile = 'ServerDescription.json'

# -------------------------------------------------------------------------------
# Script-level state
# -------------------------------------------------------------------------------

$script:RootOut              = $null
$script:LogsOut              = $null
$script:ReportFile           = $null
$script:MarkdownFile         = $null
$script:Summary              = New-Object System.Collections.Generic.List[object]
$script:PublicIP             = $null
$script:WindroseInstallCache = $null

# -------------------------------------------------------------------------------
# Banner
# -------------------------------------------------------------------------------

function Show-Banner {
    Write-Host @"

     __        _____ _   _ ____  ____   ___  ____  _____
     \ \      / /_ _| \ | |  _ \|  _ \ / _ \/ ___|| ____|
      \ \ /\ / / | ||  \| | | | | |_) | | | \___ \|  _|
       \ V  V /  | || |\  | |_| |  _ <| |_| |___) | |___
        \_/\_/  |___|_| \_|____/|_| \_\\___/|____/|_____|
                 Captain's Chest  -  v2.0.0
                   "No crew left ashore"

"@ -ForegroundColor Yellow
}

# -------------------------------------------------------------------------------
# Output helpers
# -------------------------------------------------------------------------------

function Initialize-Output {
    $ts = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $script:RootOut      = Join-Path $OutputPath $ts
    $script:LogsOut      = Join-Path $script:RootOut 'Salvage'
    New-Item -ItemType Directory -Path $script:RootOut -Force | Out-Null
    New-Item -ItemType Directory -Path $script:LogsOut -Force | Out-Null
    $script:ReportFile   = Join-Path $script:RootOut 'CaptainsLog.txt'
    $script:MarkdownFile = Join-Path $script:RootOut 'CaptainsLog.md'
    New-Item -ItemType File -Path $script:ReportFile   -Force | Out-Null
    New-Item -ItemType File -Path $script:MarkdownFile -Force | Out-Null
}

function Write-Section {
    param([string]$Title)
    $line = "`r`n=== $Title ==="
    Write-Host $line -ForegroundColor Cyan
    Add-Content -Path $script:ReportFile -Value $line
}

function Write-Line {
    param([string]$Text = '')
    Write-Host $Text
    Add-Content -Path $script:ReportFile -Value $Text
}

function Write-Ok   { param([string]$T) Write-Host "  [OK  ] $T" -ForegroundColor Green;  Add-Content -Path $script:ReportFile -Value "  [OK  ] $T" }
function Write-Warn { param([string]$T) Write-Host "  [WARN] $T" -ForegroundColor Yellow; Add-Content -Path $script:ReportFile -Value "  [WARN] $T" }
function Write-Fail { param([string]$T) Write-Host "  [FAIL] $T" -ForegroundColor Red;    Add-Content -Path $script:ReportFile -Value "  [FAIL] $T" }
function Write-Info { param([string]$T) Write-Host "  [INFO] $T" -ForegroundColor Gray;   Add-Content -Path $script:ReportFile -Value "  [INFO] $T" }

function Add-Finding {
    param(
        [ValidateSet('PASS','WARN','FAIL','INFO')]
        [string]$Status,
        [string]$Check,
        [string]$Details
    )
    $script:Summary.Add([pscustomobject]@{ Status = $Status; Check = $Check; Details = $Details }) | Out-Null
}

function Run-CommandCapture {
    param([string]$Label, [scriptblock]$Command)
    Write-Section $Label
    try {
        $result = & $Command 2>&1 | Out-String
        if ([string]::IsNullOrWhiteSpace($result)) { $result = '[no output]' }
        Write-Line $result.TrimEnd()
    } catch {
        Write-Line "[error] $($_.Exception.Message)"
    }
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# -------------------------------------------------------------------------------
# Main menu
# -------------------------------------------------------------------------------

function Prompt-Menu {
    if ($Mode) { return $Mode }
    Write-Host ''
    Write-Host 'Chart yer course, Captain:' -ForegroundColor Green
    Write-Host '  1. Connection trouble  - ISP, fleet endpoints, firewall, game version (the 90% case)'
    Write-Host '  2. Can''t reach server  - above + DNS / ping / tracert to a specific server'
    Write-Host '  3. Shipwright          - dedicated server setup, save transfer, config validation'
    Write-Host ''
    $choice = Read-Host 'Choice (1-3) [default 1]'
    switch ($choice) {
        '2'     { return 'CantReachServer' }
        '3'     { return 'Shipwright' }
        default { return 'ConnectionTrouble' }
    }
}

function Prompt-ServerTarget {
    $ip   = $ServerIP
    $port = $ServerPort
    if ([string]::IsNullOrWhiteSpace($ip)) { $ip = Read-Host 'Enter server IP or hostname' }
    $pi = Read-Host "Port [default $port]"
    if (-not [string]::IsNullOrWhiteSpace($pi)) {
        $parsed = 0
        if ([int]::TryParse($pi, [ref]$parsed)) { $port = $parsed }
    }
    return [pscustomobject]@{ IP = $ip.Trim(); Port = $port }
}

# -------------------------------------------------------------------------------
# Network
# -------------------------------------------------------------------------------

function Get-PublicIP {
    if ($SkipNetworkTests) { return }
    Write-Section 'Public IP'
    foreach ($url in @('https://api.ipify.org','https://ifconfig.me/ip','https://icanhazip.com')) {
        try {
            $ip = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5).Content.Trim()
            if ($ip -match '^\d{1,3}(\.\d{1,3}){3}$') {
                Write-Line "Public IP: $ip  (via $url)"
                Add-Finding -Status 'PASS' -Check 'Public IP' -Details "Resolved: $ip"
                $script:PublicIP = $ip
                return
            }
        } catch { continue }
    }
    Write-Line 'Could not determine public IP.'
    Add-Finding -Status 'WARN' -Check 'Public IP' -Details 'Public IP lookup failed.'
}

function Get-IspInfo {
    param([string]$PublicIP)
    if (-not $PublicIP) { return $null }
    try {
        $d = (Invoke-WebRequest -Uri "https://ipinfo.io/$PublicIP/json" -UseBasicParsing -TimeoutSec 5).Content | ConvertFrom-Json
        if ($d.org) { return [pscustomobject]@{ ISP = $d.org; City = $d.city; Country = $d.country } }
    } catch { }
    try {
        $d = (Invoke-WebRequest -Uri "http://ip-api.com/json/$PublicIP" -UseBasicParsing -TimeoutSec 5).Content | ConvertFrom-Json
        if ($d.status -eq 'success') { return [pscustomobject]@{ ISP = $d.isp; City = $d.city; Country = $d.countryCode } }
    } catch { }
    return $null
}

function Match-IspCulprit {
    param([string]$IspOrg)
    if (-not $IspOrg) { return $null }
    foreach ($entry in $script:IspCulpritTable) {
        if ($IspOrg -imatch $entry.Match) { return $entry }
    }
    return $null
}

function Resolve-HostDnsDiagnostic {
    param([string]$HostName)
    $r = [pscustomobject]@{
        HostName = $HostName; SystemStatus = 'Unknown'; SystemAddresses = @()
        PublicStatus = 'Unknown'; PublicAddresses = @(); Diagnosis = ''
    }
    try {
        $sys  = Resolve-DnsName -Name $HostName -Type A -QuickTimeout -ErrorAction Stop
        $ipv4 = @($sys | Where-Object { $_.Type -eq 'A'    } | Select-Object -ExpandProperty IPAddress -Unique)
        $ipv6 = @($sys | Where-Object { $_.Type -eq 'AAAA' } | Select-Object -ExpandProperty IPAddress -Unique)
        if ($ipv4) {
            $r.SystemAddresses = $ipv4
            $r.SystemStatus = if ($ipv4 -contains '127.0.0.1' -or $ipv4 -contains '0.0.0.0') { 'Spoofed' } else { 'OK' }
        } elseif ($ipv6) { $r.SystemAddresses = $ipv6; $r.SystemStatus = 'IPv6Only' }
        else { $r.SystemStatus = 'NXDOMAIN' }
    } catch { $r.SystemStatus = if ($_.Exception.Message -match 'timeout') { 'Timeout' } else { 'NXDOMAIN' } }

    try {
        $pub  = Resolve-DnsName -Name $HostName -Type A -Server '8.8.8.8' -QuickTimeout -ErrorAction Stop
        $ipv4 = @($pub | Where-Object { $_.Type -eq 'A' } | Select-Object -ExpandProperty IPAddress -Unique)
        if ($ipv4) { $r.PublicAddresses = $ipv4; $r.PublicStatus = 'OK' } else { $r.PublicStatus = 'NXDOMAIN' }
    } catch { $r.PublicStatus = if ($_.Exception.Message -match 'timeout') { 'Timeout' } else { 'NXDOMAIN' } }

    $r.Diagnosis = switch ($true) {
        ($r.SystemStatus -eq 'OK')                                            { 'Resolves normally.' }
        ($r.SystemStatus -eq 'NXDOMAIN' -and $r.PublicStatus -eq 'OK')       { 'ISP BLOCK: resolves on Google 8.8.8.8 but not your system DNS.' }
        ($r.SystemStatus -eq 'NXDOMAIN' -and $r.PublicStatus -eq 'NXDOMAIN') { 'DOMAIN DOWN: does not resolve anywhere.' }
        ($r.SystemStatus -eq 'Spoofed')                                       { 'DNS SPOOFING: ISP/VPN returning null address.' }
        ($r.SystemStatus -eq 'IPv6Only')                                      { 'IPv6 ONLY: Windrose is IPv4-only - prioritize IPv4.' }
        ($r.SystemStatus -eq 'Timeout')                                       { 'DNS TIMEOUT: check firewall or switch DNS to 8.8.8.8.' }
        default                                                               { 'DNS result unclear.' }
    }
    return $r
}

# -------------------------------------------------------------------------------
# ISP detection and fleet check
# -------------------------------------------------------------------------------

function Show-IspDiagnosis {
    Write-Section 'Port authority (your ISP)'
    if (-not $script:PublicIP) { Write-Line 'Public IP unknown - skipping ISP lookup.'; return $null }

    $isp = Get-IspInfo -PublicIP $script:PublicIP
    if (-not $isp) {
        Write-Line 'Could not identify ISP.'
        Add-Finding -Status 'INFO' -Check 'ISP detection' -Details 'IP lookup returned no ISP info.'
        return $null
    }

    Write-Line "ISP:     $($isp.ISP)"
    if ($isp.City)    { Write-Line "City:    $($isp.City)" }
    if ($isp.Country) { Write-Line "Country: $($isp.Country)" }

    $culprit = Match-IspCulprit -IspOrg $isp.ISP
    if ($culprit) {
        Write-Line ''
        Write-Line '*** HEADS UP: your ISP ships a security feature that commonly blocks gaming traffic ***'
        Write-Line ''
        Write-Line "ISP:              $($culprit.Name)"
        Write-Line "Feature to check: $($culprit.Feature)"
        Write-Line "Where to toggle:  $($culprit.Toggle)"
        Write-Line ''
        if ($culprit.KnownBlocksWindrose) {
            Write-Line '** CONFIRMED to block Windrose. Toggle this OFF before anything else. **'
            Add-Finding -Status 'WARN' -Check 'ISP' -Details "$($culprit.Name) - $($culprit.Feature) confirmed to block Windrose. Fix: $($culprit.Toggle)"
        } else {
            Write-Line 'Known to block P2P games (Rust, Palworld, Ark). Try toggling off if Fleet check fails.'
            Add-Finding -Status 'INFO' -Check 'ISP' -Details "$($culprit.Name) - toggle $($culprit.Feature) if Fleet check fails. Location: $($culprit.Toggle)"
        }
        return $culprit
    }

    Write-Line ''
    Write-Line 'ISP not in known-culprit list. Still check your ISP app or router admin page'
    Write-Line 'for any "Security", "Threat Protection", or "Safe Browsing" toggle if the'
    Write-Line 'Fleet check below shows failures.'
    Add-Finding -Status 'INFO' -Check 'ISP' -Details "$($isp.ISP) - not in culprit list. Check ISP app for security toggles if connection fails."
    return $null
}

function Show-KnownIspTable {
    Write-Section 'Known ISP culprits reference'
    $confirmed = $script:IspCulpritTable | Where-Object { $_.KnownBlocksWindrose }
    $others    = $script:IspCulpritTable | Where-Object { -not $_.KnownBlocksWindrose }
    Write-Line 'CONFIRMED to block Windrose:'
    foreach ($c in $confirmed) { Write-Line "  $($c.Name) - $($c.Toggle)" }
    Write-Line ''
    Write-Line 'Known to block similar P2P games (Rust, Palworld, Ark, etc.):'
    foreach ($c in $others) { Write-Line "  $($c.Name) - $($c.Toggle)" }
    Write-Line ''
    Write-Line 'Note: dedicated server hosts (SurvivalServers, LOW.MS, g-portal) are'
    Write-Line 'NOT affected - they run on business connections without consumer security'
    Write-Line 'filters. The block is on your residential end, not the host or Windrose.'
}

function Write-DirectIpFallback {
    Write-Line ''
    Write-Line '=== Fallback: Direct IP mode ==='
    Write-Line 'Connection Services unreachable? You can still host without them:'
    Write-Line '  Host a Game > Direct IP tab > port 7777'
    Write-Line '  Share your public IP with your crew.'
    Write-Line 'Bypasses Windrose Connection Services entirely.'
    Write-Line 'Requires port 7777 open on your router.'
}

function Test-WindroseServices {
    if ($SkipNetworkTests) {
        Write-Section 'Fleet check'
        Write-Line 'Skipped (-SkipNetworkTests).'
        return
    }

    $detectedCulprit = Show-IspDiagnosis

    Write-Section 'Fleet check (Windrose backend services)'
    Write-Line 'Checking all 8 Windrose Connection Service endpoints.'
    Write-Line 'Compares system DNS vs Google DNS to pinpoint ISP blocking vs outages.'
    Write-Line ''

    $anyIspBlock  = $false
    $anyDnsSpoof  = $false
    $anyIpv6Issue = $false
    $reachable    = 0
    $unreachable  = 0
    $dnsIssues    = @()

    foreach ($ep in $script:WindroseServiceEndpoints) {
        Write-Line "--- $($ep.Name) ($($ep.Region)) ---"
        $dns = Resolve-HostDnsDiagnostic -HostName $ep.Host
        Write-Line "  System DNS: $($dns.SystemStatus)$(if ($dns.SystemAddresses) { ' -> ' + ($dns.SystemAddresses -join ', ') })"
        Write-Line "  Google DNS: $($dns.PublicStatus)$(if ($dns.PublicAddresses) { ' -> ' + ($dns.PublicAddresses -join ', ') })"
        Write-Line "  Diagnosis:  $($dns.Diagnosis)"

        switch ($dns.SystemStatus) {
            'NXDOMAIN' { if ($dns.PublicStatus -eq 'OK') { $anyIspBlock = $true; $dnsIssues += $ep.Host } }
            'Spoofed'  { $anyDnsSpoof = $true; $dnsIssues += $ep.Host }
            'IPv6Only' { $anyIpv6Issue = $true }
        }

        $tcpOk = $false
        if ($dns.SystemStatus -eq 'OK' -and $dns.SystemAddresses) {
            try {
                $tcp = [System.Net.Sockets.TcpClient]::new()
                $ar  = $tcp.BeginConnect($ep.Host, $ep.Port, $null, $null)
                $tcpOk = $ar.AsyncWaitHandle.WaitOne(3000) -and $tcp.Connected
                $tcp.Close()
            } catch { }
        }

        if ($tcpOk) {
            Write-Ok "TCP $($ep.Port) reachable"
            $reachable++
        } else {
            Write-Fail "TCP $($ep.Port) NOT reachable"
            $unreachable++
            Add-Finding -Status 'FAIL' -Check "Fleet: $($ep.Name)" -Details "TCP $($ep.Port) unreachable. DNS: $($dns.SystemStatus). $($dns.Diagnosis)"
        }
        Write-Line ''
    }

    Write-Section 'Fleet verdict'

    if ($anyDnsSpoof) {
        Write-Line '*** DNS SPOOFING DETECTED ***'
        Write-Line 'Your DNS is returning a null/loopback address for Windrose domains.'
        Write-Line 'Likely cause: ISP safe browsing, VPN, NextDNS with aggressive filtering.'
        Write-Line ''
        Write-Line 'FIX: Switch to Google DNS (8.8.8.8 / 8.8.4.4):'
        Write-Line '  Settings > Network & Internet > your connection > Properties'
        Write-Line '  > Edit DNS > Manual > IPv4 ON'
        Write-Line '  Preferred: 8.8.8.8   Alternate: 8.8.4.4'
        Write-Line '  Save, then run: ipconfig /flushdns'
        Add-Finding -Status 'FAIL' -Check 'Fleet: Overall' -Details 'DNS spoofing. Switch to Google DNS 8.8.8.8.'

    } elseif ($anyIspBlock) {
        Write-Line '*** ISP BLOCKING DETECTED ***'
        Write-Line 'Windrose endpoints resolve on Google DNS but NOT on your system DNS.'
        Write-Line 'Your ISP or router is filtering these domains.'
        Write-Line ''
        if ($detectedCulprit) {
            Write-Line "*** YOUR FIX: $($detectedCulprit.Name) ***"
            Write-Line "  Toggle OFF: $($detectedCulprit.Feature)"
            Write-Line "  Where:      $($detectedCulprit.Toggle)"
            if ($detectedCulprit.KnownBlocksWindrose) { Write-Line '  Confirmed to fix this on this ISP. Do this FIRST.' }
            Write-Line ''
            Write-Line 'If that does not work:'
        }
        Write-Line '  1. Switch to Google DNS (8.8.8.8 / 8.8.4.4) - see fix above'
        Write-Line '  2. Try a VPN - if it works on VPN, confirmed ISP block'
        Write-Line '  3. Ask your ISP to whitelist *.windrose.support and port 3478 UDP/TCP'
        $details = if ($detectedCulprit) { "ISP blocking. Fix: toggle off $($detectedCulprit.Feature) on $($detectedCulprit.Name)." } else { "ISP blocking on $($dnsIssues.Count) endpoint(s). Check ISP app security toggle." }
        Add-Finding -Status 'FAIL' -Check 'Fleet: Overall' -Details $details

    } elseif ($anyIpv6Issue) {
        Write-Line '*** IPv6 PRIORITIZATION ISSUE ***'
        Write-Line 'Your system prefers IPv6 for Windrose domains. Windrose is IPv4-only.'
        Write-Line ''
        Write-Line 'FIX: Force Windows to prefer IPv4 (keep IPv6 enabled).'
        Write-Line 'Run this in an elevated Command Prompt:'
        Write-Line '  reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" /v DisabledComponents /t REG_DWORD /d 32 /f'
        Write-Line 'Then restart your PC. To revert: set /d 0 instead.'
        Add-Finding -Status 'FAIL' -Check 'Fleet: Overall' -Details 'IPv6 prioritization. Game is IPv4-only.'

    } elseif ($reachable -gt 0 -and $unreachable -gt 0) {
        Write-Line "PARTIAL: $reachable/$($reachable + $unreachable) endpoints reachable."
        Write-Line ''
        if ($detectedCulprit) {
            Write-Line "LIKELY CAUSE: $($detectedCulprit.Name) - $($detectedCulprit.Feature)"
            Write-Line "  Toggle OFF: $($detectedCulprit.Toggle)"
            Write-Line ''
        }
        Write-Line 'Other possibilities:'
        Write-Line '  - A regional backend is genuinely down (check playwindrose.com / Discord #status)'
        Write-Line '  - Windows Firewall blocking outbound on specific ports'
        Write-Line ''
        Write-Line 'If port 3478 is failing: that is P2P signaling. The game cannot connect'
        Write-Line 'peers without it. Almost always an ISP security feature.'
        Write-DirectIpFallback
        $details = if ($detectedCulprit) { "Partial: $reachable ok / $unreachable failed. Likely $($detectedCulprit.Feature) on $($detectedCulprit.Name)." } else { "Partial: $reachable ok / $unreachable failed. Check ISP security toggle." }
        Add-Finding -Status 'WARN' -Check 'Fleet: Overall' -Details $details

    } elseif ($unreachable -eq 0) {
        Write-Ok "All $reachable endpoints reachable. Backend is up on your end."
        Add-Finding -Status 'PASS' -Check 'Fleet: Overall' -Details "All $reachable Windrose services reachable."

    } else {
        Write-Line 'ALL endpoints unreachable.'
        Write-Line '  - Backend may be entirely down (check playwindrose.com / Discord #status)'
        Write-Line '  - Or firewall is blocking ALL outbound HTTPS on port 443'
        Write-DirectIpFallback
        Add-Finding -Status 'FAIL' -Check 'Fleet: Overall' -Details "All $($script:WindroseServiceEndpoints.Count) services unreachable."
    }

    if ($reachable -lt $script:WindroseServiceEndpoints.Count) { Show-KnownIspTable }
}

# -------------------------------------------------------------------------------
# Game install detection
# -------------------------------------------------------------------------------

function Get-SteamInstallPath {
    foreach ($reg in @('HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam','HKCU:\SOFTWARE\Valve\Steam')) {
        try {
            $p = (Get-ItemProperty -Path $reg -ErrorAction Stop).InstallPath
            if ($p -and (Test-Path $p)) { return $p }
            $p = (Get-ItemProperty -Path $reg -ErrorAction Stop).SteamPath
            if ($p -and (Test-Path $p)) { return ($p -replace '/', '\') }
        } catch { continue }
    }
    return $null
}

function Get-SteamLibraries {
    $libs = New-Object System.Collections.Generic.List[string]
    $root = Get-SteamInstallPath
    if ($root) { [void]$libs.Add($root) }

    $vdfs = @(
        "$env:ProgramFiles(x86)\Steam\steamapps\libraryfolders.vdf"
        "$env:ProgramFiles\Steam\steamapps\libraryfolders.vdf"
        'C:\Steam\steamapps\libraryfolders.vdf'
    )
    if ($root) { $vdfs += (Join-Path $root 'steamapps\libraryfolders.vdf') }

    foreach ($vdf in ($vdfs | Select-Object -Unique)) {
        if (Test-Path $vdf) {
            try {
                [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"') | ForEach-Object {
                    [void]$libs.Add(($_.Groups[1].Value -replace '\\\\', '\'))
                }
            } catch { }
        }
    }
    try {
        Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 -and $_.Root -match '^[A-Z]:\\$' } | ForEach-Object {
            foreach ($n in @('SteamLibrary','Steam','Games\SteamLibrary','Games\Steam')) {
                $c = Join-Path $_.Root $n
                if (Test-Path $c) { [void]$libs.Add($c) }
            }
        }
    } catch { }
    return ($libs | Select-Object -Unique)
}

function Find-WindroseInstall {
    if ($null -ne $script:WindroseInstallCache) { return ,@($script:WindroseInstallCache) }
    $candidates = New-Object System.Collections.Generic.List[string]
    $add = {
        param($p)
        if ([string]::IsNullOrWhiteSpace($p)) { return }
        try {
            $n = try { (Resolve-Path -LiteralPath $p -ErrorAction Stop).Path } catch { $p.ToString().TrimEnd('\').Trim() }
            if ($n -and $n -match ':\\') { $candidates.Add($n) }
        } catch { }
    }
    foreach ($lib in (Get-SteamLibraries)) {
        foreach ($sub in @('steamapps\common\Windrose','common\Windrose')) {
            $c = Join-Path $lib $sub
            if (Test-Path $c) { & $add $c }
        }
    }
    try {
        $fp = Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue |
            Where-Object { $_.Program -match '\\Windrose\\.*Windrose\.exe$|\\Windrose\\.*R5.*\.exe$' } |
            Select-Object -ExpandProperty Program -First 1
        if ($fp) {
            $d = Split-Path $fp -Parent
            while ($d -and (Split-Path $d -Leaf) -ne 'Windrose') {
                $p = Split-Path $d -Parent; if ($p -eq $d) { $d = $null; break }; $d = $p
            }
            if ($d -and (Test-Path $d)) { & $add $d }
        }
    } catch { }
    $seen   = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    $unique = New-Object System.Collections.Generic.List[string]
    foreach ($c in $candidates) { if ($seen.Add($c)) { $unique.Add($c) } }
    $result = @($unique.ToArray())
    $script:WindroseInstallCache = $result
    return $result
}

function Find-DedicatedServerInstall {
    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($install in @(Find-WindroseInstall)) {
        foreach ($sub in @('R5\Builds\WindroseServer','R5\Builds\WindowsServer')) {
            $p = Join-Path $install $sub
            if (Test-Path $p) { $candidates.Add($p) }
        }
    }
    foreach ($lib in (Get-SteamLibraries)) {
        $p = Join-Path $lib 'steamapps\common\Windrose Dedicated Server'
        if (Test-Path $p) { $candidates.Add($p) }
    }
    foreach ($p in @('C:\WindroseServer','C:\Game_Servers\Windrose_Server',"$env:USERPROFILE\WindroseServer")) {
        if (Test-Path $p) { $candidates.Add($p) }
    }
    return ($candidates | Select-Object -Unique)
}

# -------------------------------------------------------------------------------
# Diagnostic sections
# -------------------------------------------------------------------------------

function Get-LocalNetworkSummary {
    Write-Section 'Local network'
    foreach ($p in (Get-NetConnectionProfile)) {
        Write-Line "  $($p.Name) | $($p.NetworkCategory) | IPv4: $($p.IPv4Connectivity) | IPv6: $($p.IPv6Connectivity)"
        if ($p.NetworkCategory -eq 'Public') {
            Add-Finding -Status 'WARN' -Check 'Network profile' -Details "'$($p.Name)' is Public - firewall may be stricter."
        }
    }
    Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
        Write-Line "  UP: $($_.Name) | $($_.InterfaceDescription) | $($_.LinkSpeed)"
    }
}

function Check-SteamAndProcesses {
    Write-Section 'Running processes'
    $procs = Get-Process | Where-Object { $_.ProcessName -match 'steam|Windrose|R5' } |
        Select-Object ProcessName, Id, StartTime, Path
    if ($procs) {
        foreach ($pr in $procs) { Write-Line ($pr | Format-List | Out-String).TrimEnd() }
        Add-Finding -Status 'PASS' -Check 'Processes' -Details 'Steam and/or Windrose processes running.'
    } else {
        Write-Line '  No Steam or Windrose processes running.'
        Add-Finding -Status 'INFO' -Check 'Processes' -Details 'Steam and Windrose not currently running.'
    }
}

function Get-GameVersionInfo {
    $installs = @(Find-WindroseInstall)
    Write-Section 'Game install'
    if (-not $installs -or $installs.Count -eq 0) {
        Write-Warn 'No Windrose install detected.'
        Add-Finding -Status 'WARN' -Check 'Game install' -Details 'Windrose install not auto-detected.'
        return @()
    }
    foreach ($install in $installs) {
        Write-Line "  Install: $install"
        Get-ChildItem -Path $install -Recurse -Include *.exe -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'Windrose|R5' } | Select-Object -First 5 |
            ForEach-Object { Write-Line "    $($_.FullName) | v$($_.VersionInfo.FileVersion)" }
        Add-Finding -Status 'PASS' -Check 'Game install' -Details "Detected at $install."
    }
    return $installs
}

function Collect-GameFiles {
    param([string[]]$Installs)
    if (-not $Installs) { return }
    foreach ($install in $Installs) {
        $dest = Join-Path $script:LogsOut ($install -replace '[:\\/ ]', '_')
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        Write-Section "Salvage from $install"
        $savedPath = Join-Path $install 'R5\Saved'
        foreach ($sub in @('SaveProfiles','Config')) {
            $src = Join-Path $savedPath $sub
            if (Test-Path $src) { Copy-Item $src (Join-Path $dest $sub) -Recurse -Force; Write-Line "  Recovered $sub" }
        }
        Get-ChildItem -Path $install -Recurse -Filter 'ServerDescription.json' -ErrorAction SilentlyContinue | Select-Object -First 3 |
            ForEach-Object {
                Copy-Item $_.FullName (Join-Path $dest "ServerDescription_$($_.Name)") -Force
                Write-Line "  Recovered $($_.FullName)"
            }
        $logs = Get-ChildItem -Path $savedPath -Recurse -Include *.log,*.txt -ErrorAction SilentlyContinue | Select-Object -First 50
        if ($logs) {
            $ld = Join-Path $dest 'Logs'; New-Item -ItemType Directory -Path $ld -Force | Out-Null
            $logs | ForEach-Object { Copy-Item $_.FullName (Join-Path $ld $_.Name) -Force }
            Write-Line "  Recovered $($logs.Count) log/text files"
        }
    }
}

function Check-LocalFirewallRules {
    Write-Section 'Firewall'
    foreach ($p in (Get-NetFirewallProfile)) {
        Write-Line "  $($p.Name): Enabled=$($p.Enabled) Inbound=$($p.DefaultInboundAction) Outbound=$($p.DefaultOutboundAction)"
    }
    $rules = Get-NetFirewallApplicationFilter | Where-Object { $_.Program -match 'Steam|Windrose|R5' } | Select-Object -First 20
    if ($rules) {
        Write-Line '  Steam/Windrose filters found:'
        foreach ($r in $rules) { Write-Line "    $($r.Program)" }
        Add-Finding -Status 'PASS' -Check 'Firewall' -Details 'Steam/Windrose firewall filters found.'
    } else {
        Write-Warn 'No Steam/Windrose application filters found.'
        Add-Finding -Status 'WARN' -Check 'Firewall' -Details 'No Steam/Windrose application filters detected.'
    }
}

function Check-RecentErrors {
    Write-Section 'Recent errors'
    $events = Get-WinEvent -LogName Application -MaxEvents 250 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.LevelDisplayName -in @('Error','Critical') -and (
                $_.ProviderName -match 'Application Error|Windows Error Reporting|Steam|Windrose' -or
                $_.Message      -match 'Windrose|R5|steam'
            )
        } | Select-Object -First 25 TimeCreated, ProviderName, Id, LevelDisplayName, Message
    if ($events) {
        foreach ($e in $events) { Write-Line ($e | Format-List | Out-String).TrimEnd() }
        Add-Finding -Status 'WARN' -Check 'Recent errors' -Details 'Related application errors in event log - review report.'
    } else {
        Write-Line '  No recent related application errors found.'
        Add-Finding -Status 'PASS' -Check 'Recent errors' -Details 'No recent related errors.'
    }
}

function Check-HostsFile {
    Run-CommandCapture -Label 'Hosts file' -Command { Get-Content "$env:WINDIR\System32\drivers\etc\hosts" }
}

# -------------------------------------------------------------------------------
# Mode 2 - server reachability
# -------------------------------------------------------------------------------

function Test-ServerReachability {
    param([string]$Target, [int]$Port)

    Write-Section "DNS: $Target"
    try {
        $r   = Resolve-DnsName -Name $Target -ErrorAction Stop
        $ips = $r | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress -Unique
        if ($ips) {
            foreach ($ip in $ips) { Write-Line "  $Target -> $ip" }
            Add-Finding -Status 'PASS' -Check 'DNS' -Details "Resolved $Target."
        } else {
            Write-Fail 'No addresses returned.'
            Add-Finding -Status 'WARN' -Check 'DNS' -Details "No addresses for $Target."
        }
    } catch {
        Write-Fail "DNS failed: $($_.Exception.Message)"
        Add-Finding -Status 'FAIL' -Check 'DNS' -Details "DNS failed for $Target."
    }

    Write-Section "Ping: $Target"
    try {
        $pings = Test-Connection -TargetName $Target -Count 4 -ErrorAction Stop
        foreach ($p in $pings) { Write-Line "  Reply $($p.Latency) ms" }
        $avg = [math]::Round(($pings | Measure-Object -Property Latency -Average).Average, 1)
        Add-Finding -Status 'PASS' -Check 'Ping' -Details "Average $avg ms."
    } catch {
        Write-Warn 'Ping failed or ICMP blocked (not definitive for game connectivity).'
        Add-Finding -Status 'WARN' -Check 'Ping' -Details 'Ping failed.'
    }

    Write-Section "TCP port: $Target`:$Port"
    $r = Test-NetConnection -ComputerName $Target -Port $Port -InformationLevel Detailed -WarningAction SilentlyContinue
    Write-Line ($r | Out-String).TrimEnd()
    if ($r.TcpTestSucceeded) {
        Add-Finding -Status 'PASS' -Check "TCP $Port" -Details "TCP $Port reachable on $Target."
    } else {
        Add-Finding -Status 'FAIL' -Check "TCP $Port" -Details "TCP $Port unreachable. If game uses UDP, check host firewall/port forwarding."
    }

    Write-Section "Port presets: $Target"
    foreach ($preset in $script:WindrosePortPresets) {
        $pr    = Test-NetConnection -ComputerName $Target -Port $preset.Port -WarningAction SilentlyContinue
        $state = if ($pr.TcpTestSucceeded) { 'OPEN (TCP)' } else { 'closed/filtered' }
        Write-Line ("  {0,-6} {1,-10} {2,-38} -> {3}" -f $preset.Port, $preset.Protocol, $preset.Purpose, $state)
        Add-Finding -Status (if ($pr.TcpTestSucceeded) { 'PASS' } else { 'WARN' }) `
            -Check "Port $($preset.Port)" -Details "$($preset.Purpose) -> $state"
    }
    Write-Line '  Note: UDP cannot be confirmed client-side. closed/filtered on UDP-only ports is inconclusive.'

    if (-not $SkipTraceRoute) {
        Run-CommandCapture -Label "Traceroute: $Target" -Command { tracert $Target }
    }
}

# -------------------------------------------------------------------------------
# Shipwright - dedicated server setup and save management
# -------------------------------------------------------------------------------

function Invoke-Shipwright {
    Write-Host ''
    Write-Host '==============================' -ForegroundColor Yellow
    Write-Host '       SHIPWRIGHT             ' -ForegroundColor Yellow
Write-Host '  Dedicated server toolkit    ' -ForegroundColor Yellow
    Write-Host '==============================' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  1. Setup server       - copy WindroseServer out of game files and configure it'
    Write-Host '  2. Transfer save      - move a world between client and dedicated server'
    Write-Host '  3. Validate config    - check World Island ID triple-match (no file changes)'
    Write-Host '  4. Exit'
    Write-Host ''
    $choice = Read-Host 'Choice (1-4)'
    switch ($choice) {
        '1' { Invoke-ServerSetup }
        '2' { Invoke-SaveTransfer }
        '3' { Invoke-ValidateServerConfig }
    }
}

# --- Server setup ---

function Invoke-ServerSetup {
    Write-Host ''
    Write-Host '--- Setup: find and copy server files ---' -ForegroundColor Cyan

    $installs = @(Find-WindroseInstall)

    # Check for already-deployed server installs first
    $existingServers = @(Find-DedicatedServerInstall | Where-Object { $_ -notmatch '\\R5\\Builds\\' })
    if ($existingServers.Count -gt 0) {
        Write-Host ''
        Write-Host '[OK] Existing dedicated server install(s) found:' -ForegroundColor Green
        for ($i = 0; $i -lt $existingServers.Count; $i++) {
            Write-Host "  $($i+1). $($existingServers[$i])"
        }
        Write-Host ''
        Write-Host '  1. Configure one of these'
        Write-Host '  2. Copy a fresh one from game files'
        Write-Host '  3. Cancel'
        $pick = Read-Host 'Choice (1-3)'
        if ($pick -eq '1') {
            $idx = 0
            if ($existingServers.Count -gt 1) {
                $n = Read-Host "Which? (1-$($existingServers.Count))"
                $idx = [math]::Max(0, [int]$n - 1)
            }
            Invoke-ConfigureServer -ServerPath $existingServers[$idx]
            return
        } elseif ($pick -eq '3') { return }
    }

    # Find server source inside game install
    $src = $null
    foreach ($install in $installs) {
        foreach ($sub in @('R5\Builds\WindroseServer','R5\Builds\WindowsServer')) {
            $p = Join-Path $install $sub
            if (Test-Path $p) { $src = $p; break }
        }
        if ($src) { break }
    }

    if (-not $src) {
        Write-Host '[FAIL] WindroseServer folder not found inside game install.' -ForegroundColor Red
        Write-Host 'Alternatives:'
        Write-Host '  - Install "Windrose Dedicated Server" free from Steam (Tools section)'
        Write-Host '  - Manually copy <GameInstall>\R5\Builds\WindroseServer to anywhere outside the game folder'
        return
    }

    Write-Host "[OK] Server source: $src" -ForegroundColor Green
    Write-Host ''
    $default = 'C:\WindroseServer'
    $destIn  = Read-Host "Copy to where? [default: $default]"
    $dest    = if ([string]::IsNullOrWhiteSpace($destIn)) { $default } else { $destIn.Trim() }

    # Warn if they picked a path inside the game folder
    foreach ($install in $installs) {
        if ($dest -like "$install*") {
            Write-Host ''
            Write-Host '[WARN] That path is inside the game folder.' -ForegroundColor Yellow
            Write-Host 'Per the official docs, the game client will shut down the server if launched from there.'
            $c = Read-Host 'Continue anyway? (y/N)'
            if ($c -notmatch '^[Yy]') { Write-Host 'Cancelled.'; return }
        }
    }

    if (Test-Path $dest) {
        Write-Host "[WARN] '$dest' already exists." -ForegroundColor Yellow
        $ow = Read-Host 'Overwrite? (y/N)'
        if ($ow -notmatch '^[Yy]') { Write-Host 'Cancelled.'; return }
        Remove-Item $dest -Recurse -Force
    }

    Write-Host "Copying files to $dest..."
    try {
        Copy-Item -Path $src -Destination $dest -Recurse -Force
        Write-Host '[OK] Files copied.' -ForegroundColor Green
    } catch {
        Write-Host "[FAIL] Copy failed: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    Invoke-ConfigureServer -ServerPath $dest
}

function Invoke-ConfigureServer {
    param([string]$ServerPath)
    Write-Host ''
    Write-Host '--- Configure server ---' -ForegroundColor Cyan

    $descPath = Join-Path $ServerPath $script:ServerDescFile
    $batFile  = Join-Path $ServerPath 'StartServerForeground.bat'
    $exeFile  = Join-Path $ServerPath 'WindroseServer.exe'

    # Generate default config if it does not exist yet
    if (-not (Test-Path $descPath)) {
        Write-Host 'ServerDescription.json not found - need to run the server once to generate it.'
        Write-Host ''
        if (Test-Path $batFile) {
            Write-Host "Starting: $batFile"
            Write-Host 'Watch for an invite code in the console window, then close that window.'
            Start-Process -FilePath $batFile -WorkingDirectory $ServerPath
            Read-Host 'Press Enter here once you have CLOSED the server window'
        } elseif (Test-Path $exeFile) {
            Start-Process -FilePath $exeFile -WorkingDirectory $ServerPath
            Start-Sleep -Seconds 15
            Get-Process | Where-Object { $_.Path -eq $exeFile } | Stop-Process -Force
            Write-Host 'Server run complete.'
        } else {
            Write-Host "[FAIL] WindroseServer.exe not found in $ServerPath" -ForegroundColor Red
            return
        }
    }

    if (-not (Test-Path $descPath)) {
        Write-Host '[FAIL] ServerDescription.json was not generated.' -ForegroundColor Red
        return
    }

    try {
        $desc = Get-Content $descPath -Raw | ConvertFrom-Json
        $cfg  = $desc.ServerDescription_Persistent
    } catch {
        Write-Host "[FAIL] Could not read ServerDescription.json: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    Write-Host ''
    Write-Host 'Current config:' -ForegroundColor Green
    Write-Host "  Invite Code:  $($cfg.InviteCode)"
    Write-Host "  Server Name:  $(if ($cfg.ServerName) { $cfg.ServerName } else { '(not set)' })"
    Write-Host "  World ID:     $($cfg.WorldIslandId)"
    Write-Host "  Max Players:  $($cfg.MaxPlayerCount)"
    Write-Host "  Region:       $(if ($cfg.UserSelectedRegion) { $cfg.UserSelectedRegion } else { 'Auto' })"
    Write-Host ''

    $edit = Read-Host 'Edit settings now? (Y/n)'
    if ($edit -match '^[Nn]') {
        Write-Host ''
        Write-Host "Ready. Start the server with: $batFile"
        Write-Host "Crew connect via: Play > Connect to Server > invite code $($cfg.InviteCode)"
        return
    }

    $name = Read-Host "Server name [current: $(if ($cfg.ServerName) { $cfg.ServerName } else { '(none)' })]"
    if (-not [string]::IsNullOrWhiteSpace($name)) { $cfg.ServerName = $name }

    $maxP = Read-Host "Max players [current: $($cfg.MaxPlayerCount)]"
    if ($maxP -match '^\d+$') { $cfg.MaxPlayerCount = [int]$maxP }

    Write-Host "Region options: EU (covers EU+NA), CIS, SEA, or blank for Auto"
    $region = Read-Host "Region [current: $(if ($cfg.UserSelectedRegion) { $cfg.UserSelectedRegion } else { 'Auto' })]"
    if ($region -in @('EU','CIS','SEA')) { $cfg.UserSelectedRegion = $region }
    elseif ($region -eq '' -or $region -eq 'Auto') { $cfg.UserSelectedRegion = '' }
    elseif (-not [string]::IsNullOrWhiteSpace($region)) { Write-Host '[WARN] Invalid region - keeping current.' -ForegroundColor Yellow }

    $pw = Read-Host 'Password (leave blank for none / to keep current)'
    if (-not [string]::IsNullOrWhiteSpace($pw)) {
        $cfg.Password = $pw; $cfg.IsPasswordProtected = $true
    } elseif ($cfg.IsPasswordProtected) {
        $rem = Read-Host 'Remove existing password? (y/N)'
        if ($rem -match '^[Yy]') { $cfg.Password = ''; $cfg.IsPasswordProtected = $false }
    }

    try {
        $desc.ServerDescription_Persistent = $cfg
        Set-Content -Path $descPath -Value ($desc | ConvertTo-Json -Depth 10) -Force
        Write-Host ''
        Write-Host '[OK] Configuration saved.' -ForegroundColor Green
        Write-Host "  Invite code: $($cfg.InviteCode)"
        Write-Host "  Start:       $batFile"
        Write-Host "  Crew joins:  Play > Connect to Server > $($cfg.InviteCode)"
    } catch {
        Write-Host "[FAIL] Could not save configuration: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# --- Save transfer helpers ---

function Find-ClientWorldFolders {
    $root   = "$env:LOCALAPPDATA\R5\Saved\SaveProfiles"
    $worlds = New-Object System.Collections.Generic.List[pscustomobject]
    if (-not (Test-Path $root)) { return $worlds }
    Get-ChildItem -Path $root -Filter 'WorldDescription.json' -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $wid = Split-Path $_.DirectoryName -Leaf
        try {
            $wd = Get-Content $_.FullName -Raw | ConvertFrom-Json
            $worlds.Add([pscustomobject]@{ WorldId = $wid; WorldName = $wd.WorldDescription.WorldName; Path = $_.DirectoryName; DescFile = $_.FullName; Source = 'client' })
        } catch {
            $worlds.Add([pscustomobject]@{ WorldId = $wid; WorldName = '(unreadable)'; Path = $_.DirectoryName; DescFile = $_.FullName; Source = 'client' })
        }
    }
    return $worlds
}

function Find-ServerWorldFolders {
    param([string]$ServerPath)
    $root   = Join-Path $ServerPath $script:ServerSaveRoot
    $worlds = New-Object System.Collections.Generic.List[pscustomobject]
    if (-not (Test-Path $root)) { return $worlds }
    Get-ChildItem -Path $root -Filter 'WorldDescription.json' -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $wid = Split-Path $_.DirectoryName -Leaf
        try {
            $wd = Get-Content $_.FullName -Raw | ConvertFrom-Json
            $worlds.Add([pscustomobject]@{ WorldId = $wid; WorldName = $wd.WorldDescription.WorldName; Path = $_.DirectoryName; DescFile = $_.FullName; Source = 'server' })
        } catch {
            $worlds.Add([pscustomobject]@{ WorldId = $wid; WorldName = '(unreadable)'; Path = $_.DirectoryName; DescFile = $_.FullName; Source = 'server' })
        }
    }
    return $worlds
}

function Test-ProcessesStopped {
    $running = Get-Process | Where-Object { $_.ProcessName -match 'WindroseServer|Windrose|R5' }
    if ($running) {
        Write-Host ''
        Write-Host '[FAIL] These processes are still running:' -ForegroundColor Red
        foreach ($p in $running) { Write-Host "  $($p.ProcessName) (PID $($p.Id))" }
        Write-Host ''
        Write-Host 'Stop the game client AND the dedicated server before transferring saves.'
        Write-Host 'Transferring while either is running can corrupt your save data.'
        return $false
    }
    return $true
}

function Test-WorldIdTripleMatch {
    param([string]$WorldFolderPath, [string]$ServerDescPath = '')
    $folderId = Split-Path $WorldFolderPath -Leaf
    $descFile  = Join-Path $WorldFolderPath 'WorldDescription.json'
    $result    = [pscustomobject]@{
        FolderId        = $folderId
        DescIslandId    = $null
        ServerConfigId  = $null
        FolderMatchDesc = $false
        DescMatchConfig = $false
        AllMatch        = $false
        Issues          = @()
    }
    if (Test-Path $descFile) {
        try {
            $wd = Get-Content $descFile -Raw | ConvertFrom-Json
            $result.DescIslandId    = $wd.WorldDescription.islandId
            $result.FolderMatchDesc = ($folderId -eq $result.DescIslandId)
            if (-not $result.FolderMatchDesc) {
                $result.Issues += "Folder '$folderId' != islandId '$($result.DescIslandId)' in WorldDescription.json"
            }
        } catch { $result.Issues += "Could not parse WorldDescription.json: $($_.Exception.Message)" }
    } else { $result.Issues += "WorldDescription.json not found in $WorldFolderPath" }

    if ($ServerDescPath -and (Test-Path $ServerDescPath)) {
        try {
            $sd = Get-Content $ServerDescPath -Raw | ConvertFrom-Json
            $result.ServerConfigId  = $sd.ServerDescription_Persistent.WorldIslandId
            $result.DescMatchConfig = ($folderId -eq $result.ServerConfigId)
            if (-not $result.DescMatchConfig) {
                $result.Issues += "Folder '$folderId' != WorldIslandId '$($result.ServerConfigId)' in ServerDescription.json"
            }
        } catch { $result.Issues += "Could not parse ServerDescription.json: $($_.Exception.Message)" }
    }
    $result.AllMatch = ($result.Issues.Count -eq 0)
    return $result
}

function New-SaveBackup {
    param([string]$Path, [string]$Label)
    $ts        = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $backupDir = Join-Path "$env:USERPROFILE\Desktop\WindroseBackups" "${Label}_${ts}"
    try {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        Copy-Item -Path $Path -Destination $backupDir -Recurse -Force
        Write-Host "  [OK] Backup: $backupDir" -ForegroundColor Green
        return $backupDir
    } catch {
        Write-Host "  [FAIL] Backup failed: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Resolve-ServerPath {
    $serverPaths = @(Find-DedicatedServerInstall)
    if ($serverPaths.Count -eq 0) {
        $m = Read-Host 'No server install found. Enter server path (blank to cancel)'
        if ([string]::IsNullOrWhiteSpace($m) -or -not (Test-Path $m)) { return $null }
        return $m
    }
    if ($serverPaths.Count -eq 1) {
        Write-Host "  Server: $($serverPaths[0])"
        return $serverPaths[0]
    }
    Write-Host 'Multiple server installs found:'
    for ($i = 0; $i -lt $serverPaths.Count; $i++) { Write-Host "  $($i+1). $($serverPaths[$i])" }
    $pick = Read-Host "Which? (1-$($serverPaths.Count))"
    return $serverPaths[[math]::Max(0,[int]$pick - 1)]
}

# --- Save transfer ---

function Invoke-SaveTransfer {
    Write-Host ''
    Write-Host '--- Save Transfer ---' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  1. Client -> Server  (move your local world to a dedicated server)'
    Write-Host '  2. Server -> Client  (pull a world back from a dedicated server)'
    Write-Host '  3. Cancel'
    Write-Host ''
    $dir = Read-Host 'Direction (1-3)'
    if ($dir -eq '3' -or [string]::IsNullOrWhiteSpace($dir)) { return }

    if (-not (Test-ProcessesStopped)) { return }

    $serverPath = Resolve-ServerPath
    if (-not $serverPath) { return }
    $serverDescPath = Join-Path $serverPath $script:ServerDescFile

    if ($dir -eq '1') {
        # --- Client -> Server ---
        $worlds = @(Find-ClientWorldFolders)
        if (-not $worlds -or $worlds.Count -eq 0) {
            Write-Host '[FAIL] No client worlds found.' -ForegroundColor Red
            Write-Host "  Looked in: $env:LOCALAPPDATA\R5\Saved\SaveProfiles"
            return
        }
        Write-Host ''
        Write-Host 'Client worlds:'
        for ($i = 0; $i -lt $worlds.Count; $i++) {
            Write-Host "  $($i+1). $($worlds[$i].WorldName)  (ID: $($worlds[$i].WorldId))"
            Write-Host "       $($worlds[$i].Path)"
        }
        $pick  = Read-Host "Which world? (1-$($worlds.Count))"
        $world = $worlds[[math]::Max(0,[int]$pick - 1)]

        $gameVersion = Split-Path (Split-Path $world.Path -Parent) -Leaf
        $destRoot    = Join-Path $serverPath "$($script:ServerSaveRoot)\$gameVersion\Worlds"
        $destPath    = Join-Path $destRoot $world.WorldId

        Write-Host ''
        Write-Host 'Pre-flight:' -ForegroundColor Cyan
        Write-Host "  World:    $($world.WorldName)"
        Write-Host "  ID:       $($world.WorldId)"
        Write-Host "  From:     $($world.Path)"
        Write-Host "  To:       $destPath"
        Write-Host ''

        $val = Test-WorldIdTripleMatch -WorldFolderPath $world.Path
        if ($val.Issues) {
            Write-Host '[WARN] Source world has ID issues:' -ForegroundColor Yellow
            foreach ($issue in $val.Issues) { Write-Host "  - $issue" }
            $c = Read-Host 'Continue anyway? (y/N)'
            if ($c -notmatch '^[Yy]') { return }
        } else { Write-Host '[OK] Source IDs consistent.' -ForegroundColor Green }

        if (Test-Path $destPath) {
            Write-Host "[WARN] Destination already exists: $destPath" -ForegroundColor Yellow
            $bk = Read-Host 'Back it up and overwrite? (Y/n)'
            if ($bk -match '^[Nn]') { Write-Host 'Cancelled.'; return }
            $bkResult = New-SaveBackup -Path $destPath -Label "server_$($world.WorldId)"
            if (-not $bkResult) { Write-Host 'Backup failed. Aborting.'; return }
        }

        Write-Host 'Backing up source...'
        $srcBk = New-SaveBackup -Path $world.Path -Label "client_$($world.WorldId)"
        if (-not $srcBk) { Write-Host 'Source backup failed. Aborting.'; return }

        $confirm = Read-Host "Copy '$($world.WorldName)' to server? (Y/n)"
        if ($confirm -match '^[Nn]') { Write-Host 'Cancelled.'; return }

        New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
        try {
            Copy-Item -Path $world.Path -Destination $destPath -Recurse -Force
            Write-Host '[OK] World copied to server.' -ForegroundColor Green
        } catch {
            Write-Host "[FAIL] Copy failed: $($_.Exception.Message)" -ForegroundColor Red; return
        }

        # Update ServerDescription.json
        if (Test-Path $serverDescPath) {
            try {
                $sd  = Get-Content $serverDescPath -Raw | ConvertFrom-Json
                $old = $sd.ServerDescription_Persistent.WorldIslandId
                $sd.ServerDescription_Persistent.WorldIslandId = $world.WorldId
                Set-Content -Path $serverDescPath -Value ($sd | ConvertTo-Json -Depth 10) -Force
                Write-Host "[OK] ServerDescription.json updated: $old -> $($world.WorldId)" -ForegroundColor Green
            } catch {
                Write-Host "[WARN] Could not update ServerDescription.json: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Host "  Manually set WorldIslandId to: $($world.WorldId)"
            }
        } else {
            Write-Host "[WARN] ServerDescription.json not found - manually set WorldIslandId to: $($world.WorldId)" -ForegroundColor Yellow
        }

        Write-Host ''
        Write-Host 'Post-transfer validation:' -ForegroundColor Cyan
        $postVal = Test-WorldIdTripleMatch -WorldFolderPath $destPath -ServerDescPath $serverDescPath
        if ($postVal.AllMatch) {
            Write-Host '[OK] All IDs match. Transfer successful.' -ForegroundColor Green
        } else {
            Write-Host '[WARN] ID mismatch after transfer - fix before starting server:' -ForegroundColor Yellow
            foreach ($issue in $postVal.Issues) { Write-Host "  - $issue" }
            Write-Host "  Open: $serverDescPath"
            Write-Host "  Set WorldIslandId to exactly: $($world.WorldId)"
        }

    } else {
        # --- Server -> Client ---
        $worlds = @(Find-ServerWorldFolders -ServerPath $serverPath)
        if (-not $worlds -or $worlds.Count -eq 0) {
            Write-Host '[FAIL] No worlds found on server.' -ForegroundColor Red
            Write-Host "  Looked in: $(Join-Path $serverPath $script:ServerSaveRoot)"
            return
        }
        Write-Host ''
        Write-Host 'Server worlds:'
        for ($i = 0; $i -lt $worlds.Count; $i++) {
            Write-Host "  $($i+1). $($worlds[$i].WorldName)  (ID: $($worlds[$i].WorldId))"
            Write-Host "       $($worlds[$i].Path)"
        }
        $pick  = Read-Host "Which world? (1-$($worlds.Count))"
        $world = $worlds[[math]::Max(0,[int]$pick - 1)]

        $profileRoot = "$env:LOCALAPPDATA\R5\Saved\SaveProfiles"
        $profiles    = @(Get-ChildItem -Path $profileRoot -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer })
        $profile     = $null

        if ($profiles.Count -eq 1) {
            $profile = $profiles[0].FullName
        } elseif ($profiles.Count -gt 1) {
            Write-Host 'Client profiles:'
            for ($i = 0; $i -lt $profiles.Count; $i++) { Write-Host "  $($i+1). $($profiles[$i].Name)" }
            $pick    = Read-Host "Which profile? (1-$($profiles.Count))"
            $profile = $profiles[[math]::Max(0,[int]$pick - 1)].FullName
        } else {
            $profile = $profileRoot
        }

        $versionPart = Split-Path (Split-Path $world.Path -Parent) -Leaf
        $destRoot    = Join-Path $profile "RocksDB\$versionPart\Worlds"
        $destPath    = Join-Path $destRoot $world.WorldId

        Write-Host ''
        Write-Host "From: $($world.Path)"
        Write-Host "To:   $destPath"

        if (Test-Path $destPath) {
            Write-Host "[WARN] Destination exists." -ForegroundColor Yellow
            $bk = Read-Host 'Back it up and overwrite? (Y/n)'
            if ($bk -match '^[Nn]') { Write-Host 'Cancelled.'; return }
            $bkResult = New-SaveBackup -Path $destPath -Label "client_$($world.WorldId)"
            if (-not $bkResult) { Write-Host 'Backup failed. Aborting.'; return }
        }

        Write-Host 'Backing up source...'
        $srcBk = New-SaveBackup -Path $world.Path -Label "server_$($world.WorldId)"
        if (-not $srcBk) { Write-Host 'Source backup failed. Aborting.'; return }

        $confirm = Read-Host "Copy '$($world.WorldName)' to client? (Y/n)"
        if ($confirm -match '^[Nn]') { Write-Host 'Cancelled.'; return }

        New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
        try {
            Copy-Item -Path $world.Path -Destination $destPath -Recurse -Force
            Write-Host '[OK] World copied to client.' -ForegroundColor Green
            Write-Host "When starting the game, choose 'local' saves if prompted."
        } catch {
            Write-Host "[FAIL] Copy failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# --- Config validation ---

function Invoke-ValidateServerConfig {
    Write-Host ''
    Write-Host '--- Validate Server Config ---' -ForegroundColor Cyan

    $serverPath = Resolve-ServerPath
    if (-not $serverPath) { return }
    $serverDescPath = Join-Path $serverPath $script:ServerDescFile

    if (-not (Test-Path $serverDescPath)) {
        Write-Host "[FAIL] ServerDescription.json not found: $serverDescPath" -ForegroundColor Red
        Write-Host '  Start the server once to generate it, then validate.'
        return
    }

    try {
        $sd           = Get-Content $serverDescPath -Raw | ConvertFrom-Json
        $configuredId = $sd.ServerDescription_Persistent.WorldIslandId
        Write-Host "  Active WorldIslandId in ServerDescription.json: $configuredId"
    } catch {
        Write-Host "[FAIL] Could not read ServerDescription.json: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    $worlds = @(Find-ServerWorldFolders -ServerPath $serverPath)
    if (-not $worlds -or $worlds.Count -eq 0) {
        Write-Host '[WARN] No world folders found on server.' -ForegroundColor Yellow
        Write-Host '  Transfer a world or run the server once to create one.'
        return
    }

    Write-Host ''
    Write-Host "Worlds on server ($($worlds.Count)):" -ForegroundColor Cyan
    $allOk = $true

    foreach ($world in $worlds) {
        Write-Host ''
        Write-Host "  World: $($world.WorldName)  (Folder: $($world.WorldId))"
        $val = Test-WorldIdTripleMatch -WorldFolderPath $world.Path -ServerDescPath $serverDescPath

        if ($val.FolderMatchDesc) {
            Write-Host '    [OK  ] Folder name matches islandId in WorldDescription.json' -ForegroundColor Green
        } else {
            Write-Host "    [FAIL] Folder '$($val.FolderId)' != islandId '$($val.DescIslandId)'" -ForegroundColor Red
            $allOk = $false
        }

        if ($world.WorldId -eq $configuredId) {
            Write-Host '    [OK  ] This is the ACTIVE world (matches ServerDescription.json WorldIslandId)' -ForegroundColor Green
        } else {
            Write-Host "    [INFO] Not the active world (server will load '$configuredId')" -ForegroundColor Gray
        }

        foreach ($issue in $val.Issues) {
            Write-Host "    [WARN] $issue" -ForegroundColor Yellow
            $allOk = $false
        }
    }

    # Check configured ID actually exists
    if (-not ($worlds | Where-Object { $_.WorldId -eq $configuredId })) {
        Write-Host ''
        Write-Host "[FAIL] WorldIslandId '$configuredId' does not match any world folder." -ForegroundColor Red
        Write-Host '  Server will generate a FRESH WORLD on next start.'
        Write-Host '  Fix: set WorldIslandId in ServerDescription.json to one of the folder names above.'
        $allOk = $false
    }

    Write-Host ''
    if ($allOk) {
        Write-Host '[OK] All IDs consistent. No mismatch risk.' -ForegroundColor Green
    } else {
        Write-Host '[WARN] Mismatches found. Fix before starting server to avoid progress loss.' -ForegroundColor Yellow
        Write-Host "  File to edit: $serverDescPath"
        Write-Host '  Rule: folder name == islandId in WorldDescription.json == WorldIslandId in ServerDescription.json'
        Write-Host '  Do NOT rename world folders - the database uses those IDs as keys.'
    }
}

# -------------------------------------------------------------------------------
# Export and redaction
# -------------------------------------------------------------------------------

function Export-Summary {
    Write-Section "Captain's summary"
    foreach ($item in $script:Summary) {
        $prefix = switch ($item.Status) { 'PASS' {'[OK  ]'} 'WARN' {'[WARN]'} 'FAIL' {'[FAIL]'} default {'[INFO]'} }
        Write-Line "$prefix $($item.Check): $($item.Details)"
    }

    $summaryCsv = Join-Path $script:RootOut 'Manifest.csv'
    $script:Summary | Export-Csv -Path $summaryCsv -NoTypeInformation -Force

    $md = New-Object System.Text.StringBuilder
    [void]$md.AppendLine("# Windrose Captain's Chest - diagnostic report")
    [void]$md.AppendLine('')
    [void]$md.AppendLine("- **Logged:** $(Get-Date)")
    [void]$md.AppendLine("- **Ship:** $env:COMPUTERNAME")
    [void]$md.AppendLine("- **Admin:** $(Test-Admin)")
    [void]$md.AppendLine('')
    [void]$md.AppendLine('## Findings')
    [void]$md.AppendLine('')
    [void]$md.AppendLine('| Status | Check | Details |')
    [void]$md.AppendLine('|--------|-------|---------|')
    foreach ($item in $script:Summary) {
        [void]$md.AppendLine("| $($item.Status) | $($item.Check) | $($item.Details -replace '\|','\|') |")
    }
    Set-Content -Path $script:MarkdownFile -Value $md.ToString() -Force

    $zipPath = "$script:RootOut.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path "$script:RootOut\*" -DestinationPath $zipPath -Force

    Write-Section 'Chest sealed'
    Write-Line "Folder:   $script:RootOut"
    Write-Line "Zip:      $zipPath"
    Write-Line "Markdown: $script:MarkdownFile"
}

function New-RedactedReport {
    param([string]$InputPath, [string]$OutputPath)
    if (-not (Test-Path $InputPath)) { return $false }
    $content = Get-Content $InputPath -Raw

    $content = $content -replace [regex]::Escape($env:COMPUTERNAME), '<REDACTED_HOSTNAME>'
    $content = $content -replace [regex]::Escape($env:USERNAME),     '<REDACTED_USER>'
    $content = $content -replace [regex]::Escape($env:USERPROFILE),  'C:\Users\<REDACTED_USER>'
    $content = $content -replace [regex]::Escape("C:\Users\$env:USERNAME"), 'C:\Users\<REDACTED_USER>'

    $content = [regex]::Replace($content, '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b', {
        param($m)
        $ip = $m.Value; $parts = $ip.Split('.')
        foreach ($p in $parts) { if ([int]$p -gt 255) { return $ip } }
        $o1 = [int]$parts[0]; $o2 = [int]$parts[1]
        if ($o1 -in @(0,10,127) -or
            ($o1 -eq 169 -and $o2 -eq 254) -or
            ($o1 -eq 172 -and $o2 -ge 16 -and $o2 -le 31) -or
            ($o1 -eq 192 -and $o2 -eq 168) -or
            $o1 -ge 224 -or
            $ip -in @('1.1.1.1','1.0.0.1','8.8.8.8','8.8.4.4','9.9.9.9')) { return $ip }
        return '<REDACTED_PUBLIC_IP>'
    })

    $content = $content -replace 'DHCPv6 Client DUID[\.\s]*:\s*[\w\-]+', 'DHCPv6 Client DUID . . . : <REDACTED_DUID>'
    $content = $content -replace '\b([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}\b', '<REDACTED_MAC>'
    $content = $content -replace 'fe80::[0-9a-fA-F:]+', 'fe80::<REDACTED>'

    Set-Content -Path $OutputPath -Value ("REDACTED REPORT - safe to share`nGenerated: $(Get-Date)`n`n" + $content) -Force
    return $true
}

function Invoke-RedactionFlow {
    if ($NoRedactPrompt) { return }
    $create = $Redact
    if (-not $create) {
        Write-Host ''
        $ans = Read-Host 'Create redacted copy for sharing? (Y/n)'
        $create = ([string]::IsNullOrWhiteSpace($ans) -or $ans -match '^[Yy]')
    }
    if (-not $create) { return }

    $okTxt = New-RedactedReport -InputPath $script:ReportFile   -OutputPath (Join-Path $script:RootOut 'CaptainsLog_REDACTED.txt')
    $okMd  = New-RedactedReport -InputPath $script:MarkdownFile -OutputPath (Join-Path $script:RootOut 'CaptainsLog_REDACTED.md')

    $zipPath = "$script:RootOut.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path "$script:RootOut\*" -DestinationPath $zipPath -Force

    if ($okTxt -or $okMd) {
        Write-Host "Redacted copies in: $script:RootOut" -ForegroundColor Green
        Write-Host 'Share the REDACTED version publicly, not the full log.'
    }
}

# -------------------------------------------------------------------------------
# Main
# -------------------------------------------------------------------------------

Show-Banner

$selectedMode = Prompt-Menu

# Shipwright is interactive only - no log file
if ($selectedMode -eq 'Shipwright') {
    Invoke-Shipwright
    if (-not $NoPause) { Read-Host 'Press Enter to dock' }
    exit 0
}

Initialize-Output

Write-Line "Windrose Captain's Chest - diagnostic report"
Write-Line "Logged:  $(Get-Date)"
Write-Line "Ship:    $env:COMPUTERNAME"
Write-Line "Admin:   $(Test-Admin)"
Write-Line "Mode:    $selectedMode"

# Core checks - run in both modes
Get-PublicIP
Get-LocalNetworkSummary
Run-CommandCapture -Label 'IP configuration' -Command { ipconfig /all }
Test-WindroseServices
Check-LocalFirewallRules
Check-HostsFile
Check-SteamAndProcesses
$installs = Get-GameVersionInfo
Collect-GameFiles -Installs $installs
Check-RecentErrors

# Mode 2 additions
if ($selectedMode -eq 'CantReachServer') {
    $target = Prompt-ServerTarget
    if (-not [string]::IsNullOrWhiteSpace($target.IP)) {
        Test-ServerReachability -Target $target.IP -Port $target.Port
    } else {
        Add-Finding -Status 'FAIL' -Check 'Server target' -Details 'No IP or hostname provided.'
        Write-Line 'No target entered. Server reachability tests skipped.'
    }
}

Export-Summary
Invoke-RedactionFlow

Write-Host ''
Write-Host "Chest sealed: $script:RootOut.zip" -ForegroundColor Yellow
Write-Host 'Fair winds, Captain.' -ForegroundColor Yellow

if (-not $NoPause) {
    Write-Host ''
    Read-Host 'Press Enter to dock'
}
