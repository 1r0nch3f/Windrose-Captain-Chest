<#
.SYNOPSIS
    Captain's Chest - a diagnostic toolkit for Windrose crews.

.DESCRIPTION
    Gather ye logs, charts, and soundings into one tidy chest. Produces a
    single pasteable report covering:

      - Ship's papers:  OS, CPU, RAM, GPU (with driver age check)
      - Soundings:      Network adapters, local IP, public IP
      - Hold inventory: Windrose install detection and executable versions
      - Watch posts:    Firewall profile and Steam/Windrose rules
      - Crew roster:    Steam and Windrose process state
      - Log book:       Recent application and system errors
      - Spyglass:       Optional server reachability (DNS, ping, TCP, trace)
      - Salvage:        Collected Config/SaveProfiles/ServerDescription/logs

    Outputs to a timestamped chest on yer Desktop:
      - CaptainsLog.txt       - full human-readable report
      - CaptainsLog.md        - pasteable markdown for Discord/forum
      - Manifest.csv          - pass/warn/fail findings
      - Salvage/              - collected game files
      - Chest_<timestamp>.zip - the whole chest, sealed for transport

.PARAMETER OutputPath
    Root folder for the chest. Default: Desktop\WindroseCaptainChest

.PARAMETER ServerIP
    Optional server IP or hostname to sound out.

.PARAMETER ServerPort
    Port to test. Default: 7777.

.PARAMETER Mode
    Full | Quick | LocalOnly. Default prompts interactively.

.PARAMETER SkipTraceRoute
    Skip the tracert step (saves ~30 seconds).

.PARAMETER SkipNetworkTests
    Skip all remote tests including public IP lookup.

.PARAMETER NoPause
    Don't wait for a key press at the end. Useful for automation.

.EXAMPLE
    .\CaptainsChest.ps1
    .\CaptainsChest.ps1 -ServerIP 1.2.3.4 -ServerPort 7777 -Mode Full -NoPause
#>

param(
    [string]$OutputPath = "$env:USERPROFILE\Desktop\WindroseCaptainChest",
    [string]$ServerIP = "",
    [int]$ServerPort = 7777,
    [ValidateSet('Full','Quick','LocalOnly','')]
    [string]$Mode = '',
    [switch]$SkipTraceRoute,
    [switch]$SkipNetworkTests,
    [switch]$NoPause
)

$ErrorActionPreference = 'SilentlyContinue'
Set-StrictMode -Version Latest

# --- Port presets (edit here if the charts change) -----------------------------
$script:WindrosePortPresets = @(
    [pscustomobject]@{ Port = 7777;  Protocol = 'UDP/TCP'; Purpose = 'Default game port' }
    [pscustomobject]@{ Port = 7778;  Protocol = 'UDP';     Purpose = 'Secondary game port' }
    [pscustomobject]@{ Port = 27015; Protocol = 'UDP/TCP'; Purpose = 'Steam query / master' }
    [pscustomobject]@{ Port = 27036; Protocol = 'UDP/TCP'; Purpose = 'Steam streaming / P2P' }
)

$script:RootOut      = $null
$script:LogsOut      = $null
$script:ReportFile   = $null
$script:MarkdownFile = $null
$script:Summary      = New-Object System.Collections.Generic.List[object]

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
    param(
        [string]$Label,
        [scriptblock]$Command
    )
    Write-Section $Label
    try {
        $result = & $Command 2>&1 | Out-String
        if ([string]::IsNullOrWhiteSpace($result)) { $result = '[no output]' }
        Write-Line $result.TrimEnd()
    }
    catch {
        Write-Line "[error] $($_.Exception.Message)"
    }
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# -------------------------------------------------------------------------------
# Prompts
# -------------------------------------------------------------------------------

function Prompt-Menu {
    if ($Mode) { return $Mode }
    Write-Host ''
    Write-Host 'Chart yer course, Captain:' -ForegroundColor Green
    Write-Host '  1. Full voyage  - ship, shore, and sound out a distant port'
    Write-Host '  2. Quick sweep  - ship info and a quick port test'
    Write-Host '  3. Stay ashore  - ship and shore only, no remote soundings'
    Write-Host ''
    $choice = Read-Host 'Yer choice (1-3) [default 1]'
    switch ($choice) {
        '2' { return 'Quick' }
        '3' { return 'LocalOnly' }
        default { return 'Full' }
    }
}

function Prompt-ServerTarget {
    $targetIP   = $ServerIP
    $targetPort = $ServerPort

    if ([string]::IsNullOrWhiteSpace($targetIP)) {
        $targetIP = Read-Host "Name the port to sound (IP or hostname)"
    }

    $portInput = Read-Host "Port number, or press Enter for $targetPort"
    if (-not [string]::IsNullOrWhiteSpace($portInput)) {
        $parsed = 0
        if ([int]::TryParse($portInput, [ref]$parsed)) { $targetPort = $parsed }
    }

    return [pscustomobject]@{
        IP   = $targetIP.Trim()
        Port = $targetPort
    }
}

# -------------------------------------------------------------------------------
# Ship's papers
# -------------------------------------------------------------------------------

function Get-OsInfo {
    Run-CommandCapture -Label "Ship's papers (OS)" -Command {
        Get-ComputerInfo |
            Select-Object WindowsProductName, WindowsVersion, OsBuildNumber, OsArchitecture, CsName |
            Format-List
    }
}

function Get-CpuAndMemory {
    Run-CommandCapture -Label 'Engine room (CPU and memory)' -Command {
        Get-CimInstance Win32_Processor |
            Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed |
            Format-List
        Get-CimInstance Win32_ComputerSystem |
            Select-Object @{N='TotalPhysicalMemoryGB';E={[math]::Round($_.TotalPhysicalMemory/1GB,2)}} |
            Format-List
    }
}

function Get-GpuInfoWithDriverAge {
    Write-Section 'Crow''s nest (GPU)'
    $gpus = Get-CimInstance Win32_VideoController
    if (-not $gpus) {
        Write-Line 'No GPUs sighted.'
        Add-Finding -Status 'WARN' -Check 'GPU' -Details 'No video controllers were enumerated.'
        return
    }

    foreach ($gpu in $gpus) {
        $driverDate = $null
        try {
            if ($gpu.DriverDate) {
                $driverDate = [Management.ManagementDateTimeConverter]::ToDateTime($gpu.DriverDate)
            }
        } catch { }

        $ramGB = if ($gpu.AdapterRAM) { [math]::Round($gpu.AdapterRAM / 1GB, 2) } else { 'unknown' }

        Write-Line ("Name:           {0}" -f $gpu.Name)
        Write-Line ("Driver Version: {0}" -f $gpu.DriverVersion)
        if ($driverDate) {
            $age = (Get-Date) - $driverDate
            Write-Line ("Driver Date:    {0:yyyy-MM-dd} ({1} days old)" -f $driverDate, [int]$age.TotalDays)
            if ($age.TotalDays -gt 365) {
                Add-Finding -Status 'WARN' -Check 'GPU driver age' -Details ("{0} driver is {1} days old - consider updating." -f $gpu.Name, [int]$age.TotalDays)
            } elseif ($age.TotalDays -gt 180) {
                Add-Finding -Status 'INFO' -Check 'GPU driver age' -Details ("{0} driver is {1} days old." -f $gpu.Name, [int]$age.TotalDays)
            } else {
                Add-Finding -Status 'PASS' -Check 'GPU driver age' -Details ("{0} driver is fresh ({1} days old)." -f $gpu.Name, [int]$age.TotalDays)
            }
        } else {
            Write-Line 'Driver Date:    unknown'
            Add-Finding -Status 'INFO' -Check 'GPU driver age' -Details ("{0} driver date could not be determined." -f $gpu.Name)
        }
        Write-Line ("VRAM (GB):      {0}" -f $ramGB)
        Write-Line ''
    }
}

# -------------------------------------------------------------------------------
# Soundings (network)
# -------------------------------------------------------------------------------

function Get-LocalNetworkSummary {
    Write-Section 'Home waters (local network)'

    $profiles = Get-NetConnectionProfile
    foreach ($p in $profiles) {
        Write-Line ("Network: {0} | Category: {1} | IPv4: {2} | IPv6: {3}" -f $p.Name, $p.NetworkCategory, $p.IPv4Connectivity, $p.IPv6Connectivity)
        if ($p.NetworkCategory -eq 'Public') {
            Add-Finding -Status 'WARN' -Check 'Network profile' -Details ("Adapter profile '{0}' is Public - firewall may be stricter." -f $p.Name)
        }
    }

    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    foreach ($a in $adapters) {
        Write-Line ("Adapter up: {0} | {1} | {2}" -f $a.Name, $a.InterfaceDescription, $a.LinkSpeed)
    }
}

function Get-PublicIP {
    if ($SkipNetworkTests) { return }
    Write-Section 'Flag on the mast (public IP)'

    $endpoints = @(
        'https://api.ipify.org',
        'https://ifconfig.me/ip',
        'https://icanhazip.com'
    )

    $publicIP = $null
    foreach ($url in $endpoints) {
        try {
            $publicIP = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5).Content.Trim()
            if ($publicIP -match '^\d{1,3}(\.\d{1,3}){3}$') {
                Write-Line ("Public IP: {0}  (source: {1})" -f $publicIP, $url)
                Add-Finding -Status 'PASS' -Check 'Public IP' -Details "Public IP resolved: $publicIP"
                break
            } else {
                $publicIP = $null
            }
        } catch { continue }
    }

    if (-not $publicIP) {
        Write-Line 'Could not determine public IP from any endpoint.'
        Add-Finding -Status 'WARN' -Check 'Public IP' -Details 'Public IP lookup failed on all endpoints.'
    }
}

function Test-DnsResolution {
    param([string]$Target)
    Write-Section 'Charting the course (DNS)'
    try {
        $results = Resolve-DnsName -Name $Target -ErrorAction Stop
        $addresses = $results | Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress -Unique
        if ($addresses) {
            foreach ($a in $addresses) { Write-Line "Resolved: $Target -> $a" }
            Add-Finding -Status 'PASS' -Check 'DNS resolution' -Details "Hostname resolved for $Target."
        } else {
            Write-Line 'No IP addresses returned.'
            Add-Finding -Status 'WARN' -Check 'DNS resolution' -Details "No addresses for $Target."
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
        foreach ($p in $pings) {
            Write-Line ("Reply from {0} in {1} ms" -f $p.Address, $p.Latency)
        }
        $avg = [math]::Round((($pings | Measure-Object -Property Latency -Average).Average), 2)
        Add-Finding -Status 'PASS' -Check 'Ping' -Details "Ping succeeded. Average latency: $avg ms."
    } catch {
        Write-Line "Ping failed or was blocked: $($_.Exception.Message)"
        Add-Finding -Status 'WARN' -Check 'Ping' -Details 'Ping failed or ICMP is blocked - not definitive for the game port.'
    }
}

function Test-TcpPort {
    param([string]$Target, [int]$Port)
    Write-Section "Boarding party (TCP port $Port)"
    $result = Test-NetConnection -ComputerName $Target -Port $Port -InformationLevel Detailed
    $result | Out-String | ForEach-Object { Write-Line $_.TrimEnd() }

    if ($result.TcpTestSucceeded) {
        Add-Finding -Status 'PASS' -Check "TCP $Port" -Details "TCP $Port is reachable on $Target."
    } else {
        Add-Finding -Status 'FAIL' -Check "TCP $Port" -Details "TCP $Port not reachable on $Target. Game may use UDP - inconclusive alone."
    }
}

function Test-UdpPortLight {
    Write-Section "A word on UDP"
    Write-Line 'PowerShell cannot positively prove a UDP game port is open the way it can for TCP.'
    Write-Line 'If TCP fails but the game uses UDP, compare with host-side port forwarding and firewall rules.'
    Add-Finding -Status 'INFO' -Check 'UDP certainty' -Details 'Client-side UDP testing is limited in plain PowerShell.'
}

function Test-WindrosePortPresets {
    param([string]$Target)
    Write-Section 'Sounding the harbor (port presets)'
    Write-Line 'Testing common Windrose / Steam ports against the target:'
    foreach ($preset in $script:WindrosePortPresets) {
        $r = Test-NetConnection -ComputerName $Target -Port $preset.Port -WarningAction SilentlyContinue
        $state = if ($r.TcpTestSucceeded) { 'OPEN (TCP)' } else { 'closed/filtered (TCP)' }
        Write-Line ("  Port {0,-6} {1,-10} {2,-35} -> {3}" -f $preset.Port, $preset.Protocol, $preset.Purpose, $state)
        if ($preset.Protocol -match 'TCP') {
            $status = if ($r.TcpTestSucceeded) { 'PASS' } else { 'WARN' }
            Add-Finding -Status $status -Check ("Preset port {0}" -f $preset.Port) -Details ("{0} ({1}) -> {2}" -f $preset.Purpose, $preset.Protocol, $state)
        }
    }
    Write-Line ''
    Write-Line 'Note: UDP results cannot be confirmed from the client side. "closed/filtered" on a UDP-only port is not conclusive.'
}

function Run-TraceRoute {
    param([string]$Target)
    if ($SkipTraceRoute) { return }
    Run-CommandCapture -Label 'Ship''s log (trace route)' -Command { tracert $Target }
}

function Get-BaselineConnectivity {
    if ($SkipNetworkTests) { return }
    Run-CommandCapture -Label 'Steam harbor reachable?' -Command {
        Test-NetConnection store.steampowered.com -Port 443
    }
    Run-CommandCapture -Label 'Cloudflare beacon (1.1.1.1:53)' -Command {
        Test-NetConnection 1.1.1.1 -Port 53
    }
    Run-CommandCapture -Label 'Google beacon (8.8.8.8:53)' -Command {
        Test-NetConnection 8.8.8.8 -Port 53
    }
}

# -------------------------------------------------------------------------------
# Hold inventory / watch posts / crew
# -------------------------------------------------------------------------------

function Get-WindrosePaths {
    $paths = @()
    $common = @(
        'C:\Steam\steamapps\common\Windrose',
        'C:\Program Files (x86)\Steam\steamapps\common\Windrose',
        "$env:ProgramFiles(x86)\Steam\steamapps\common\Windrose",
        "$env:ProgramFiles\Steam\steamapps\common\Windrose"
    )
    foreach ($p in $common) {
        if ($p -and (Test-Path $p)) { $paths += $p }
    }
    return $paths | Select-Object -Unique
}

function Get-SteamLibraries {
    $libs = @()
    $vdfPaths = @(
        "$env:ProgramFiles(x86)\Steam\steamapps\libraryfolders.vdf",
        "$env:ProgramFiles\Steam\steamapps\libraryfolders.vdf"
    )
    foreach ($vdf in $vdfPaths) {
        if (Test-Path $vdf) {
            $content = Get-Content $vdf -Raw
            $ms = [regex]::Matches($content, '"path"\s+"([^"]+)"')
            foreach ($m in $ms) {
                $libs += ($m.Groups[1].Value -replace '\\\\', '\')
            }
        }
    }
    return $libs | Select-Object -Unique
}

function Find-WindroseInstall {
    $candidates = Get-WindrosePaths
    $libs = Get-SteamLibraries
    foreach ($lib in $libs) {
        $c = Join-Path $lib 'steamapps\common\Windrose'
        if (Test-Path $c) { $candidates += $c }
    }
    return $candidates | Select-Object -Unique
}

function Copy-IfExists {
    param([string]$Source, [string]$Destination)
    if (Test-Path $Source) {
        $destDir = Split-Path $Destination -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Copy-Item -Path $Source -Destination $Destination -Force -Recurse
        return $true
    }
    return $false
}

function Get-GameVersionInfo {
    $installs = Find-WindroseInstall
    Write-Section 'Shipyard (Windrose installs)'
    if (-not $installs -or $installs.Count -eq 0) {
        Write-Line 'No install path auto-detected.'
        Add-Finding -Status 'WARN' -Check 'Game install' -Details 'Windrose install not auto-detected.'
        return @()
    }

    foreach ($i in $installs) { Write-Line $i }

    foreach ($install in $installs) {
        $exeCandidates = Get-ChildItem -Path $install -Recurse -Include *.exe -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'Windrose|R5' } |
            Select-Object -First 5

        if ($exeCandidates) {
            Write-Section "Hull markings in $install"
            foreach ($exe in $exeCandidates) {
                Write-Line ("{0} | {1}" -f $exe.FullName, $exe.VersionInfo.FileVersion)
            }
            Add-Finding -Status 'PASS' -Check 'Game install' -Details "Install and version info detected in $install."
        } else {
            Add-Finding -Status 'WARN' -Check 'Game version' -Details "Install found at $install but no Windrose/R5 exe detected."
        }
    }

    return $installs
}

function Collect-GameFiles {
    param([string[]]$Installs)
    if (-not $Installs) { return }

    foreach ($install in $Installs) {
        $safeName = ($install -replace '[:\\/ ]', '_')
        $destBase = Join-Path $script:LogsOut $safeName
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

        $serverDesc = Get-ChildItem -Path $install -Recurse -Filter 'ServerDescription.json' -ErrorAction SilentlyContinue | Select-Object -First 3
        if ($serverDesc) {
            foreach ($f in $serverDesc) {
                $dest = Join-Path $destBase ("ServerDescription_" + $f.Name)
                Copy-Item $f.FullName $dest -Force
                Write-Line "Recovered $($f.FullName)"
            }
        } else {
            Write-Line 'ServerDescription.json not found'
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
        Write-Line 'No matching Steam/Windrose application filters were found.'
        Add-Finding -Status 'WARN' -Check 'Firewall app rules' -Details 'No Steam/Windrose firewall filters found.'
    }
}

function Check-SteamAndProcesses {
    Write-Section 'Crew roster (running processes)'
    $procs = Get-Process |
        Where-Object { $_.ProcessName -match 'steam|Windrose|R5' } |
        Select-Object ProcessName, Id, StartTime, Path
    if ($procs) {
        foreach ($pr in $procs) { Write-Line ($pr | Format-List | Out-String).TrimEnd() }
        Add-Finding -Status 'PASS' -Check 'Processes' -Details 'Steam and/or Windrose processes detected.'
    } else {
        Write-Line 'No Steam or Windrose processes are currently running.'
        Add-Finding -Status 'INFO' -Check 'Processes' -Details 'Steam and Windrose not running right now.'
    }
}

function Check-RecentErrors {
    Write-Section 'Man overboard (recent errors)'
    $events = Get-WinEvent -LogName Application -MaxEvents 250 |
        Where-Object {
            $_.LevelDisplayName -in @('Error','Critical') -and (
                $_.ProviderName -match 'Application Error|Windows Error Reporting|Steam|Windrose' -or
                $_.Message -match 'Windrose|R5|steam'
            )
        } |
        Select-Object -First 25 TimeCreated, ProviderName, Id, LevelDisplayName, Message

    if ($events) {
        foreach ($e in $events) { Write-Line ($e | Format-List | Out-String).TrimEnd() }
        Add-Finding -Status 'WARN' -Check 'Recent crashes/errors' -Details 'Recent related application errors found - review report.'
    } else {
        Write-Line 'No recent related application errors found in sampled log.'
        Add-Finding -Status 'PASS' -Check 'Recent crashes/errors' -Details 'No recent related application errors found.'
    }
}

function Check-VCRuntimes {
    Run-CommandCapture -Label 'Powder magazine (VC++ runtimes)' -Command {
        Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall' |
            Get-ItemProperty |
            Where-Object { $_.DisplayName -match 'Visual C\+\+' } |
            Sort-Object DisplayName |
            Select-Object DisplayName, DisplayVersion, Publisher |
            Format-Table -Auto
    }
}

# -------------------------------------------------------------------------------
# Export
# -------------------------------------------------------------------------------

function Export-Summary {
    Write-Section "Captain's summary"
    foreach ($item in $script:Summary) {
        Write-Line ("[{0}] {1}: {2}" -f $item.Status, $item.Check, $item.Details)
    }

    $summaryCsv = Join-Path $script:RootOut 'Manifest.csv'
    $script:Summary | Export-Csv -Path $summaryCsv -NoTypeInformation -Force

    # Markdown version for Discord/forum pasting
    $md = New-Object System.Text.StringBuilder
    [void]$md.AppendLine('# Windrose Captain''s Chest - diagnostic report')
    [void]$md.AppendLine('')
    [void]$md.AppendLine(("- **Logged:** {0}" -f (Get-Date)))
    [void]$md.AppendLine(("- **Ship:** {0}" -f $env:COMPUTERNAME))
    [void]$md.AppendLine(("- **Captain:** {0}" -f $env:USERNAME))
    [void]$md.AppendLine(("- **Admin:** {0}" -f (Test-Admin)))
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

$selectedMode = Prompt-Menu

# Always-run local collection
Get-OsInfo
Get-CpuAndMemory
Get-GpuInfoWithDriverAge
Get-LocalNetworkSummary
Run-CommandCapture -Label 'Rigging (network adapters)' -Command {
    Get-NetAdapter | Sort-Object Status, Name |
        Format-Table -Auto Name, InterfaceDescription, Status, LinkSpeed, MacAddress
}
Run-CommandCapture -Label 'IP configuration' -Command { ipconfig /all }
Run-CommandCapture -Label 'Route table'      -Command { route print }

Get-PublicIP

Check-SteamAndProcesses
$installs = Get-GameVersionInfo
Collect-GameFiles -Installs $installs
Check-LocalFirewallRules
Check-RecentErrors
Check-VCRuntimes

Run-CommandCapture -Label 'Hosts file' -Command {
    Get-Content "$env:WINDIR\System32\drivers\etc\hosts"
}

# Remote soundings by mode
switch ($selectedMode) {
    'Full' {
        Get-BaselineConnectivity
        $target = Prompt-ServerTarget
        if (-not [string]::IsNullOrWhiteSpace($target.IP)) {
            Write-Section 'Target port'
            Write-Line ("Sounding: {0}:{1}" -f $target.IP, $target.Port)
            if ($target.IP -match '[A-Za-z]') { Test-DnsResolution -Target $target.IP }
            Test-BasicPing -Target $target.IP
            Test-TcpPort -Target $target.IP -Port $target.Port
            Test-UdpPortLight
            Test-WindrosePortPresets -Target $target.IP
            Run-TraceRoute -Target $target.IP
        } else {
            Add-Finding -Status 'FAIL' -Check 'Server target' -Details 'No IP or hostname provided for remote test.'
            Write-Line 'No target entered. Remote soundings skipped.'
        }
    }
    'Quick' {
        $target = Prompt-ServerTarget
        if (-not [string]::IsNullOrWhiteSpace($target.IP)) {
            Write-Section 'Target port'
            Write-Line ("Sounding: {0}:{1}" -f $target.IP, $target.Port)
            Test-TcpPort -Target $target.IP -Port $target.Port
            Test-UdpPortLight
        } else {
            Add-Finding -Status 'FAIL' -Check 'Server target' -Details 'No IP or hostname provided for quick test.'
            Write-Line 'No target entered. Quick port test skipped.'
        }
    }
    'LocalOnly' {
        Add-Finding -Status 'PASS' -Check 'Mode' -Details 'Stayed ashore - local-only collection completed.'
        Write-Line 'Stayed ashore. Remote soundings skipped.'
    }
}

Export-Summary

Write-Host ''
Write-Host "Chest sealed: $script:RootOut.zip" -ForegroundColor Yellow
Write-Host "Fair winds, Captain." -ForegroundColor Yellow

if (-not $NoPause) {
    Write-Host ''
    Read-Host 'Press Enter to dock'
}
