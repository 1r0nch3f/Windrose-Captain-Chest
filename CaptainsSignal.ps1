<#
.SYNOPSIS
    Captain's Signal - Windrose hosting quick-check and crew invite generator.

.DESCRIPTION
    Lightweight companion to Captain's Chest. Runs in seconds.
    No hardware collection, no salvage, no log scanning.

    Does three things:
      1. Reads your current server config from ServerDescription.json
      2. Snapshots live network connections from Windrose-Win64-Shipping
      3. Generates a ready-to-copy invite message for text, iMessage, or Discord

    Works for both hosting modes:
      - Invite code: reads the code automatically, no copy-paste from in-game
      - Direct IP:   looks up your public IP and includes it with port 7777

    Run while Windrose is open and a session is hosted (loading screen is fine).

.EXAMPLE
    .\CaptainsSignal.ps1
#>

$ErrorActionPreference = 'SilentlyContinue'

# -------------------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------------------

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=== {0} ===" -f $Title) -ForegroundColor Cyan
}

function Write-Ok   { param([string]$Msg) Write-Host ("[PASS] $Msg") -ForegroundColor Green  }
function Write-Warn { param([string]$Msg) Write-Host ("[WARN] $Msg") -ForegroundColor Yellow }
function Write-Fail { param([string]$Msg) Write-Host ("[FAIL] $Msg") -ForegroundColor Red    }
function Write-Info { param([string]$Msg) Write-Host ("[INFO] $Msg") -ForegroundColor Gray   }

function Get-SteamLibraries {
    $libs = New-Object System.Collections.Generic.List[string]
    $regPaths = @(
        'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
        'HKLM:\SOFTWARE\Valve\Steam',
        'HKCU:\SOFTWARE\Valve\Steam'
    )
    foreach ($reg in $regPaths) {
        try {
            $p = (Get-ItemProperty -Path $reg -Name 'InstallPath' -ErrorAction Stop).InstallPath
            if ($p -and (Test-Path $p)) { [void]$libs.Add($p) }
        } catch { }
    }
    try {
        $drives = Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue |
            Where-Object { $_.Free -gt 0 -and $_.Root -match '^[A-Z]:\\$' }
        foreach ($d in $drives) {
            foreach ($candidate in @('SteamLibrary','Steam','Games\SteamLibrary','Games\Steam')) {
                $p = Join-Path $d.Root $candidate
                if (Test-Path $p) { [void]$libs.Add($p) }
            }
        }
    } catch { }
    return ($libs | Select-Object -Unique)
}

function Get-PublicIP {
    $endpoints = @(
        'https://api.ipify.org',
        'https://ifconfig.me/ip',
        'https://icanhazip.com'
    )
    foreach ($url in $endpoints) {
        try {
            $ip = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5).Content.Trim()
            if ($ip -match '^\d{1,3}(\.\d{1,3}){3}$') { return $ip }
        } catch { continue }
    }
    return $null
}

# -------------------------------------------------------------------------------
# Banner
# -------------------------------------------------------------------------------

Write-Host ""
Write-Host "  +-------------------------------------------------+" -ForegroundColor Yellow
Write-Host "  |   Captain's Signal  -  Windrose crew invite     |" -ForegroundColor Yellow
Write-Host "  +-------------------------------------------------+" -ForegroundColor Yellow
Write-Host ""

# -------------------------------------------------------------------------------
# Step 1: Read ServerDescription.json
# -------------------------------------------------------------------------------

Write-Header "Reading server config"

$serverDescJson = $null
$serverDescFile = $null

$candidates = @(
    "$env:ProgramFiles(x86)\Steam\steamapps\common\Windrose\R5\ServerDescription.json",
    "$env:ProgramFiles\Steam\steamapps\common\Windrose\R5\ServerDescription.json"
)
foreach ($lib in (Get-SteamLibraries)) {
    $candidates += (Join-Path $lib 'steamapps\common\Windrose\R5\ServerDescription.json')
}

foreach ($c in ($candidates | Select-Object -Unique)) {
    if (Test-Path $c) {
        try {
            $serverDescJson = Get-Content $c -Raw | ConvertFrom-Json
            $serverDescFile = $c
            break
        } catch { }
    }
}

if (-not $serverDescJson) {
    Write-Warn "ServerDescription.json not found. Is Windrose installed?"
    Write-Host ""
    Write-Host "Searched in:"
    foreach ($c in ($candidates | Select-Object -Unique)) { Write-Host "  $c" }
    Write-Host ""
    Write-Host "Make sure Windrose is installed and you have hosted at least once." -ForegroundColor Yellow
    exit 1
}

$p                = $serverDescJson.ServerDescription_Persistent
$inviteCode       = $p.InviteCode
$serverName       = $p.ServerName
$maxPlayers       = $p.MaxPlayerCount
$isPasswordProt   = $p.IsPasswordProtected
$serverPass       = $p.Password
$isDirectIP       = $p.UseDirectConnection
$directPort       = $p.DirectConnectionServerPort
$region           = $p.UserSelectedRegion
$deploymentId     = $serverDescJson.DeploymentId

Write-Ok  "Config found: $serverDescFile"
Write-Host ""
Write-Host "  Server name:  $serverName"
Write-Host "  Max players:  $maxPlayers"
Write-Host "  Region:       $region"
Write-Host "  Game version: $deploymentId"
Write-Host "  Invite code:  $inviteCode"
Write-Host "  Direct IP:    $isDirectIP  (port $directPort)"
Write-Host "  Password:     $isPasswordProt"

# -------------------------------------------------------------------------------
# Step 2: Live network snapshot
# -------------------------------------------------------------------------------

Write-Header "Live network check"

$wr = Get-Process | Where-Object { $_.Name -match 'Windrose-Win64' } | Select-Object -First 1

if (-not $wr) {
    Write-Warn "Windrose is not running. Network check skipped."
    Write-Info "Start Windrose and host a session for a full network check."
} else {
    Write-Ok "Windrose running: $($wr.Name) PID $($wr.Id)"

    $tcpConns = Get-NetTCPConnection | Where-Object { $_.OwningProcess -eq $wr.Id }
    $udpConns = Get-NetUDPEndpoint   | Where-Object { $_.OwningProcess -eq $wr.Id }

    # Backend connectivity
    $knownBackendIPs = @(
        '3.66.107.109','3.75.35.235','3.36.19.254',
        '3.37.92.160','149.154.64.47'
    )
    $backendHits = $tcpConns | Where-Object {
        $_.RemoteAddress -in $knownBackendIPs -and $_.RemotePort -eq 443
    }
    if ($backendHits) {
        Write-Ok ("Backend: {0} connection service contact(s) detected" -f ($backendHits | Measure-Object).Count)
    } else {
        Write-Warn "Backend: no connection service IPs detected in live TCP snapshot."
        Write-Host "  This is normal if you are not actively on the host screen." -ForegroundColor Gray
    }

    # UDP pool
    $udpExternal  = $udpConns | Where-Object { $_.LocalAddress -eq '0.0.0.0' } | Sort-Object LocalPort
    $udpCount     = ($udpExternal | Measure-Object).Count
    if ($udpCount -ge 10) {
        $udpRange = "$($udpExternal[0].LocalPort)-$($udpExternal[-1].LocalPort)"
        Write-Ok "UDP pool: $udpCount sockets open ($udpRange) - peer connections ready"
    } elseif ($udpCount -gt 0) {
        Write-Warn "UDP pool: only $udpCount sockets open. Expected at least 10."
    } else {
        Write-Warn "UDP pool: no external UDP sockets detected. Host a session first."
    }

    # Port 7777 (Direct IP confirmation)
    $port7777Live = $tcpConns | Where-Object { $_.RemotePort -eq 7777 -or $_.LocalPort -eq 7777 }
    if ($port7777Live) {
        Write-Ok "Port 7777: active - Direct IP mode confirmed live"
    } elseif ($isDirectIP) {
        Write-Warn "Port 7777: not detected live but ServerDescription says Direct IP mode."
        Write-Host "  Session may still be loading." -ForegroundColor Gray
    }

    # Firewall rule
    $fwRule = Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue |
        Where-Object { $_.Program -match 'Windrose|Kraken' }
    if ($fwRule) {
        Write-Ok "Firewall: Windrose application rule present"
    } else {
        Write-Warn "Firewall: no Windrose rule found."
        Write-Host "  If you hit Cancel on the Windows Security prompt, Direct IP hosting may fail." -ForegroundColor Gray
        Write-Host "  Fix: Windows Defender Firewall > Allow an app > add Windrose." -ForegroundColor Gray
    }
}

# -------------------------------------------------------------------------------
# Step 3: Public IP (for Direct IP mode)
# -------------------------------------------------------------------------------

$publicIP = $null
if ($isDirectIP) {
    Write-Header "Looking up public IP"
    $publicIP = Get-PublicIP
    if ($publicIP) {
        Write-Ok "Public IP: $publicIP"
        Write-Host ""
        Write-Host "  *** PUBLIC IP WARNING ***" -ForegroundColor Yellow
        Write-Host "  Your public IP identifies your home internet connection." -ForegroundColor Yellow
        Write-Host "  Only share it with people you trust." -ForegroundColor Yellow
        Write-Host "  Do not post it publicly in Discord servers, forums, or social media." -ForegroundColor Yellow
    } else {
        Write-Warn "Could not determine public IP. Visit https://whatismyip.com to find it."
    }
}

# -------------------------------------------------------------------------------
# Step 4: Generate crew invite messages
# -------------------------------------------------------------------------------

Write-Header "Send to crew"

$serverInfo  = "$serverName (max $maxPlayers)"
$passwordLine = if ($isPasswordProt -and -not [string]::IsNullOrWhiteSpace($serverPass)) {
    "Password: $serverPass"
} else { $null }

if ($isDirectIP -and $publicIP) {

    Write-Host ""
    Write-Host "--- Copy this (text / iMessage / WhatsApp) ---" -ForegroundColor Green
    Write-Host ""
    Write-Host "Hey! Join my Windrose server: $serverInfo"
    Write-Host "Direct IP: $publicIP"
    Write-Host "Port: $directPort"
    if ($passwordLine) { Write-Host $passwordLine }
    Write-Host "In-game: Host a Game > Direct IP tab"
    Write-Host "See you on deck!"
    Write-Host ""
    Write-Host "--- Copy this (Discord) ---" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "**Join my Windrose server - $serverInfo!**"
    Write-Host "In-game: **Host a Game > Direct IP tab**"
    Write-Host "``IP: $publicIP``  ``Port: $directPort``"
    if ($passwordLine) { Write-Host ("``$passwordLine``") }
    Write-Host "See you on deck!"

} elseif (-not $isDirectIP -and -not [string]::IsNullOrWhiteSpace($inviteCode)) {

    Write-Host ""
    Write-Host "--- Copy this (text / iMessage / WhatsApp) ---" -ForegroundColor Green
    Write-Host ""
    Write-Host "Hey! Join my Windrose server: $serverInfo"
    Write-Host "Invite code: $inviteCode"
    if ($passwordLine) { Write-Host $passwordLine }
    Write-Host "In-game: Join a Game > Enter Code"
    Write-Host "See you on deck!"
    Write-Host ""
    Write-Host "--- Copy this (Discord) ---" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "**Join my Windrose server - $serverInfo!**"
    Write-Host "Go to **Join a Game > Enter Code** and use:"
    Write-Host "``$inviteCode``"
    if ($passwordLine) { Write-Host ("``$passwordLine``") }
    Write-Host "See you on deck!"

} elseif ($isDirectIP -and -not $publicIP) {

    Write-Host ""
    Write-Host "Direct IP mode but public IP lookup failed." -ForegroundColor Yellow
    Write-Host "Find your IP at https://whatismyip.com then share:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "--- Copy this (text / iMessage / WhatsApp) ---" -ForegroundColor Green
    Write-Host ""
    Write-Host "Hey! Join my Windrose server: $serverInfo"
    Write-Host "Direct IP: [your IP from whatismyip.com]"
    Write-Host "Port: $directPort"
    if ($passwordLine) { Write-Host $passwordLine }
    Write-Host "In-game: Host a Game > Direct IP tab"
    Write-Host "See you on deck!"

} else {

    Write-Warn "Could not generate invite. No invite code found and not in Direct IP mode."
    Write-Host "Make sure Windrose is running and you have started hosting a session." -ForegroundColor Gray

}

Write-Host ""
Write-Host "Fair winds, Captain." -ForegroundColor Yellow
Write-Host ""
