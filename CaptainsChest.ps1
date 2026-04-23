<#
.SYNOPSIS
    Captain's Chest - networking and game diagnostic toolkit for Windrose crews.

.DESCRIPTION
    Three modes:
      1. Connection trouble  - ISP detection, fleet endpoint checks, port 3478,
                               Windows Firewall, game version, recent crash logs
      2. Can't reach server  - everything in mode 1 plus DNS, ping, and traceroute
                               to a user-supplied server IP/hostname
      3. Shipwright          - dedicated server validation: config files, save profiles,
                               firewall rules, port checks, crash logs

    Outputs to a timestamped folder on your Desktop:
      - CaptainsLog.txt          full human-readable report
      - CaptainsLog.md           pasteable markdown for Discord/forum
      - CaptainsLog_REDACTED.*   optional scrubbed copies safe to post publicly
      - Manifest.csv             PASS/WARN/FAIL findings
      - Salvage/                 collected game and config files
      - Chest_<timestamp>.zip    sealed for transport

.PARAMETER OutputPath
    Root folder for the chest. Default: Desktop\WindroseCaptainChest

.PARAMETER ServerIP
    Server IP or hostname (pre-fills mode 2 prompt).

.PARAMETER ServerPort
    Port to test. Default: 7777.

.PARAMETER Mode
    ConnectionTrouble | CantReachServer | Shipwright | '' (prompts if blank).

.PARAMETER SkipTraceRoute
    Skip tracert step (saves ~30 seconds). Mode 2 only.

.PARAMETER NoPause
    Don't wait for a key press at the end.

.PARAMETER Redact
    Automatically create a redacted report without prompting.

.PARAMETER NoRedactPrompt
    Skip the redaction prompt entirely (don't create one).

.EXAMPLE
    .\CaptainsChest.ps1
    .\CaptainsChest.ps1 -Mode CantReachServer -ServerIP 1.2.3.4
    .\CaptainsChest.ps1 -Mode Shipwright -NoPause -Redact
#>

param(
    [string]$OutputPath = "$env:USERPROFILE\Desktop\WindroseCaptainChest",
    [string]$ServerIP   = "",
    [int]$ServerPort    = 7777,
    [ValidateSet('ConnectionTrouble','CantReachServer','Shipwright','')]
    [string]$Mode = '',
    [switch]$SkipTraceRoute,
    [switch]$NoPause,
    [switch]$Redact,
    [switch]$NoRedactPrompt
)

$ErrorActionPreference = 'SilentlyContinue'
Set-StrictMode -Version Latest

# -------------------------------------------------------------------------------
# Windrose backend service endpoints
# -------------------------------------------------------------------------------
$script:WindroseServiceEndpoints = @(
    [pscustomobject]@{ Name = 'EU/NA API Gateway (primary)';   Host = 'r5coopapigateway-eu-release.windrose.support';   Port = 443;  Region = 'EU & NA' }
    [pscustomobject]@{ Name = 'EU/NA API Gateway (failover)';  Host = 'r5coopapigateway-eu-release-2.windrose.support'; Port = 443;  Region = 'EU & NA' }
    [pscustomobject]@{ Name = 'RU/CIS API Gateway (primary)';  Host = 'r5coopapigateway-ru-release.windrose.support';   Port = 443;  Region = 'CIS' }
    [pscustomobject]@{ Name = 'RU/CIS API Gateway (failover)'; Host = 'r5coopapigateway-ru-release-2.windrose.support'; Port = 443;  Region = 'CIS' }
    [pscustomobject]@{ Name = 'KR/SEA API Gateway (primary)';  Host = 'r5coopapigateway-kr-release.windrose.support';   Port = 443;  Region = 'SEA (South Korea)' }
    [pscustomobject]@{ Name = 'KR/SEA API Gateway (failover)'; Host = 'r5coopapigateway-kr-release-2.windrose.support'; Port = 443;  Region = 'SEA (South Korea)' }
    [pscustomobject]@{ Name = 'Sentry (error reporting)';      Host = 'sentry.windrose.support';                        Port = 443;  Region = 'Global' }
    [pscustomobject]@{ Name = 'STUN/TURN (P2P signaling)';     Host = 'windrose.support';                               Port = 3478; Region = 'Global' }
)

# -------------------------------------------------------------------------------
# ISP culprit table
# Maps ISP org-name fragments to router security features that block game traffic.
# Matching is case-insensitive against the "org" field returned by ipinfo.io.
# -------------------------------------------------------------------------------
$script:IspCulpritTable = @(
    # --- United States ---
    @{ Match = 'Spectrum|Charter';       Name = 'Spectrum (Charter)';      Feature = 'Security Shield';              Toggle = 'My Spectrum app > Internet > Security Shield > OFF';              Country = 'US'; KnownBlocksWindrose = $true  }
    @{ Match = 'Comcast|Xfinity';        Name = 'Xfinity (Comcast)';       Feature = 'xFi Advanced Security';        Toggle = 'Xfinity app > WiFi > See Network > Advanced Security > OFF';      Country = 'US'; KnownBlocksWindrose = $true  }
    @{ Match = 'Cox Communications';     Name = 'Cox';                     Feature = 'Cox Security Suite';           Toggle = 'Cox webmail/panel > Security Suite > disable';                     Country = 'US'; KnownBlocksWindrose = $false }
    @{ Match = 'AT&T|AT&amp;T';          Name = 'AT&T';                    Feature = 'ActiveArmor';                  Toggle = 'Smart Home Manager app > ActiveArmor > toggle Internet Security'; Country = 'US'; KnownBlocksWindrose = $false }
    @{ Match = 'CenturyLink|Lumen';      Name = 'CenturyLink/Lumen';       Feature = 'Connection Shield';            Toggle = 'centurylink.com/myaccount > Internet > Connection Shield';         Country = 'US'; KnownBlocksWindrose = $false }
    @{ Match = 'Verizon';                Name = 'Verizon Fios/5G Home';    Feature = 'Network Protection';           Toggle = 'My Verizon app > Services > Digital Secure';                      Country = 'US'; KnownBlocksWindrose = $false }
    @{ Match = 'T-Mobile';               Name = 'T-Mobile Home Internet';  Feature = 'Network Protection';           Toggle = 'T-Life app > Home Internet > Network settings';                   Country = 'US'; KnownBlocksWindrose = $false }
    @{ Match = 'Optimum|Cablevision';    Name = 'Optimum (Altice)';        Feature = 'Optimum Internet Protection';  Toggle = 'optimum.net account > Internet Security > disable';               Country = 'US'; KnownBlocksWindrose = $false }
    @{ Match = 'Frontier';               Name = 'Frontier';                Feature = 'Secure (Whole-Home)';          Toggle = 'frontier.com/helpcenter > Internet Security > disable';            Country = 'US'; KnownBlocksWindrose = $false }
    # --- United Kingdom ---
    @{ Match = 'British Telecom|BT ';    Name = 'BT';                      Feature = 'Web Protect';                  Toggle = 'my.bt.com > Broadband > Manage Web Protect > OFF';                Country = 'UK'; KnownBlocksWindrose = $true  }
    @{ Match = 'Sky UK|Sky Broadband';   Name = 'Sky';                     Feature = 'Broadband Shield';             Toggle = 'sky.com/mysky > Broadband Shield > set to None';                  Country = 'UK'; KnownBlocksWindrose = $false }
    @{ Match = 'Virgin Media';           Name = 'Virgin Media';            Feature = 'Web Safe';                     Toggle = 'virginmedia.com/my-account > Web Safe > disable';                 Country = 'UK'; KnownBlocksWindrose = $false }
    @{ Match = 'TalkTalk';               Name = 'TalkTalk';                Feature = 'HomeSafe';                     Toggle = 'my.talktalk.co.uk > HomeSafe > disable';                          Country = 'UK'; KnownBlocksWindrose = $false }
    # --- Europe ---
    @{ Match = 'Ziggo|VodafoneZiggo';    Name = 'Ziggo (NL)';              Feature = 'Default domain filter';        Toggle = 'mijn.ziggo.nl > Security/router settings';                        Country = 'NL'; KnownBlocksWindrose = $true  }
    @{ Match = 'Orange ';                Name = 'Orange (FR/ES)';          Feature = 'Livebox parental/security';    Toggle = 'Livebox admin 192.168.1.1 > Security/parental controls > OFF';    Country = 'FR'; KnownBlocksWindrose = $false }
    @{ Match = 'Free SAS|Free ';         Name = 'Free (FR)';               Feature = 'Freebox security';             Toggle = 'freebox.fr > Securite > adjust filtering';                         Country = 'FR'; KnownBlocksWindrose = $false }
    @{ Match = 'Deutsche Telekom';       Name = 'Deutsche Telekom (DE)';   Feature = 'Default firewall';             Toggle = 'Speedport admin > Firewall > customize rules';                    Country = 'DE'; KnownBlocksWindrose = $false }
    @{ Match = 'Telekom';                Name = 'Telekom (DE/EU)';         Feature = 'Default security';             Toggle = 'Router admin panel > Security settings';                          Country = 'EU'; KnownBlocksWindrose = $false }
    @{ Match = 'Vodafone';               Name = 'Vodafone (EU)';           Feature = 'Secure Net';                   Toggle = 'My Vodafone app > Secure Net > disable';                          Country = 'EU'; KnownBlocksWindrose = $false }
    # --- Canada ---
    @{ Match = 'Rogers Communications';  Name = 'Rogers (CA)';             Feature = 'Shield';                       Toggle = 'MyRogers app > Internet > Shield > OFF';                          Country = 'CA'; KnownBlocksWindrose = $false }
    @{ Match = 'Bell Canada';            Name = 'Bell (CA)';               Feature = 'Internet Security';            Toggle = 'MyBell account > Internet > Security > disable';                  Country = 'CA'; KnownBlocksWindrose = $false }
    @{ Match = 'Telus';                  Name = 'Telus (CA)';              Feature = 'Online Security';              Toggle = 'My Telus account > Internet > Online Security';                   Country = 'CA'; KnownBlocksWindrose = $false }
    # --- Australia ---
    @{ Match = 'Telstra';                Name = 'Telstra (AU)';            Feature = 'Smart Modem security';         Toggle = 'My Telstra app > Home Internet > security settings';              Country = 'AU'; KnownBlocksWindrose = $false }
    @{ Match = 'Optus';                  Name = 'Optus (AU)';              Feature = 'Internet Security';            Toggle = 'My Optus app > Internet > Security > disable';                    Country = 'AU'; KnownBlocksWindrose = $false }
)

# -------------------------------------------------------------------------------
# Script state
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
    $banner = @"

     __        _____ _   _ ____  ____   ___  ____  _____
     \ \      / /_ _| \ | |  _ \|  _ \ / _ \/ ___|| ____|
      \ \ /\ / / | ||  \| | | | | |_) | | | \___ \|  _|
       \ V  V /  | || |\  | |_| |  _ <| |_| |___) | |___
        \_/\_/  |___|_| \_|____/|_| \_\\___/|____/|_____|
                 Captain's Chest  -  diagnostic toolkit
                        "No crew left ashore"

"@
    Write-Host $banner -ForegroundColor Yellow
}

# -------------------------------------------------------------------------------
# Output helpers
# -------------------------------------------------------------------------------
function Initialize-Output {
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $script:RootOut      = Join-Path $OutputPath $timestamp
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
    param([string]$Text)
    Write-Host $Text
    Add-Content -Path $script:ReportFile -Value $Text
}

function Write-TaggedLine {
    param(
        [ValidateSet('PASS','WARN','FAIL','INFO')]
        [string]$Status,
        [string]$Text
    )
    Write-Line ("[{0}] {1}" -f $Status, $Text)
}

function Add-Finding {
    param(
        [ValidateSet('PASS','WARN','FAIL','INFO')]
        [string]$Status,
        [string]$Check,
        [string]$Details
    )
    $script:Summary.Add([pscustomobject]@{
        Status  = $Status
        Check   = $Check
        Details = $Details
    }) | Out-Null
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
    $id        = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# -------------------------------------------------------------------------------
# Prompts
# -------------------------------------------------------------------------------
function Prompt-Mode {
    if ($Mode) { return $Mode }
    Write-Host ''
    Write-Host 'Chart yer course, Captain:' -ForegroundColor Green
    Write-Host '  1. Connection trouble  - game shows N/A, ISP/fleet/firewall checks'
    Write-Host '  2. Can''t reach server  - all of #1 plus DNS, ping, traceroute to a specific IP'
    Write-Host '  3. Shipwright          - dedicated server: config, saves, ports, logs'
    Write-Host ''
    $choice = Read-Host 'Yer choice (1-3) [default 1]'
    switch ($choice) {
        '2' { return 'CantReachServer' }
        '3' { return 'Shipwright' }
        default { return 'ConnectionTrouble' }
    }
}

function Prompt-ServerTarget {
    $targetIP   = $ServerIP
    $targetPort = $ServerPort

    if ([string]::IsNullOrWhiteSpace($targetIP)) {
        $targetIP = Read-Host 'Enter the server IP or hostname'
    }
    $portInput = Read-Host "Port number, or press Enter for $targetPort"
    if (-not [string]::IsNullOrWhiteSpace($portInput)) {
        $parsed = 0
        if ([int]::TryParse($portInput, [ref]$parsed)) { $targetPort = $parsed }
    }
    return [pscustomobject]@{ IP = $targetIP.Trim(); Port = $targetPort }
}

# -------------------------------------------------------------------------------
# OS info
# -------------------------------------------------------------------------------
function Get-OsInfo {
    Write-Section "Ship's papers (OS)"
    $os    = Get-CimInstance Win32_OperatingSystem
    $build = [int]$os.BuildNumber
    $arch  = $os.OSArchitecture

    $edition = try {
        (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name ProductName).ProductName
    } catch { $os.Caption }

    $marketingName = if ($build -ge 22000) { $edition -replace 'Windows 10', 'Windows 11' } else { $edition }

    $displayVersion = try {
        (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name DisplayVersion -ErrorAction Stop).DisplayVersion
    } catch { '' }

    Write-Line ("Product:      {0}" -f $marketingName)
    if ($displayVersion) { Write-Line ("Version:      {0}" -f $displayVersion) }
    Write-Line ("Build:        {0}" -f $build)
    Write-Line ("Architecture: {0}" -f $arch)
    Write-Line ("Host:         {0}" -f $env:COMPUTERNAME)
}

# -------------------------------------------------------------------------------
# Network - adapters, public IP
# -------------------------------------------------------------------------------
function Get-LocalNetworkSummary {
    Write-Section 'Home waters (local network)'
    $profiles = Get-NetConnectionProfile
    foreach ($p in $profiles) {
        Write-Line ("Network: {0} | Category: {1} | IPv4: {2} | IPv6: {3}" -f $p.Name, $p.NetworkCategory, $p.IPv4Connectivity, $p.IPv6Connectivity)
        if ($p.NetworkCategory -eq 'Public') {
            Add-Finding -Status 'WARN' -Check 'Network profile' -Details ("Profile '{0}' is Public - firewall may be stricter." -f $p.Name)
        }
    }
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    foreach ($a in $adapters) {
        Write-Line ("Adapter up: {0} | {1} | {2}" -f $a.Name, $a.InterfaceDescription, $a.LinkSpeed)
    }
}

function Get-PublicIP {
    Write-Section 'Flag on the mast (public IP)'
    $endpoints = @('https://api.ipify.org', 'https://ifconfig.me/ip', 'https://icanhazip.com')
    $publicIP  = $null
    foreach ($url in $endpoints) {
        try {
            $publicIP = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5).Content.Trim()
            if ($publicIP -match '^\d{1,3}(\.\d{1,3}){3}$') {
                Write-Line ("Public IP: {0}  (source: {1})" -f $publicIP, $url)
                Add-Finding -Status 'PASS' -Check 'Public IP' -Details "Public IP resolved: $publicIP"
                $script:PublicIP = $publicIP
                break
            } else { $publicIP = $null }
        } catch { continue }
    }
    if (-not $publicIP) {
        Write-Line 'Could not determine public IP from any endpoint.'
        Add-Finding -Status 'WARN' -Check 'Public IP' -Details 'Public IP lookup failed on all endpoints.'
    }
}

# -------------------------------------------------------------------------------
# DNS diagnostic - dual DNS check (system vs Google 8.8.8.8)
# -------------------------------------------------------------------------------
function Resolve-HostDnsDiagnostic {
    param([string]$HostName)

    $result = [pscustomobject]@{
        HostName        = $HostName
        SystemStatus    = 'Unknown'   # OK | NXDOMAIN | Timeout | Spoofed | IPv6Only
        SystemAddresses = @()
        PublicStatus    = 'Unknown'
        PublicAddresses = @()
        Diagnosis       = ''
    }

    # System DNS lookup
    try {
        $sys  = Resolve-DnsName -Name $HostName -Type A -QuickTimeout -ErrorAction Stop
        $ipv4 = @($sys | Where-Object { $_.Type -eq 'A'    -and $_.IPAddress } | Select-Object -ExpandProperty IPAddress -Unique)
        $ipv6 = @($sys | Where-Object { $_.Type -eq 'AAAA' -and $_.IPAddress } | Select-Object -ExpandProperty IPAddress -Unique)
        if ($ipv4) {
            $result.SystemAddresses = $ipv4
            $result.SystemStatus    = if ($ipv4 -contains '127.0.0.1' -or $ipv4 -contains '0.0.0.0') { 'Spoofed' } else { 'OK' }
        } elseif ($ipv6) {
            $result.SystemAddresses = $ipv6
            $result.SystemStatus    = 'IPv6Only'
        } else {
            $result.SystemStatus    = 'NXDOMAIN'
        }
    } catch {
        $result.SystemStatus = if ($_.Exception.Message -match 'timeout|timed out') { 'Timeout' } else { 'NXDOMAIN' }
    }

    # Google DNS lookup (bypasses ISP DNS)
    try {
        $pub  = Resolve-DnsName -Name $HostName -Type A -Server '8.8.8.8' -QuickTimeout -ErrorAction Stop
        $ipv4 = @($pub | Where-Object { $_.Type -eq 'A' -and $_.IPAddress } | Select-Object -ExpandProperty IPAddress -Unique)
        if ($ipv4) {
            $result.PublicAddresses = $ipv4
            $result.PublicStatus    = 'OK'
        } else {
            $result.PublicStatus    = 'NXDOMAIN'
        }
    } catch {
        $result.PublicStatus = if ($_.Exception.Message -match 'timeout|timed out') { 'Timeout' } else { 'NXDOMAIN' }
    }

    $result.Diagnosis = switch ($result.SystemStatus) {
        'OK'       { 'DNS resolves normally.' }
        'Spoofed'  { 'DNS SPOOFING: Your DNS is returning a loopback/null address. A VPN, parental controls, or custom DNS filter is intercepting this domain.' }
        'IPv6Only' { 'IPv6 ONLY: Only an IPv6 address was returned. Windrose does NOT support IPv6 - you need to prioritize IPv4 (see Troubleshooting).' }
        'Timeout'  { 'DNS TIMEOUT: Your DNS server did not respond. Check firewall/antivirus or switch to Google DNS (8.8.8.8).' }
        'NXDOMAIN' {
            if ($result.PublicStatus -eq 'OK') {
                'ISP BLOCK: Your ISP/router is blocking this domain. It resolves fine on Google DNS (8.8.8.8) but not on your system DNS.'
            } else {
                'DOMAIN DOWN: The domain does not resolve anywhere. This may be a dev-side issue or the domain has been retired.'
            }
        }
        default    { 'DNS resolution unclear.' }
    }

    return $result
}

# -------------------------------------------------------------------------------
# ISP detection and culprit matching
# -------------------------------------------------------------------------------
function Get-IspInfo {
    param([string]$PublicIP)
    if (-not $PublicIP) { return $null }

    # ipinfo.io - most reliable, good org names
    try {
        $resp = Invoke-WebRequest -Uri "https://ipinfo.io/$PublicIP/json" -UseBasicParsing -TimeoutSec 5
        $data = $resp.Content | ConvertFrom-Json
        if ($data.org) {
            return [pscustomobject]@{
                ISP     = $data.org
                ASN     = $(if ($data.org -match '^(AS\d+)') { $matches[1] } else { '' })
                City    = $data.city
                Country = $data.country
                Source  = 'ipinfo.io'
            }
        }
    } catch { }

    # ip-api.com fallback
    try {
        $resp = Invoke-WebRequest -Uri "http://ip-api.com/json/$PublicIP" -UseBasicParsing -TimeoutSec 5
        $data = $resp.Content | ConvertFrom-Json
        if ($data.status -eq 'success' -and $data.isp) {
            return [pscustomobject]@{
                ISP     = $data.isp
                ASN     = $data.as
                City    = $data.city
                Country = $data.countryCode
                Source  = 'ip-api.com'
            }
        }
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

function Show-IspDiagnosis {
    Write-Section 'Port authority (your ISP)'

    if (-not $script:PublicIP) {
        Write-Line 'Public IP unknown - skipping ISP lookup.'
        return $null
    }

    $isp = Get-IspInfo -PublicIP $script:PublicIP
    if (-not $isp) {
        Write-Line 'Could not identify ISP from public IP.'
        Add-Finding -Status 'INFO' -Check 'ISP detection' -Details 'IP lookup services did not return ISP info.'
        return $null
    }

    Write-Line ("ISP:      {0}" -f $isp.ISP)
    if ($isp.ASN)     { Write-Line ("ASN:      {0}" -f $isp.ASN) }
    if ($isp.City)    { Write-Line ("City:     {0}" -f $isp.City) }
    if ($isp.Country) { Write-Line ("Country:  {0}" -f $isp.Country) }

    $culprit = Match-IspCulprit -IspOrg $isp.ISP
    if ($culprit) {
        Write-Line ''
        Write-Line '*** HEADS UP: your ISP ships routers with a security feature that ***'
        Write-Line '*** commonly blocks legitimate gaming traffic, including Windrose. ***'
        Write-Line ''
        Write-Line ("ISP:              {0}" -f $culprit.Name)
        Write-Line ("Feature to check: {0}" -f $culprit.Feature)
        Write-Line ("Where to toggle:  {0}" -f $culprit.Toggle)
        Write-Line ''
        if ($culprit.KnownBlocksWindrose) {
            Write-Line '** This ISP has been CONFIRMED to block Windrose specifically. **'
            Write-Line 'Turning this feature off has fixed the issue for other players on'
            Write-Line 'this same ISP. If the Fleet check below shows port 3478 blocked or'
            Write-Line 'any Windrose domain unreachable, toggle this feature off FIRST.'
            Add-Finding -Status 'WARN' -Check 'ISP' -Details "$($culprit.Name) - $($culprit.Feature) confirmed to block Windrose. Toggle OFF: $($culprit.Toggle)"
        } else {
            Write-Line 'This feature has been reported to block similar P2P games like'
            Write-Line 'Rust, Palworld, and Ark. If the Fleet check below shows issues,'
            Write-Line 'toggling this feature off is worth trying before anything else.'
            Add-Finding -Status 'INFO' -Check 'ISP' -Details "$($culprit.Name) - consider toggling off $($culprit.Feature) if Fleet check fails. Location: $($culprit.Toggle)"
        }
        return $culprit
    }

    Write-Line ''
    Write-Line 'Your ISP is not in the known-culprit list. That does NOT mean your ISP'
    Write-Line 'is safe - many ISPs ship router security features that block gaming'
    Write-Line 'traffic, and this list only covers the big ones. If the Fleet check'
    Write-Line 'below shows issues, check your ISP app or router admin page for any'
    Write-Line '"security", "threat protection", or "safe browsing" toggle and try'
    Write-Line 'turning it off.'
    Add-Finding -Status 'INFO' -Check 'ISP' -Details "$($isp.ISP) - not in known-culprit list. Check ISP app/router for security toggles if Fleet check fails."
    return $null
}

function Show-KnownIspTable {
    Write-Section 'Known ISP router security features to check'
    Write-Line 'If your ISP auto-detection above missed you, or if the Fleet check'
    Write-Line 'shows connection issues, check whether your ISP is on this list and'
    Write-Line 'toggle off the named feature:'
    Write-Line ''

    $confirmedBlocks = $script:IspCulpritTable | Where-Object {  $_.KnownBlocksWindrose }
    $otherKnown      = $script:IspCulpritTable | Where-Object { -not $_.KnownBlocksWindrose }

    if ($confirmedBlocks) {
        Write-Line 'CONFIRMED to block Windrose:'
        Write-Line ('  ' + ('-' * 80))
        foreach ($c in $confirmedBlocks) {
            Write-Line ('  {0,-28} {1,-30} [{2}]' -f $c.Name, $c.Feature, $c.Country)
        }
        Write-Line ''
    }

    Write-Line 'Known to block similar P2P games (Rust, Palworld, Ark, etc.):'
    Write-Line ('  ' + ('-' * 80))
    foreach ($c in $otherKnown) {
        Write-Line ('  {0,-28} {1,-30} [{2}]' -f $c.Name, $c.Feature, $c.Country)
    }
    Write-Line ''
    Write-Line 'Note: Dedicated server hosts (SurvivalServers, LOW.MS, g-portal etc.) do'
    Write-Line 'NOT have these problems - they run on business connections without consumer'
    Write-Line 'security filters. The block is almost always on your residential end.'
}

# -------------------------------------------------------------------------------
# Fleet check - Windrose backend service reachability
# -------------------------------------------------------------------------------
function Write-FleetDiagnosisSummary {
    param(
        [int]$Reachable,
        [int]$Unreachable,
        [bool]$AnyDnsSpoof,
        [bool]$AnyIspBlock,
        [bool]$AnyIpv6Issue,
        [bool]$HasPartialReachability,
        [bool]$Stun3478Reachable,
        [object]$DetectedCulprit
    )

    Write-Section 'Diagnosis'
    Write-Line 'What this means for the player:'
    Write-Line ''

    if ($Reachable -eq $script:WindroseServiceEndpoints.Count) {
        Write-TaggedLine -Status 'PASS' -Text 'Windrose backend services are reachable from this machine.'
        Write-Line 'The game should be able to reach Connection Services.'
        Write-Line 'If the game still fails, the issue is likely local: Steam, game client, or firewall.'
        Write-Line ''
        Write-Line 'Next steps:'
        Write-Line '  - Restart Windrose and Steam'
        Write-Line '  - Verify game files in Steam'
        Write-Line '  - Check local firewall/AV prompts'
        Add-Finding -Status 'PASS' -Check 'Diagnosis' -Details 'All Windrose backend services reachable. Likely a local client or Steam issue if problems continue.'
        return
    }

    if ($AnyDnsSpoof) {
        Write-TaggedLine -Status 'FAIL' -Text 'Your DNS is returning fake or filtered answers for one or more Windrose domains.'
        Write-Line 'Usually caused by a VPN, parental controls, safe browsing, or a custom DNS filter.'
        Write-Line ''
        Write-Line 'Next steps:'
        Write-Line '  - Disable VPN / proxy / filtering software'
        Write-Line '  - Switch DNS to 8.8.8.8 or 1.1.1.1'
        Write-Line '  - Run: ipconfig /flushdns'
        Add-Finding -Status 'FAIL' -Check 'Diagnosis' -Details 'DNS spoofing or filtering detected on Windrose domains.'
        return
    }

    if ($AnyIspBlock) {
        if ($DetectedCulprit) {
            Write-TaggedLine -Status 'FAIL' -Text ("ISP/router is likely blocking Windrose. Most likely culprit: {0} -> {1}." -f $DetectedCulprit.Name, $DetectedCulprit.Feature)
            Write-Line ("Toggle path: {0}" -f $DetectedCulprit.Toggle)
        } else {
            Write-TaggedLine -Status 'FAIL' -Text 'Your network is blocking Windrose domains before the game can connect.'
        }
        Write-Line 'The game may show N/A for Connection Services because DNS works on Google DNS but not on your network path.'
        Write-Line ''
        Write-Line 'Next steps:'
        Write-Line '  - Disable ISP security / threat protection features'
        Write-Line '  - Switch DNS to 8.8.8.8 or 1.1.1.1'
        Write-Line '  - Try a VPN or hotspot to confirm the block'
        Write-Line '  - Ask the ISP to whitelist *.windrose.support and port 3478'
        Write-Line ''
        Write-TaggedLine -Status 'INFO' -Text 'Fallback: Direct IP mode (Host > Direct IP tab > port 7777) bypasses Connection Services entirely.'
        Add-Finding -Status 'FAIL' -Check 'Diagnosis' -Details 'ISP or network DNS blocking detected for Windrose services.'
        return
    }

    if ($AnyIpv6Issue) {
        Write-TaggedLine -Status 'FAIL' -Text 'Windows is preferring IPv6 answers, but Windrose needs IPv4.'
        Write-Line 'The domains resolve, but the game may fail because it does not handle IPv6-only paths.'
        Write-Line ''
        Write-Line 'Next steps:'
        Write-Line '  - Keep IPv6 enabled, but set Windows to prefer IPv4'
        Write-Line '  - Run as admin: reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" /v DisabledComponents /t REG_DWORD /d 32 /f'
        Write-Line '  - Reboot after applying the change. To revert later use /d 0 instead of /d 32.'
        Add-Finding -Status 'FAIL' -Check 'Diagnosis' -Details 'IPv6 prioritization issue detected. Game is IPv4-only.'
        return
    }

    if ($HasPartialReachability) {
        if (-not $Stun3478Reachable) {
            if ($DetectedCulprit) {
                Write-TaggedLine -Status 'WARN' -Text ("Some services work, but P2P signaling is blocked. Likely cause: {0} -> {1}." -f $DetectedCulprit.Name, $DetectedCulprit.Feature)
                Write-Line ("Toggle path: {0}" -f $DetectedCulprit.Toggle)
            } else {
                Write-TaggedLine -Status 'WARN' -Text 'Some Windrose services work, but peer-to-peer signaling on port 3478 is blocked.'
            }
            Write-Line 'The game can see part of the backend but cannot complete the connection path for players to join each other.'
            Write-Line ''
            Write-Line 'Next steps:'
            Write-Line '  - Disable router / ISP security features'
            Write-Line '  - Test from a hotspot or VPN'
            Write-Line '  - Use Direct IP mode as a fallback if port 7777 is open on the host'
            Add-Finding -Status 'WARN' -Check 'Diagnosis' -Details 'Partial reachability with port 3478 blocked. Likely ISP/router security or P2P signaling failure.'
        } else {
            Write-TaggedLine -Status 'WARN' -Text 'Some Windrose endpoints are reachable and some are not.'
            Write-Line 'Points to a regional backend issue, routing problem, or selective ISP filtering.'
            Write-Line ''
            Write-Line 'Next steps:'
            Write-Line '  - Try another Connection Service region in-game'
            Write-Line '  - Check Windrose status channels for outages'
            Write-Line '  - Check router/firewall filtering if the issue persists'
            Add-Finding -Status 'WARN' -Check 'Diagnosis' -Details 'Partial reachability across Windrose endpoints. Possible regional outage or selective ISP filtering.'
        }
        return
    }

    Write-TaggedLine -Status 'FAIL' -Text 'All Windrose endpoints are unreachable from this machine.'
    Write-Line 'Either a full backend outage, a severe local/network block, or a broken internet path.'
    Write-Line ''
    Write-Line 'Next steps:'
    Write-Line '  - Check the official Discord and status channels'
    Write-Line '  - Confirm general internet connectivity'
    Write-Line '  - Test from another network'
    Write-Line '  - Use Direct IP mode as a fallback if hosting is possible'
    Add-Finding -Status 'FAIL' -Check 'Diagnosis' -Details 'All Windrose endpoints unreachable from this machine.'
}

function Test-WindroseServices {
    $detectedCulprit = Show-IspDiagnosis

    Write-Section 'Fleet check (Windrose services)'
    Write-Line 'Checking whether Windrose backend services are reachable from this machine.'
    Write-Line 'If the game shows "N/A" for Connection Services, this tells you whether it'
    Write-Line 'is ISP blocking, DNS issues, or a genuine outage.'
    Write-Line ''

    $anyIspBlock       = $false
    $anyDnsSpoof       = $false
    $anyIpv6Issue      = $false
    $reachable         = 0
    $unreachable       = 0
    $stun3478Reachable = $false
    $dnsIssues         = @()

    foreach ($endpoint in $script:WindroseServiceEndpoints) {
        Write-Line ("--- {0} ({1}) ---" -f $endpoint.Name, $endpoint.Region)

        $dns = Resolve-HostDnsDiagnostic -HostName $endpoint.Host
        Write-Line ("Host:         {0}" -f $endpoint.Host)
        Write-Line ("System DNS:   {0}{1}" -f $dns.SystemStatus, $(if ($dns.SystemAddresses) { ' -> ' + ($dns.SystemAddresses -join ', ') } else { '' }))
        Write-Line ("Google DNS:   {0}{1}" -f $dns.PublicStatus, $(if ($dns.PublicAddresses)  { ' -> ' + ($dns.PublicAddresses  -join ', ') } else { '' }))
        if ($dns.Diagnosis) { Write-Line ("Diagnosis:    {0}" -f $dns.Diagnosis) }

        if ($dns.SystemStatus -eq 'NXDOMAIN' -and $dns.PublicStatus -eq 'OK') {
            $anyIspBlock = $true
            $dnsIssues  += "$($endpoint.Host): ISP blocking"
        }
        if ($dns.SystemStatus -eq 'Spoofed')  { $anyDnsSpoof  = $true; $dnsIssues += "$($endpoint.Host): DNS spoofing" }
        if ($dns.SystemStatus -eq 'IPv6Only') { $anyIpv6Issue = $true; $dnsIssues += "$($endpoint.Host): IPv6-only (game needs IPv4)" }

        if ($dns.SystemStatus -eq 'OK' -and $dns.SystemAddresses) {
            try {
                $tcp = Test-NetConnection -ComputerName $endpoint.Host -Port $endpoint.Port -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                if ($tcp.TcpTestSucceeded) {
                    Write-Line ("TCP {0,-5}:   REACHABLE" -f $endpoint.Port)
                    $reachable++
                    if ($endpoint.Port -eq 3478) { $stun3478Reachable = $true }
                    Add-Finding -Status 'PASS' -Check "Fleet: $($endpoint.Name)" -Details "Reachable on $($endpoint.Host):$($endpoint.Port)."
                } else {
                    Write-Line ("TCP {0,-5}:   BLOCKED or DOWN" -f $endpoint.Port)
                    $unreachable++
                    Add-Finding -Status 'FAIL' -Check "Fleet: $($endpoint.Name)" -Details "TCP $($endpoint.Port) unreachable on $($endpoint.Host). DNS resolved but connection refused/filtered."
                }
            } catch {
                Write-Line ("TCP {0,-5}:   ERROR - {1}" -f $endpoint.Port, $_.Exception.Message)
                $unreachable++
            }
        } else {
            Write-Line ("TCP {0,-5}:   skipped (DNS failed)" -f $endpoint.Port)
            $unreachable++
            Add-Finding -Status 'FAIL' -Check "Fleet: $($endpoint.Name)" -Details "$($endpoint.Host) could not be resolved via system DNS. See Fleet check section for diagnosis."
        }

        Write-Line ''
    }

    Write-Section 'Fleet check summary'
    Write-Line ("Reachable endpoints:    {0} of {1}" -f $reachable, $script:WindroseServiceEndpoints.Count)
    Write-Line ("Unreachable endpoints:  {0}" -f $unreachable)
    Write-Line ''

    if ($reachable -eq $script:WindroseServiceEndpoints.Count) {
        Write-Line 'GOOD NEWS: All Windrose services are reachable from your machine.'
        Write-Line 'If the game still shows "N/A", restart Windrose and Steam.'
        Add-Finding -Status 'PASS' -Check 'Fleet: Overall' -Details "All $reachable Windrose service endpoints reachable."
    } elseif ($anyDnsSpoof) {
        Write-Line '*** DNS SPOOFING DETECTED ***'
        Write-Line 'Switch to Google DNS: Settings > Network & Internet > connection > Properties'
        Write-Line '  > Edit DNS > Manual > IPv4: Preferred 8.8.8.8  Alternate 8.8.4.4'
        Write-Line '  > Save, then run: ipconfig /flushdns'
        Add-Finding -Status 'FAIL' -Check 'Fleet: Overall' -Details 'DNS spoofing detected. See Fleet check section for fix.'
    } elseif ($anyIspBlock) {
        Write-Line '*** ISP / NETWORK BLOCKING DETECTED ***'
        Write-Line ''
        Write-Line 'Your ISP or router is preventing resolution of Windrose endpoints.'
        Write-Line 'Google DNS resolves them fine, but your system DNS does not.'
        Write-Line ''
        if ($detectedCulprit) {
            Write-Line ('*** THIS IS ALMOST CERTAINLY YOUR FIX: {0} ***' -f $detectedCulprit.Name)
            Write-Line ("  Toggle OFF: {0}" -f $detectedCulprit.Feature)
            Write-Line ("  Where:      {0}" -f $detectedCulprit.Toggle)
            Write-Line ''
            if ($detectedCulprit.KnownBlocksWindrose) {
                Write-Line '  This has been confirmed to fix the exact same problem for other'
                Write-Line '  players on this ISP. Try this FIRST before anything else.'
            } else {
                Write-Line '  Other players on this ISP have fixed similar game connectivity'
                Write-Line '  issues (Rust, Palworld, Ark) by toggling this feature off.'
            }
            Write-Line ''
            Write-Line 'If that does not fix it, or you cannot find the toggle:'
        }
        Write-Line '  Alternate fixes:'
        Write-Line '  1. Switch to Google DNS (8.8.8.8 / 8.8.4.4)'
        Write-Line '     Settings > Network & Internet > connection > Properties > Edit DNS'
        Write-Line '     Manual > IPv4: Preferred 8.8.8.8  Alternate 8.8.4.4 > Save'
        Write-Line '     Then run: ipconfig /flushdns'
        Write-Line ''
        Write-Line '  2. Try a VPN - if it works with a VPN, confirmed ISP block'
        Write-Line ''
        Write-Line '  3. Contact your ISP and ask them to whitelist:'
        Write-Line '       Domain:    *.windrose.support (all subdomains)'
        Write-Line '       Port:      3478'
        Write-Line '       Protocols: UDP and TCP'
        $details = if ($detectedCulprit) {
            "ISP blocking detected. Recommended fix: toggle off $($detectedCulprit.Feature) on $($detectedCulprit.Name)."
        } else {
            "ISP blocking detected on $($dnsIssues.Count) endpoint(s). Check ISP app for a security toggle."
        }
        Add-Finding -Status 'FAIL' -Check 'Fleet: Overall' -Details $details
    } elseif ($anyIpv6Issue) {
        Write-Line '*** IPv6 PRIORITIZATION ISSUE ***'
        Write-Line 'Your system prefers IPv6 for Windrose domains, but the game is IPv4-only.'
        Write-Line 'FIX (run as admin):'
        Write-Line '  reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" /v DisabledComponents /t REG_DWORD /d 32 /f'
        Write-Line 'Then restart the PC. To revert later use /d 0 instead of /d 32.'
        Add-Finding -Status 'FAIL' -Check 'Fleet: Overall' -Details 'IPv6 prioritization issue. Game is IPv4-only. See Fleet check section for fix.'
    } elseif ($reachable -gt 0 -and $unreachable -gt 0) {
        Write-Line 'PARTIAL REACHABILITY: Some Windrose services are reachable, others are not.'
        Write-Line ''
        if ($detectedCulprit) {
            Write-Line ('*** LIKELY CAUSE (based on your ISP): {0} ***' -f $detectedCulprit.Name)
            Write-Line ("  Toggle OFF: {0}" -f $detectedCulprit.Feature)
            Write-Line ("  Where:      {0}" -f $detectedCulprit.Toggle)
            Write-Line ''
        }
        Write-Line 'If TCP 3478 is the one failing, that is P2P signaling. Almost always ISP security.'
        Write-Line 'Dedicated server hosts do NOT have this problem - the block is on your end.'
        $details = if ($detectedCulprit) {
            "Partial outage: $reachable/$($script:WindroseServiceEndpoints.Count) reachable. Fix: toggle off $($detectedCulprit.Feature) on $($detectedCulprit.Name)."
        } else {
            "Partial outage: $reachable/$($script:WindroseServiceEndpoints.Count) reachable. Likely ISP security or regional backend issue."
        }
        Add-Finding -Status 'WARN' -Check 'Fleet: Overall' -Details $details
    } else {
        Write-Line 'All Windrose endpoints are unreachable. Check playwindrose.com and the'
        Write-Line 'official Discord for outage announcements.'
        Add-Finding -Status 'FAIL' -Check 'Fleet: Overall' -Details "All $($script:WindroseServiceEndpoints.Count) Windrose services unreachable."
    }

    Write-FleetDiagnosisSummary `
        -Reachable               $reachable `
        -Unreachable             $unreachable `
        -AnyDnsSpoof:            $anyDnsSpoof `
        -AnyIspBlock:            $anyIspBlock `
        -AnyIpv6Issue:           $anyIpv6Issue `
        -HasPartialReachability: ($reachable -gt 0 -and $unreachable -gt 0) `
        -Stun3478Reachable:      $stun3478Reachable `
        -DetectedCulprit         $detectedCulprit

    if ($reachable -lt $script:WindroseServiceEndpoints.Count) {
        Show-KnownIspTable
    }
}

# -------------------------------------------------------------------------------
# Firewall
# -------------------------------------------------------------------------------
function Check-LocalFirewallRules {
    Write-Section 'Watch posts (firewall profiles)'
    foreach ($p in (Get-NetFirewallProfile)) {
        Write-Line ("{0}: Enabled={1} Inbound={2} Outbound={3}" -f $p.Name, $p.Enabled, $p.DefaultInboundAction, $p.DefaultOutboundAction)
    }

    $rules = Get-NetFirewallApplicationFilter |
        Where-Object { $_.Program -match 'Steam|Windrose|R5' } |
        Select-Object -First 20

    Write-Section 'Passwords at the gate (Steam/Windrose firewall rules)'
    if ($rules) {
        foreach ($r in $rules) { Write-Line ($r | Out-String).TrimEnd() }
        Add-Finding -Status 'PASS' -Check 'Firewall app rules' -Details 'Found Steam or Windrose firewall filters.'
    } else {
        Write-Line 'No matching Steam/Windrose application filters found.'
        Write-Line 'If the game was never allowed through the firewall, Windows may be silently blocking it.'
        Add-Finding -Status 'WARN' -Check 'Firewall app rules' -Details 'No Steam/Windrose firewall filters found. Game may not have been allowed through Windows Firewall.'
    }
}

# -------------------------------------------------------------------------------
# Game install detection
# -------------------------------------------------------------------------------
function Get-SteamInstallPath {
    $regPaths = @(
        'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam'
        'HKLM:\SOFTWARE\Valve\Steam'
        'HKCU:\SOFTWARE\Valve\Steam'
    )
    foreach ($reg in $regPaths) {
        try {
            $p = (Get-ItemProperty -Path $reg -Name 'InstallPath' -ErrorAction Stop).InstallPath
            if ($p -and (Test-Path $p)) { return $p }
            $p = (Get-ItemProperty -Path $reg -Name 'SteamPath' -ErrorAction Stop).SteamPath
            if ($p -and (Test-Path $p)) { return $p -replace '/', '\' }
        } catch { continue }
    }
    return $null
}

function Get-SteamLibraries {
    $libs = New-Object System.Collections.Generic.List[string]

    $vdfCandidates = New-Object System.Collections.Generic.List[string]
    [void]$vdfCandidates.Add("$env:ProgramFiles(x86)\Steam\steamapps\libraryfolders.vdf")
    [void]$vdfCandidates.Add("$env:ProgramFiles\Steam\steamapps\libraryfolders.vdf")
    [void]$vdfCandidates.Add("C:\Steam\steamapps\libraryfolders.vdf")

    $steamRoot = Get-SteamInstallPath
    if ($steamRoot) {
        [void]$vdfCandidates.Add((Join-Path $steamRoot 'steamapps\libraryfolders.vdf'))
        [void]$libs.Add($steamRoot)
    }

    foreach ($vdf in ($vdfCandidates | Select-Object -Unique)) {
        if (Test-Path $vdf) {
            try {
                $content = Get-Content $vdf -Raw -ErrorAction Stop
                $ms      = [regex]::Matches($content, '"path"\s+"([^"]+)"')
                foreach ($m in $ms) { [void]$libs.Add(($m.Groups[1].Value -replace '\\\\', '\')) }
            } catch { }
        }
    }

    # Brute-force scan fixed drives for common Steam library folder names
    try {
        $drives = Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue |
            Where-Object { $_.Free -gt 0 -and $_.Root -match '^[A-Z]:\\$' }
        foreach ($d in $drives) {
            foreach ($c in @(
                (Join-Path $d.Root 'SteamLibrary'),
                (Join-Path $d.Root 'Steam'),
                (Join-Path $d.Root 'Games\SteamLibrary'),
                (Join-Path $d.Root 'Games\Steam')
            )) {
                if (Test-Path $c) { [void]$libs.Add($c) }
            }
        }
    } catch { }

    return ($libs | Select-Object -Unique)
}

function Find-WindroseInstall {
    if ($null -ne $script:WindroseInstallCache) { return ,@($script:WindroseInstallCache) }

    $candidates = New-Object System.Collections.Generic.List[string]
    $addPath = {
        param($p)
        if ([string]::IsNullOrWhiteSpace($p)) { return }
        try {
            $normalized = try {
                (Resolve-Path -LiteralPath $p -ErrorAction Stop).Path
            } catch {
                $p.ToString().TrimEnd('\').Trim()
            }
            if (-not [string]::IsNullOrWhiteSpace($normalized) -and $normalized -match ':\\') {
                $candidates.Add($normalized)
            }
        } catch { }
    }

    foreach ($lib in (Get-SteamLibraries)) {
        $c1 = Join-Path $lib 'steamapps\common\Windrose'
        $c2 = Join-Path $lib 'common\Windrose'
        if (Test-Path $c1) { & $addPath $c1 }
        if (Test-Path $c2) { & $addPath $c2 }
    }

    foreach ($p in @(
        'C:\Steam\steamapps\common\Windrose'
        'C:\Program Files (x86)\Steam\steamapps\common\Windrose'
        "$env:ProgramFiles(x86)\Steam\steamapps\common\Windrose"
        "$env:ProgramFiles\Steam\steamapps\common\Windrose"
    )) {
        if ($p -and (Test-Path $p)) { & $addPath $p }
    }

    # Last resort: scan firewall rules for an already-known Windrose.exe path
    try {
        $firewallPath = Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue |
            Where-Object { $_.Program -match '\\Windrose\\.*Windrose\.exe$' -or $_.Program -match '\\Windrose\\.*R5.*\.exe$' } |
            Select-Object -ExpandProperty Program -First 1
        if ($firewallPath) {
            $installDir = Split-Path $firewallPath -Parent
            while ($installDir -and (Split-Path $installDir -Leaf) -ne 'Windrose') {
                $parent = Split-Path $installDir -Parent
                if ($parent -eq $installDir) { $installDir = $null; break }
                $installDir = $parent
            }
            if ($installDir -and (Test-Path $installDir)) { & $addPath $installDir }
        }
    } catch { }

    $seen   = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    $unique = New-Object System.Collections.Generic.List[string]
    foreach ($c in $candidates) { if ($seen.Add($c)) { $unique.Add($c) } }

    $result = @($unique.ToArray())
    $script:WindroseInstallCache = $result
    return $result
}

function Get-GameVersionInfo {
    $installs = @(Find-WindroseInstall)
    Write-Section 'Shipyard (Windrose installs)'

    if (-not $installs -or $installs.Count -eq 0) {
        Write-Line 'No install path auto-detected.'
        Add-Finding -Status 'WARN' -Check 'Game install' -Details 'Windrose install not auto-detected.'
        return @()
    }

    foreach ($i in $installs) { Write-Line ([string]$i) }

    foreach ($install in $installs) {
        $installStr    = [string]$install
        $exeCandidates = Get-ChildItem -Path $installStr -Recurse -Include *.exe -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'Windrose|R5' } |
            Select-Object -First 5

        if ($exeCandidates) {
            Write-Section "Version info in $installStr"
            foreach ($exe in $exeCandidates) {
                Write-Line ("{0} | {1}" -f $exe.FullName, $exe.VersionInfo.FileVersion)
            }
            Add-Finding -Status 'PASS' -Check 'Game install' -Details "Install and version detected in $installStr."
        } else {
            Add-Finding -Status 'WARN' -Check 'Game version' -Details "Install found at $installStr but no Windrose/R5 exe detected."
        }
    }

    return $installs
}

# -------------------------------------------------------------------------------
# Crash logs
# -------------------------------------------------------------------------------
function Check-RecentCrashLogs {
    Write-Section 'Man overboard (recent crash logs)'
    $events = Get-WinEvent -LogName Application -MaxEvents 250 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.LevelDisplayName -in @('Error', 'Critical') -and (
                $_.ProviderName -match 'Application Error|Windows Error Reporting|Steam|Windrose' -or
                $_.Message      -match 'Windrose|R5|steam'
            )
        } |
        Select-Object -First 25 TimeCreated, ProviderName, Id, LevelDisplayName, Message

    if ($events) {
        foreach ($e in $events) { Write-Line ($e | Format-List | Out-String).TrimEnd() }
        Add-Finding -Status 'WARN' -Check 'Recent crashes' -Details 'Recent related application errors found in Windows Event Log - review report.'
    } else {
        Write-Line 'No recent related application errors found in sampled log.'
        Add-Finding -Status 'PASS' -Check 'Recent crashes' -Details 'No recent related application errors found.'
    }
}

# -------------------------------------------------------------------------------
# Remote target tests (mode 2)
# -------------------------------------------------------------------------------
function Test-DnsResolution {
    param([string]$Target)
    Write-Section 'Charting the course (DNS)'
    try {
        $results   = Resolve-DnsName -Name $Target -ErrorAction Stop
        $addresses = $results | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress -Unique
        if ($addresses) {
            foreach ($a in $addresses) { Write-Line "Resolved: $Target -> $a" }
            Add-Finding -Status 'PASS' -Check 'DNS resolution' -Details "Hostname resolved for $Target."
        } else {
            Write-Line 'No IP addresses returned.'
            Add-Finding -Status 'WARN' -Check 'DNS resolution' -Details "No addresses returned for $Target."
        }
    } catch {
        Write-Line "DNS resolution failed: $($_.Exception.Message)"
        Add-Finding -Status 'FAIL' -Check 'DNS resolution' -Details "DNS resolution failed for $Target."
    }
}

function Test-BasicPing {
    param([string]$Target)
    Write-Section 'Cannon shot (ping)'
    try {
        $pings = Test-Connection -TargetName $Target -Count 4 -ErrorAction Stop
        foreach ($p in $pings) { Write-Line ("Reply from {0} in {1} ms" -f $p.Address, $p.Latency) }
        $avg = [math]::Round((($pings | Measure-Object -Property Latency -Average).Average), 2)
        Add-Finding -Status 'PASS' -Check 'Ping' -Details "Ping succeeded. Average latency: $avg ms."
    } catch {
        Write-Line "Ping failed or was blocked: $($_.Exception.Message)"
        Add-Finding -Status 'WARN' -Check 'Ping' -Details 'Ping failed or ICMP is blocked - not definitive for the game port.'
    }
}

function Run-TraceRoute {
    param([string]$Target)
    if ($SkipTraceRoute) { return }
    Run-CommandCapture -Label "Ship's log (trace route to $Target)" -Command { tracert $Target }
}

# -------------------------------------------------------------------------------
# File collection (salvage)
# -------------------------------------------------------------------------------
function Copy-IfExists {
    param([string]$Source, [string]$Destination)
    if (Test-Path $Source) {
        $destDir = Split-Path $Destination -Parent
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item -Path $Source -Destination $Destination -Force -Recurse
        return $true
    }
    return $false
}

function Collect-GameFiles {
    param([string[]]$Installs)
    if (-not $Installs) { return }

    foreach ($install in $Installs) {
        $safeName  = ($install -replace '[:\\/ ]', '_')
        $destBase  = Join-Path $script:LogsOut $safeName
        New-Item -ItemType Directory -Path $destBase -Force | Out-Null

        $savedPath    = Join-Path $install 'R5\Saved'
        $saveProfiles = Join-Path $savedPath 'SaveProfiles'
        $configPath   = Join-Path $savedPath 'Config'

        Write-Section "Salvage from $install"

        if (Copy-IfExists -Source $saveProfiles -Destination (Join-Path $destBase 'SaveProfiles')) {
            Write-Line 'Recovered SaveProfiles'
        } else {
            Write-Line 'SaveProfiles not found'
        }

        if (Copy-IfExists -Source $configPath -Destination (Join-Path $destBase 'Config')) {
            Write-Line 'Recovered Config'
        } else {
            Write-Line 'Config not found'
        }

        foreach ($jsonName in @('ServerDescription.json', 'WorldDescription.json')) {
            $found = Get-ChildItem -Path $install -Recurse -Filter $jsonName -ErrorAction SilentlyContinue | Select-Object -First 3
            foreach ($f in $found) {
                $dest = Join-Path $destBase ($jsonName -replace '\.json$', "_$($f.Name)")
                Copy-Item $f.FullName $dest -Force
                Write-Line "Recovered $($f.FullName)"
            }
        }

        $logFiles = Get-ChildItem -Path $savedPath -Recurse -Include *.log,*.txt -ErrorAction SilentlyContinue
        if ($logFiles) {
            $logsFolder = Join-Path $destBase 'Logs'
            New-Item -ItemType Directory -Path $logsFolder -Force | Out-Null
            foreach ($log in $logFiles | Select-Object -First 50) {
                Copy-Item $log.FullName (Join-Path $logsFolder $log.Name) -Force
            }
            Write-Line "Recovered $($logFiles.Count) log/text files (up to 50)"
        } else {
            Write-Line 'No log files found under Saved'
        }
    }
}

# -------------------------------------------------------------------------------
# Shipwright mode - dedicated server validation
# -------------------------------------------------------------------------------
function Test-ShipwrightMode {
    param([string[]]$Installs)

    Write-Section 'Shipwright - dedicated server validation'

    foreach ($install in $Installs) {
        Write-Line ("Checking install: {0}" -f $install)
        Write-Line ''

        # --- ServerDescription.json ---
        Write-Section 'ServerDescription.json'
        $sdPath = $null
        foreach ($c in @(
            (Join-Path $install 'ServerDescription.json'),
            (Join-Path $install 'R5\ServerDescription.json')
        )) {
            if (Test-Path $c) { $sdPath = $c; break }
        }
        if (-not $sdPath) {
            $f = Get-ChildItem -Path $install -Recurse -Filter 'ServerDescription.json' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($f) { $sdPath = $f.FullName }
        }

        if ($sdPath) {
            Write-Line ("Path: {0}" -f $sdPath)
            try {
                $sd = Get-Content $sdPath -Raw | ConvertFrom-Json

                $inviteCode = if ($sd.PSObject.Properties.Name -contains 'InviteCode')            { $sd.InviteCode }            else { $null }
                $maxPlayers = if ($sd.PSObject.Properties.Name -contains 'MaxPlayerCount')        { $sd.MaxPlayerCount }        else { $null }
                $serverName = if ($sd.PSObject.Properties.Name -contains 'ServerName')            { $sd.ServerName }            else { $null }
                $isPwProt   = if ($sd.PSObject.Properties.Name -contains 'IsPasswordProtected')   { $sd.IsPasswordProtected }   else { $null }
                $proxyAddr  = if ($sd.PSObject.Properties.Name -contains 'P2pProxyAddress')       { $sd.P2pProxyAddress }       else { $null }

                if ($serverName)         { Write-Line ("ServerName:            {0}" -f $serverName) }
                if ($null -ne $maxPlayers) { Write-Line ("MaxPlayerCount:        {0}" -f $maxPlayers) }
                if ($null -ne $isPwProt)   { Write-Line ("IsPasswordProtected:   {0}" -f $isPwProt) }
                if ($proxyAddr)          { Write-Line ("P2pProxyAddress:       {0}" -f $proxyAddr) }

                if ($inviteCode) {
                    if ($inviteCode.Length -lt 6) {
                        Write-Line ("InviteCode:            {0}  [WARN - must be 6+ characters]" -f $inviteCode)
                        Add-Finding -Status 'WARN' -Check 'ServerDescription: InviteCode' -Details "InviteCode '$inviteCode' is shorter than the required 6 characters."
                    } else {
                        Write-Line ("InviteCode:            {0}  [OK - {1} chars]" -f $inviteCode, $inviteCode.Length)
                        Add-Finding -Status 'PASS' -Check 'ServerDescription: InviteCode' -Details "InviteCode present and meets minimum 6-char requirement."
                    }
                } else {
                    Write-Line 'InviteCode:            [not set]'
                    Add-Finding -Status 'WARN' -Check 'ServerDescription: InviteCode' -Details 'InviteCode not found in ServerDescription.json - players will not be able to connect by invite code.'
                }

                if ($proxyAddr -and $proxyAddr -ne '127.0.0.1') {
                    Write-Line ('P2pProxyAddress is not 127.0.0.1 - only change this if you know what it does.')
                    Add-Finding -Status 'WARN' -Check 'ServerDescription: P2pProxyAddress' -Details "P2pProxyAddress is '$proxyAddr' (expected '127.0.0.1' for most setups)."
                }

                Add-Finding -Status 'PASS' -Check 'ServerDescription.json' -Details "Found and parsed at $sdPath."
            } catch {
                Write-Line ("Failed to parse: {0}" -f $_.Exception.Message)
                Add-Finding -Status 'WARN' -Check 'ServerDescription.json' -Details "File found but could not be parsed as JSON at $sdPath. Check for missing commas, extra braces, or unmatched quotes."
            }
        } else {
            Write-Line 'ServerDescription.json not found in install.'
            Write-Line 'This file is required for the server to be discoverable by invite code.'
            Add-Finding -Status 'WARN' -Check 'ServerDescription.json' -Details "Not found under $install."
        }

        # --- WorldDescription.json ---
        Write-Section 'WorldDescription.json'
        $wdFound = Get-ChildItem -Path $install -Recurse -Filter 'WorldDescription.json' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($wdFound) {
            Write-Line ("Path: {0}" -f $wdFound.FullName)
            Add-Finding -Status 'PASS' -Check 'WorldDescription.json' -Details "Found at $($wdFound.FullName)."
        } else {
            Write-Line 'WorldDescription.json not found - server will use defaults.'
            Add-Finding -Status 'INFO' -Check 'WorldDescription.json' -Details 'Not found. Server will use default world settings.'
        }

        # --- SaveProfiles ---
        Write-Section 'Save profiles'
        $saveProfiles = Join-Path $install 'R5\Saved\SaveProfiles'
        if (Test-Path $saveProfiles) {
            $saves     = Get-ChildItem -Path $saveProfiles -Recurse -ErrorAction SilentlyContinue
            $totalSize = ($saves | Measure-Object -Property Length -Sum).Sum
            Write-Line ("Path:       {0}" -f $saveProfiles)
            Write-Line ("Files:      {0}" -f $saves.Count)
            Write-Line ("Total size: {0} MB" -f [math]::Round($totalSize / 1MB, 2))
            Add-Finding -Status 'PASS' -Check 'SaveProfiles' -Details "Found $($saves.Count) files ($([math]::Round($totalSize/1MB,2)) MB) in SaveProfiles."

            # Expected path for world saves: SaveProfiles\Default\RocksDB\<version>\Worlds\
            $worldsPath = Join-Path $saveProfiles 'Default\RocksDB'
            if (Test-Path $worldsPath) {
                Write-Line ('RocksDB world data found at Default\RocksDB')
            } else {
                Write-Line 'No RocksDB world data found at Default\RocksDB - world may not have been created yet.'
            }
        } else {
            Write-Line "SaveProfiles not found at $saveProfiles"
            Add-Finding -Status 'INFO' -Check 'SaveProfiles' -Details 'No save data found - server may not have been run yet.'
        }

        # --- R5.log ---
        Write-Section 'Server log (last 100 lines)'
        $logPath = Join-Path $install 'R5\Saved\Logs\R5.log'
        if (-not (Test-Path $logPath)) {
            $logFound = Get-ChildItem -Path $install -Recurse -Filter 'R5.log' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($logFound) { $logPath = $logFound.FullName }
        }
        if ($logPath -and (Test-Path $logPath)) {
            Write-Line ("Log: {0}" -f $logPath)
            $lines = Get-Content $logPath -ErrorAction SilentlyContinue
            if ($lines) {
                foreach ($l in ($lines | Select-Object -Last 100)) { Write-Line $l }
            } else {
                Write-Line '[log file is empty]'
            }
            Add-Finding -Status 'PASS' -Check 'Server log' -Details "R5.log found at $logPath."
        } else {
            Write-Line 'R5.log not found - server may not have been started yet.'
            Add-Finding -Status 'INFO' -Check 'Server log' -Details 'R5.log not found. Server may not have been run yet.'
        }
    }

    # --- Dedicated server port checks (localhost listen test) ---
    Write-Section 'Dedicated server ports'
    Write-Line 'Testing whether these ports are currently listening on this machine.'
    Write-Line 'Note: a "not listening" result just means the server process is not running or'
    Write-Line 'not bound to this port yet. Use an external port checker after port-forwarding'
    Write-Line 'to confirm internet-facing reachability.'
    Write-Line ''
    foreach ($pc in @(
        [pscustomobject]@{ Port = 7777;  Protocol = 'UDP/TCP'; Purpose = 'Game traffic (players connect here)' }
        [pscustomobject]@{ Port = 27015; Protocol = 'UDP/TCP'; Purpose = 'Steam query / master server' }
        [pscustomobject]@{ Port = 27036; Protocol = 'UDP/TCP'; Purpose = 'Steam P2P / relay' }
    )) {
        $r     = Test-NetConnection -ComputerName 'localhost' -Port $pc.Port -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        $state = if ($r.TcpTestSucceeded) { 'LISTENING (TCP)' } else { 'not listening (TCP)' }
        Write-Line ("  Port {0,-6} {1,-10} {2,-40} -> {3}" -f $pc.Port, $pc.Protocol, $pc.Purpose, $state)
        Add-Finding -Status (if ($r.TcpTestSucceeded) { 'PASS' } else { 'WARN' }) `
                    -Check  "Server port $($pc.Port)" `
                    -Details "$($pc.Purpose) on localhost -> $state"
    }
}

# -------------------------------------------------------------------------------
# Export summary and redaction
# -------------------------------------------------------------------------------
function Export-Summary {
    Write-Section "Captain's summary"
    foreach ($item in $script:Summary) {
        Write-Line ("[{0}] {1}: {2}" -f $item.Status, $item.Check, $item.Details)
    }

    $summaryCsv = Join-Path $script:RootOut 'Manifest.csv'
    $script:Summary | Export-Csv -Path $summaryCsv -NoTypeInformation -Force

    $md = New-Object System.Text.StringBuilder
    [void]$md.AppendLine("# Windrose Captain's Chest - diagnostic report")
    [void]$md.AppendLine('')
    [void]$md.AppendLine(("- **Logged:** {0}" -f (Get-Date)))
    [void]$md.AppendLine(("- **Ship:** {0}"   -f $env:COMPUTERNAME))
    [void]$md.AppendLine(("- **Captain:** {0}" -f $env:USERNAME))
    [void]$md.AppendLine(("- **Admin:** {0}"  -f (Test-Admin)))
    [void]$md.AppendLine('')
    [void]$md.AppendLine('## Findings')
    [void]$md.AppendLine('')
    [void]$md.AppendLine('| Status | Check | Details |')
    [void]$md.AppendLine('|--------|-------|---------|')
    foreach ($item in $script:Summary) {
        $safeDetails = ($item.Details -replace '\|', '\|')
        [void]$md.AppendLine(("| {0} | {1} | {2} |" -f $item.Status, $item.Check, $safeDetails))
    }
    Set-Content -Path $script:MarkdownFile -Value $md.ToString() -Force

    $zipPath = "$script:RootOut.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path "$script:RootOut\*" -DestinationPath $zipPath -Force

    Write-Section 'Chest sealed'
    Write-Line "Folder:   $script:RootOut"
    Write-Line "Report:   $script:ReportFile"
    Write-Line "Markdown: $script:MarkdownFile"
    Write-Line "Manifest: $summaryCsv"
    Write-Line "Zip:      $zipPath"
}

function New-RedactedReport {
    param([string]$InputPath, [string]$OutputPath)
    if (-not (Test-Path $InputPath)) { return $false }

    $content         = Get-Content $InputPath -Raw
    $hostname        = $env:COMPUTERNAME
    $username        = $env:USERNAME
    $userPathEscaped = [regex]::Escape("C:\Users\$username")
    $userHomeEscaped = [regex]::Escape($env:USERPROFILE)

    if ($hostname) { $content = $content -replace [regex]::Escape($hostname), '<REDACTED_HOSTNAME>' }
    if ($username) { $content = $content -replace [regex]::Escape($username), '<REDACTED_USER>' }
    $content = $content -replace $userHomeEscaped, 'C:\Users\<REDACTED_USER>'
    $content = $content -replace $userPathEscaped, 'C:\Users\<REDACTED_USER>'

    $content = [regex]::Replace($content, '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b', {
        param($m)
        $ip    = $m.Value
        $parts = $ip.Split('.')
        foreach ($p in $parts) { if ([int]$p -gt 255) { return $ip } }
        $o1 = [int]$parts[0]; $o2 = [int]$parts[1]
        if ($o1 -in @(0, 10, 127)) { return $ip }
        if ($o1 -eq 169 -and $o2 -eq 254) { return $ip }
        if ($o1 -eq 172 -and $o2 -ge 16 -and $o2 -le 31) { return $ip }
        if ($o1 -eq 192 -and $o2 -eq 168) { return $ip }
        if ($o1 -ge 224 -or $o1 -eq 255) { return $ip }
        if ($ip -in @('1.1.1.1','1.0.0.1','8.8.8.8','8.8.4.4','9.9.9.9')) { return $ip }
        return '<REDACTED_PUBLIC_IP>'
    })

    $content = [regex]::Replace($content, '\b192\.168\.\d{1,3}\.\d{1,3}\b', {
        param($m); $parts = $m.Value.Split('.')
        if ([int]$parts[3] -in @(0,1,254,255)) { return $m.Value }
        return "192.168.$($parts[2]).<REDACTED_HOST>"
    })

    $content = $content -replace 'DHCPv6 Client DUID[\.\s]*:\s*[\w\-]+',       'DHCPv6 Client DUID . . . . . . . . : <REDACTED_DUID>'
    $content = $content -replace 'DHCPv6 IAID[\.\s]*:\s*\d+',                  'DHCPv6 IAID . . . . . . . . . . . : <REDACTED_IAID>'
    $content = $content -replace '(Lease (?:Obtained|Expires)[\.\s]*:\s*)[A-Za-z]+,\s*[A-Za-z]+\s+\d+,\s*\d+\s+\d+:\d+:\d+\s*[AP]M', '$1<REDACTED_LEASE_TIME>'
    $content = $content -replace '\b([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}\b', '<REDACTED_MAC>'
    $content = $content -replace 'fe80::[0-9a-fA-F:]+', 'fe80::<REDACTED>'
    $content = [regex]::Replace($content, '\b(?:[0-9a-fA-F]{1,4}:){3,7}[0-9a-fA-F]{1,4}\b', {
        param($m); $v = $m.Value
        if ($v -match '^(fe80|::1|::)' -or $v -eq '::1') { return $v }
        return '<REDACTED_IPV6>'
    })
    $content = $content -replace '([A-Z]:\\Users\\)[^\\\s]+', '$1<REDACTED_USER>'

    $banner = @"
===============================================================================
  REDACTED REPORT - safe to share
  Personal data (hostname, username, public IP, MAC, etc.) replaced with
  <REDACTED_*> placeholders. Diagnostic data is preserved.
  Generated: $(Get-Date)
===============================================================================

"@
    if ($OutputPath -match '\.txt$') {
        $content = $banner + $content
    } else {
        $content = $content -replace '(?m)^(# Windrose Captain.*?\r?\n)', "`$1`n> **Redacted for sharing.** Personal data replaced with REDACTED placeholders.`n`n"
    }

    Set-Content -Path $OutputPath -Value $content -Force
    return $true
}

function Invoke-RedactionFlow {
    if ($NoRedactPrompt) { return }

    $shouldCreate = $false
    if ($Redact) {
        $shouldCreate = $true
    } else {
        Write-Host ''
        Write-Host 'Create a redacted version with personal data scrubbed?' -ForegroundColor Green
        Write-Host 'Strips: hostname, username, public IP, MAC addresses, file paths.'
        $answer = Read-Host 'Create redacted copy? (Y/n)'
        if ([string]::IsNullOrWhiteSpace($answer) -or $answer -match '^[Yy]') { $shouldCreate = $true }
    }

    if (-not $shouldCreate) { return }

    $redactedTxt = Join-Path $script:RootOut 'CaptainsLog_REDACTED.txt'
    $redactedMd  = Join-Path $script:RootOut 'CaptainsLog_REDACTED.md'
    $okTxt = New-RedactedReport -InputPath $script:ReportFile   -OutputPath $redactedTxt
    $okMd  = New-RedactedReport -InputPath $script:MarkdownFile -OutputPath $redactedMd

    $zipPath = "$script:RootOut.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path "$script:RootOut\*" -DestinationPath $zipPath -Force

    Write-Section 'Redacted versions created'
    if ($okTxt) { Write-Line "Redacted TXT: $redactedTxt" }
    if ($okMd)  { Write-Line "Redacted MD:  $redactedMd" }
    Write-Line 'Post the REDACTED version (not CaptainsLog.txt) when sharing publicly.'
    Write-Line 'Skim it before posting - no automated scrubber is perfect.'
}

# -------------------------------------------------------------------------------
# Main
# -------------------------------------------------------------------------------
Show-Banner
Initialize-Output

Write-Line "Windrose Captain's Chest - diagnostic report"
Write-Line ("Logged:   {0}" -f (Get-Date))
Write-Line ("Ship:     {0}" -f $env:COMPUTERNAME)
Write-Line ("Captain:  {0}" -f $env:USERNAME)
Write-Line ("Admin:    {0}" -f (Test-Admin))

$selectedMode = Prompt-Mode

# Common to all modes
Get-OsInfo
Get-LocalNetworkSummary
Run-CommandCapture -Label 'IP configuration' -Command { ipconfig /all }
Run-CommandCapture -Label 'Hosts file'       -Command { Get-Content "$env:WINDIR\System32\drivers\etc\hosts" }

switch ($selectedMode) {

    'ConnectionTrouble' {
        Get-PublicIP
        Test-WindroseServices
        Check-LocalFirewallRules
        $installs = Get-GameVersionInfo
        Collect-GameFiles -Installs $installs
        Check-RecentCrashLogs
    }

    'CantReachServer' {
        Get-PublicIP
        Test-WindroseServices
        Check-LocalFirewallRules
        $installs = Get-GameVersionInfo
        Collect-GameFiles -Installs $installs
        Check-RecentCrashLogs

        $target = Prompt-ServerTarget
        if (-not [string]::IsNullOrWhiteSpace($target.IP)) {
            Write-Section ("Sounding: {0}:{1}" -f $target.IP, $target.Port)
            if ($target.IP -match '[A-Za-z]') { Test-DnsResolution -Target $target.IP }
            Test-BasicPing -Target $target.IP

            Write-Section ("Boarding party (TCP port {0})" -f $target.Port)
            $tcpResult = Test-NetConnection -ComputerName $target.IP -Port $target.Port -InformationLevel Detailed -WarningAction SilentlyContinue
            Write-Line ($tcpResult | Out-String).TrimEnd()
            if ($tcpResult.TcpTestSucceeded) {
                Add-Finding -Status 'PASS' -Check "TCP $($target.Port)" -Details "TCP $($target.Port) is reachable on $($target.IP)."
            } else {
                Add-Finding -Status 'FAIL' -Check "TCP $($target.Port)" -Details "TCP $($target.Port) not reachable on $($target.IP). Game may use UDP - not conclusive alone."
            }

            Write-Section 'A word on UDP'
            Write-Line 'PowerShell cannot confirm a UDP port is open the way it can for TCP.'
            Write-Line 'If TCP fails but the game uses UDP, check host-side port forwarding and firewall rules.'
            Add-Finding -Status 'INFO' -Check 'UDP certainty' -Details 'Client-side UDP testing is limited in plain PowerShell.'

            Run-TraceRoute -Target $target.IP
        } else {
            Add-Finding -Status 'INFO' -Check 'Server target' -Details 'No IP or hostname provided for remote test.'
            Write-Line 'No target entered. Remote soundings skipped.'
        }
    }

    'Shipwright' {
        $installs = Get-GameVersionInfo
        if ($installs -and $installs.Count -gt 0) {
            Test-ShipwrightMode -Installs $installs
            Collect-GameFiles   -Installs $installs
        } else {
            Write-Section 'Shipwright aborted'
            Write-Line 'No Windrose install detected. Cannot run Shipwright checks.'
            Write-Line 'Make sure the dedicated server files are installed via Steam or SteamCMD.'
            Add-Finding -Status 'FAIL' -Check 'Shipwright' -Details 'No Windrose install found. Cannot validate server configuration.'
        }
        Check-LocalFirewallRules
        Check-RecentCrashLogs
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
