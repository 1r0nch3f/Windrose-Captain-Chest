<#
.SYNOPSIS
    Captain's Chest - a diagnostic toolkit for Windrose crews.

.DESCRIPTION
    Gather ye logs, charts, and soundings into one tidy chest. Produces a
    single pasteable report covering:

      - Ship's papers:  OS, CPU, RAM, GPU (with driver age check)
      - Seaworthy:      Spec check vs Windrose min/recommended (CPU, RAM, GPU,
                        DirectX, disk space, SSD detection)
      - Soundings:      Network adapters, local IP, public IP
      - Hold inventory: Windrose install detection and executable versions
      - Watch posts:    Firewall profile and Steam/Windrose rules
      - Crew roster:    Steam and Windrose process state
      - Log book:       Recent application and system errors
      - Spyglass:       Optional server reachability (DNS, ping, TCP, trace)
      - Salvage:        Collected Config/SaveProfiles/ServerDescription/logs

    Outputs to a timestamped chest on yer Desktop:
      - CaptainsLog.txt           - full human-readable report
      - CaptainsLog.md            - pasteable markdown for Discord/forum
      - CaptainsLog_REDACTED.txt  - optional scrubbed copy safe to post publicly
      - CaptainsLog_REDACTED.md   - optional scrubbed markdown version
      - Manifest.csv              - pass/warn/fail findings
      - Salvage/                  - collected game files
      - Chest_<timestamp>.zip     - the whole chest, sealed for transport

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

.PARAMETER Redact
    Automatically create a redacted version of the report without prompting.
    Useful for automation. Strips hostname, username, IPs, MACs, file paths.

.PARAMETER NoRedactPrompt
    Skip the "create redacted version?" prompt at the end (don't create one).

.EXAMPLE
    .\CaptainsChest.ps1
    .\CaptainsChest.ps1 -ServerIP 1.2.3.4 -ServerPort 7777 -Mode Full -NoPause
    .\CaptainsChest.ps1 -Mode LocalOnly -Redact -NoPause
#>

param(
    [string]$OutputPath = "$env:USERPROFILE\Desktop\WindroseCaptainChest",
    [string]$ServerIP = "",
    [int]$ServerPort = 7777,
    [ValidateSet('Full','Quick','LocalOnly','')]
    [string]$Mode = '',
    [switch]$SkipTraceRoute,
    [switch]$SkipNetworkTests,
    [switch]$NoPause,
    [switch]$Redact,
    [switch]$NoRedactPrompt
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

# --- Windrose system requirements (edit if the game updates these) -------------
# Source: windrosewiki.org/requirements as of April 2026.
# Numbers are "not final and subject to change" per the developers.
$script:WindroseSpecs = @{
    OS = @{
        MinBuild = 19041  # Windows 10 20H1 - any Win10/11 64-bit is fine
        MinName  = 'Windows 10 64-bit'
        RecName  = 'Windows 11 64-bit'
    }
    CPU = @{
        MinCores  = 6       # i7-8700K / Ryzen 7 2700X have 6-8 cores, both hit 6
        RecCores  = 8       # i7-10700 / Ryzen 7 5800X both have 8 cores
        MinGhz    = 3.2
        RecGhz    = 3.8
        MinName   = 'Intel i7-8700K / AMD Ryzen 7 2700X'
        RecName   = 'Intel i7-10700 / AMD Ryzen 7 5800X'
    }
    RAM = @{
        MinGB = 16
        RecGB = 32
    }
    GPU = @{
        # GPU tier lookup - higher number = better card
        # Min = GTX 1080 Ti / RX 6800 (tier 5)
        # Rec = RTX 3080 / RX 6800 XT  (tier 6)
        MinTier = 5
        RecTier = 6
        MinName = 'NVIDIA GTX 1080 Ti / AMD Radeon RX 6800'
        RecName = 'NVIDIA RTX 3080 / AMD Radeon RX 6800 XT'
        MinVramGB = 8
        RecVramGB = 10
    }
    DirectX = @{
        MinVersion = 12
        RecVersion = 12
    }
    Storage = @{
        MinFreeGB = 30
        RecFreeGB = 30
        SsdRequired = $false  # "strongly recommended" for min, "required" for rec
    }
}

# GPU tier table - maps detected GPU name patterns to a performance tier.
# Tiers: 0=below min, 1=very old, 2=low-mid, 3=mid, 4=upper-mid, 5=min spec, 6=rec spec, 7=above rec
$script:GpuTierTable = @(
    # --- Tier 7: above recommended ---
    @{ Pattern = 'RTX\s*(4070|4080|4090|5070|5080|5090)'; Tier = 7; Vendor = 'NVIDIA' }
    @{ Pattern = 'RTX\s*(3080|3090)\s*Ti';                Tier = 7; Vendor = 'NVIDIA' }
    @{ Pattern = 'RX\s*(7800|7900|9070|9080)';            Tier = 7; Vendor = 'AMD' }

    # --- Tier 6: recommended ---
    @{ Pattern = 'RTX\s*(3080|3090)';                     Tier = 6; Vendor = 'NVIDIA' }
    @{ Pattern = 'RTX\s*(4060\s*Ti|4070)';                Tier = 6; Vendor = 'NVIDIA' }
    @{ Pattern = 'RX\s*(6800\s*XT|6900|7700|7800)';       Tier = 6; Vendor = 'AMD' }

    # --- Tier 5: minimum ---
    @{ Pattern = 'GTX\s*1080\s*Ti';                       Tier = 5; Vendor = 'NVIDIA' }
    @{ Pattern = 'RTX\s*(2080|3060\s*Ti|3070|4060)';      Tier = 5; Vendor = 'NVIDIA' }
    @{ Pattern = 'RX\s*(6700\s*XT|6800|5700\s*XT|7600)';  Tier = 5; Vendor = 'AMD' }

    # --- Tier 4: upper-mid (below min but close) ---
    @{ Pattern = 'RTX\s*(2060|2070|3050|3060)';           Tier = 4; Vendor = 'NVIDIA' }
    @{ Pattern = 'GTX\s*(1080|1070\s*Ti)';                Tier = 4; Vendor = 'NVIDIA' }
    @{ Pattern = 'RX\s*(5700|6600|6700|5600\s*XT)';       Tier = 4; Vendor = 'AMD' }

    # --- Tier 3: mid ---
    @{ Pattern = 'GTX\s*(1070|1660|1060\s*6GB)';          Tier = 3; Vendor = 'NVIDIA' }
    @{ Pattern = 'RX\s*(580|590|5500\s*XT|6500\s*XT)';    Tier = 3; Vendor = 'AMD' }

    # --- Tier 2: low-mid ---
    @{ Pattern = 'GTX\s*(1050|1060|1650)';                Tier = 2; Vendor = 'NVIDIA' }
    @{ Pattern = 'RX\s*(470|480|570|560)';                Tier = 2; Vendor = 'AMD' }

    # --- Tier 1: very old ---
    @{ Pattern = 'GTX\s*(9[56]0|10[45]0|750|760|770|780)'; Tier = 1; Vendor = 'NVIDIA' }
    @{ Pattern = 'RX\s*(460|550|460)';                    Tier = 1; Vendor = 'AMD' }

    # --- Tier 0: definitely below min ---
    @{ Pattern = '(UHD|Iris|HD)\s*Graphics';              Tier = 0; Vendor = 'Intel iGPU' }
    @{ Pattern = 'Vega\s*\d+';                            Tier = 0; Vendor = 'AMD iGPU' }
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
    Write-Section "Ship's papers (OS)"

    # Get-ComputerInfo's WindowsProductName can incorrectly report "Windows 10 Pro"
    # on Windows 11 systems. Use the registry ProductName and cross-reference with
    # build number to get the right marketing name.
    $os = Get-CimInstance Win32_OperatingSystem
    $build = [int]$os.BuildNumber
    $arch  = $os.OSArchitecture

    # Build 22000+ is Windows 11; below that is Windows 10
    $edition = try {
        (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name ProductName).ProductName
    } catch { $os.Caption }

    $marketingName = if ($build -ge 22000) {
        $edition -replace 'Windows 10', 'Windows 11'
    } else {
        $edition
    }

    $displayVersion = try {
        (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name DisplayVersion -ErrorAction Stop).DisplayVersion
    } catch { '' }

    Write-Line ("Product:      {0}" -f $marketingName)
    if ($displayVersion) { Write-Line ("Version:      {0}" -f $displayVersion) }
    Write-Line ("Build:        {0}" -f $build)
    Write-Line ("Architecture: {0}" -f $arch)
    Write-Line ("Host:         {0}" -f $env:COMPUTERNAME)
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

function Get-GpuVramGB {
    param([string]$GpuName)

    # Win32_VideoController.AdapterRAM is a UInt32 that overflows at 4GB - any
    # GPU with more VRAM than that will report 4 (or a bogus smaller number).
    # Try multiple registry locations where Windows stores the real value as
    # a 64-bit QWORD.

    # Method 1: HKLM\SYSTEM\CurrentControlSet\Control\Video - most reliable,
    # stores HardwareInformation.qwMemorySize as QWORD for each adapter.
    try {
        $videoRoot = 'HKLM:\SYSTEM\CurrentControlSet\Control\Video'
        if (Test-Path $videoRoot) {
            $guidFolders = Get-ChildItem $videoRoot -ErrorAction SilentlyContinue |
                Where-Object { $_.PSChildName -match '^\{[0-9A-Fa-f\-]+\}$' }
            foreach ($guid in $guidFolders) {
                # Each adapter has 0000, 0001, etc. subkeys
                $subkeys = Get-ChildItem $guid.PSPath -ErrorAction SilentlyContinue |
                    Where-Object { $_.PSChildName -match '^\d{4}$' }
                foreach ($sub in $subkeys) {
                    $props = Get-ItemProperty $sub.PSPath -ErrorAction SilentlyContinue
                    # Match on DriverDesc which holds the display name
                    $desc = $props.'DriverDesc'
                    if (-not $desc) { $desc = $props.'Device Description' }
                    if ($desc -and $GpuName -and ($desc -eq $GpuName -or $GpuName -like "*$desc*" -or $desc -like "*$GpuName*")) {
                        $qword = $props.'HardwareInformation.qwMemorySize'
                        if (-not $qword) { $qword = $props.'HardwareInformation.MemorySize' }
                        if ($qword -and $qword -gt 0) {
                            return [math]::Round($qword / 1GB, 1)
                        }
                    }
                }
            }
        }
    } catch { }

    # Method 2: HKLM\SOFTWARE\Microsoft\DirectX - newer Windows versions
    try {
        $regPath = 'HKLM:\SOFTWARE\Microsoft\DirectX'
        if (Test-Path $regPath) {
            $adapters = Get-ChildItem $regPath -ErrorAction SilentlyContinue | Where-Object {
                $_.PSChildName -match '^\{[0-9A-Fa-f\-]+\}$'
            }
            foreach ($adapter in $adapters) {
                $props = Get-ItemProperty $adapter.PSPath -ErrorAction SilentlyContinue
                if ($props.Description -eq $GpuName -and $props.DedicatedVideoMemory) {
                    return [math]::Round($props.DedicatedVideoMemory / 1GB, 1)
                }
            }
        }
    } catch { }

    # Method 3: WMI Win32_VideoController but re-read AdapterRAM as an UInt32
    # overflow hint — if it reports exactly 4294967295 or 4294836224 or a
    # similar near-4GB value, we know the card is >=4GB but can't tell how much
    try {
        $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq $GpuName } | Select-Object -First 1
        if ($gpu -and $gpu.AdapterRAM) {
            $bytes = [uint64]$gpu.AdapterRAM
            # If it's within 64 MB of the 4GB UInt32 cap, it's definitely overflowed
            if ($bytes -ge 4227858432) {
                return 4  # sentinel - caller can treat as "at least 4, real value unknown"
            }
            return [math]::Round($bytes / 1GB, 2)
        }
    } catch { }

    return $null
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

        # Prefer registry-sourced VRAM (fixes 4GB cap bug), fall back to WMI
        $vramGB = Get-GpuVramGB -GpuName $gpu.Name
        if (-not $vramGB -and $gpu.AdapterRAM) {
            $vramGB = [math]::Round($gpu.AdapterRAM / 1GB, 2)
        }
        $vramDisplay = if ($vramGB) { "$vramGB" } else { 'unknown' }

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
        Write-Line ("VRAM (GB):      {0}" -f $vramDisplay)
        Write-Line ''
    }
}

# -------------------------------------------------------------------------------
# Seaworthy check (min/recommended spec comparison)
# -------------------------------------------------------------------------------

function Get-GpuTier {
    param([string]$GpuName)

    if ([string]::IsNullOrWhiteSpace($GpuName)) { return -1 }

    foreach ($entry in $script:GpuTierTable) {
        if ($GpuName -match $entry.Pattern) {
            return $entry.Tier
        }
    }
    return -1  # unknown
}

function Get-DirectXVersion {
    try {
        $tempFile = Join-Path $env:TEMP "dxdiag_$(Get-Random).txt"
        Start-Process -FilePath 'dxdiag' -ArgumentList "/t `"$tempFile`"" -Wait -NoNewWindow -ErrorAction Stop
        # dxdiag runs async sometimes - give it a moment
        $waited = 0
        while (-not (Test-Path $tempFile) -and $waited -lt 10) {
            Start-Sleep -Seconds 1
            $waited++
        }
        if (Test-Path $tempFile) {
            $content = Get-Content $tempFile -Raw
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            if ($content -match 'DirectX Version:\s*DirectX\s+(\d+)') {
                return [int]$matches[1]
            }
        }
    } catch { }
    return $null
}

function Get-SystemDriveIsSSD {
    param([string]$DriveLetter = 'C')
    try {
        $partition = Get-Partition -DriveLetter $DriveLetter -ErrorAction Stop
        $disk = Get-PhysicalDisk | Where-Object { $_.DeviceId -eq $partition.DiskNumber }
        if ($disk) {
            return ($disk.MediaType -eq 'SSD')
        }
    } catch { }
    return $null  # unknown
}

function Test-Seaworthy {
    Write-Section 'Seaworthy check (minimum/recommended specs)'
    $specs = $script:WindroseSpecs

    Write-Line 'Comparing yer ship against the Windrose requirements.'
    Write-Line ("  Minimum:      CPU {0}, {1} GB RAM, {2}" -f $specs.CPU.MinName, $specs.RAM.MinGB, $specs.GPU.MinName)
    Write-Line ("  Recommended:  CPU {0}, {1} GB RAM, {2}" -f $specs.CPU.RecName, $specs.RAM.RecGB, $specs.GPU.RecName)
    Write-Line ''

    # --- OS check ---
    $os = Get-CimInstance Win32_OperatingSystem
    $osArch = $os.OSArchitecture
    $osBuild = [int]($os.BuildNumber)
    $is64bit = $osArch -match '64'
    $osDisplay = "$($os.Caption) (build $osBuild, $osArch)"
    Write-Line ("OS:      {0}" -f $osDisplay)

    if (-not $is64bit) {
        Write-Line '         [FAIL] Windrose requires a 64-bit OS.'
        Add-Finding -Status 'FAIL' -Check 'Seaworthy: OS' -Details "64-bit required. Detected: $osArch"
    } elseif ($osBuild -ge 22000) {
        Write-Line '         [PASS-REC] Meets recommended (Windows 11).'
        Add-Finding -Status 'PASS' -Check 'Seaworthy: OS' -Details "Meets recommended ($osDisplay)."
    } elseif ($osBuild -ge $specs.OS.MinBuild) {
        Write-Line '         [PASS-MIN] Meets minimum (Windows 10 64-bit).'
        Add-Finding -Status 'PASS' -Check 'Seaworthy: OS' -Details "Meets minimum ($osDisplay)."
    } else {
        Write-Line '         [FAIL] Below minimum Windows 10 build.'
        Add-Finding -Status 'FAIL' -Check 'Seaworthy: OS' -Details "Below minimum. Detected: $osDisplay"
    }

    # --- CPU check ---
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $cpuCores = [int]$cpu.NumberOfCores
    $cpuGhz = [math]::Round($cpu.MaxClockSpeed / 1000.0, 2)
    Write-Line ("CPU:     {0} ({1} cores @ {2} GHz)" -f $cpu.Name.Trim(), $cpuCores, $cpuGhz)

    if ($cpuCores -ge $specs.CPU.RecCores -and $cpuGhz -ge $specs.CPU.RecGhz) {
        Write-Line '         [PASS-REC] Meets recommended CPU.'
        Add-Finding -Status 'PASS' -Check 'Seaworthy: CPU' -Details "Meets recommended ($cpuCores cores, $cpuGhz GHz)."
    } elseif ($cpuCores -ge $specs.CPU.MinCores -and $cpuGhz -ge $specs.CPU.MinGhz) {
        Write-Line '         [PASS-MIN] Meets minimum CPU.'
        Add-Finding -Status 'PASS' -Check 'Seaworthy: CPU' -Details "Meets minimum ($cpuCores cores, $cpuGhz GHz). Recommended: $($specs.CPU.RecCores) cores, $($specs.CPU.RecGhz)+ GHz."
    } else {
        Write-Line '         [FAIL] Below minimum CPU.'
        Add-Finding -Status 'FAIL' -Check 'Seaworthy: CPU' -Details "Below minimum ($cpuCores cores, $cpuGhz GHz). Min: $($specs.CPU.MinCores) cores, $($specs.CPU.MinGhz)+ GHz."
    }

    # --- RAM check ---
    $ramBytes = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    $ramGB = [math]::Round($ramBytes / 1GB, 2)
    Write-Line ("RAM:     {0} GB" -f $ramGB)

    if ($ramGB -ge $specs.RAM.RecGB) {
        Write-Line '         [PASS-REC] Meets recommended RAM.'
        Add-Finding -Status 'PASS' -Check 'Seaworthy: RAM' -Details "Meets recommended ($ramGB GB)."
    } elseif ($ramGB -ge $specs.RAM.MinGB) {
        Write-Line ('         [PASS-MIN] Meets minimum. Recommended is {0} GB.' -f $specs.RAM.RecGB)
        Add-Finding -Status 'PASS' -Check 'Seaworthy: RAM' -Details "Meets minimum ($ramGB GB). Recommended: $($specs.RAM.RecGB) GB."
    } else {
        Write-Line '         [FAIL] Below minimum RAM.'
        Add-Finding -Status 'FAIL' -Check 'Seaworthy: RAM' -Details "Below minimum ($ramGB GB). Min: $($specs.RAM.MinGB) GB."
    }

    # --- GPU check ---
    $gpus = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Basic|Remote|Meta|Mirror' }
    $bestTier = -1
    $bestGpu = $null
    foreach ($g in $gpus) {
        $tier = Get-GpuTier -GpuName $g.Name
        if ($tier -gt $bestTier) {
            $bestTier = $tier
            $bestGpu = $g
        }
    }

    if ($bestGpu) {
        # Prefer registry lookup (fixes 4GB WMI overflow), fall back to WMI
        $vramGB = Get-GpuVramGB -GpuName $bestGpu.Name
        if (-not $vramGB -and $bestGpu.AdapterRAM) {
            $vramGB = [math]::Round($bestGpu.AdapterRAM / 1GB, 2)
        }
        $vramDisplay = if ($vramGB) { "$vramGB GB VRAM" } else { 'VRAM unknown' }
        Write-Line ("GPU:     {0} ({1})" -f $bestGpu.Name, $vramDisplay)

        if ($bestTier -eq -1) {
            Write-Line '         [MANUAL] Could not auto-classify this GPU. Compare manually to the requirements above.'
            Add-Finding -Status 'INFO' -Check 'Seaworthy: GPU' -Details "GPU '$($bestGpu.Name)' not in lookup table - check manually against $($specs.GPU.MinName) / $($specs.GPU.RecName)."
        } elseif ($bestTier -ge $specs.GPU.RecTier) {
            Write-Line '         [PASS-REC] Meets recommended GPU tier.'
            Add-Finding -Status 'PASS' -Check 'Seaworthy: GPU' -Details "$($bestGpu.Name) meets recommended tier."
        } elseif ($bestTier -ge $specs.GPU.MinTier) {
            Write-Line '         [PASS-MIN] Meets minimum GPU tier.'
            Add-Finding -Status 'PASS' -Check 'Seaworthy: GPU' -Details "$($bestGpu.Name) meets minimum tier. Recommended: $($specs.GPU.RecName)."
        } else {
            Write-Line '         [FAIL] Below minimum GPU tier.'
            Add-Finding -Status 'FAIL' -Check 'Seaworthy: GPU' -Details "$($bestGpu.Name) below minimum. Min: $($specs.GPU.MinName)."
        }
    } else {
        Write-Line 'GPU:     no suitable adapter detected'
        Add-Finding -Status 'WARN' -Check 'Seaworthy: GPU' -Details 'No GPU detected or only basic/virtual adapters present.'
    }

    # --- DirectX check ---
    Write-Line ''
    Write-Line 'DirectX: querying dxdiag (this takes a few seconds)...'
    $dxVersion = Get-DirectXVersion
    if ($dxVersion) {
        Write-Line ("         DirectX {0} detected" -f $dxVersion)
        if ($dxVersion -ge $specs.DirectX.MinVersion) {
            Write-Line '         [PASS] Meets DirectX requirement.'
            Add-Finding -Status 'PASS' -Check 'Seaworthy: DirectX' -Details "DirectX $dxVersion (required: $($specs.DirectX.MinVersion))."
        } else {
            Write-Line '         [FAIL] Below minimum DirectX version.'
            Add-Finding -Status 'FAIL' -Check 'Seaworthy: DirectX' -Details "DirectX $dxVersion detected. Required: $($specs.DirectX.MinVersion)."
        }
    } else {
        Write-Line '         [UNKNOWN] Could not parse DirectX version from dxdiag.'
        Add-Finding -Status 'INFO' -Check 'Seaworthy: DirectX' -Details "DirectX version could not be determined via dxdiag."
    }

    # --- Storage check ---
    Write-Line ''
    $targetDrive = $null
    $installs = @(Find-WindroseInstall)   # force array even if single result
    if ($installs -and $installs.Count -gt 0) {
        # Robustly extract a drive letter from the first install path. Guards
        # against any upstream weirdness with array shape or path concatenation.
        $firstPath = [string]$installs[0]
        if ($firstPath -match '^([A-Za-z]):\\') {
            $targetDrive = $matches[1].ToUpper()
        }
    }

    if ($targetDrive) {
        Write-Line ("Storage: checking drive {0}: (Windrose install drive)" -f $targetDrive)
    } else {
        $targetDrive = 'C'
        Write-Line 'Storage: checking drive C: (no Windrose install found - default)'
    }

    $drive = Get-PSDrive -Name $targetDrive -ErrorAction SilentlyContinue
    if ($drive) {
        $freeGB = [math]::Round($drive.Free / 1GB, 2)
        Write-Line ("         Free space: {0} GB" -f $freeGB)

        if ($freeGB -ge $specs.Storage.RecFreeGB) {
            Write-Line ('         [PASS] Meets {0} GB requirement.' -f $specs.Storage.MinFreeGB)
            Add-Finding -Status 'PASS' -Check 'Seaworthy: Storage' -Details "$freeGB GB free on $($targetDrive): (need $($specs.Storage.MinFreeGB) GB)."
        } else {
            Write-Line ('         [FAIL] Below {0} GB requirement.' -f $specs.Storage.MinFreeGB)
            Add-Finding -Status 'FAIL' -Check 'Seaworthy: Storage' -Details "Only $freeGB GB free on $($targetDrive):. Need $($specs.Storage.MinFreeGB) GB."
        }

        # SSD check
        $isSsd = Get-SystemDriveIsSSD -DriveLetter $targetDrive
        if ($isSsd -eq $true) {
            Write-Line '         [PASS] SSD detected (recommended).'
            Add-Finding -Status 'PASS' -Check 'Seaworthy: SSD' -Details "Drive $($targetDrive): is an SSD."
        } elseif ($isSsd -eq $false) {
            Write-Line '         [WARN] HDD detected - SSD is strongly recommended for Windrose.'
            Add-Finding -Status 'WARN' -Check 'Seaworthy: SSD' -Details "Drive $($targetDrive): is an HDD. SSD strongly recommended."
        } else {
            Write-Line '         [UNKNOWN] Could not determine drive type.'
            Add-Finding -Status 'INFO' -Check 'Seaworthy: SSD' -Details "Could not determine if drive $($targetDrive): is SSD or HDD."
        }
    } else {
        Write-Line '         [WARN] Could not read drive info.'
        Add-Finding -Status 'WARN' -Check 'Seaworthy: Storage' -Details "Could not read drive $($targetDrive):"
    }

    Write-Line ''
    Write-Line 'Note: Windrose is in Early Access - the developers state that requirements are'
    Write-Line 'not final. For self-hosted servers, add RAM on top of these numbers.'
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

function Get-SteamInstallPath {
    # Steam's install path from the registry is the most reliable starting point.
    $regPaths = @(
        'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
        'HKLM:\SOFTWARE\Valve\Steam',
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
    $libs = New-Object System.Collections.Generic.List[string]

    # Build list of libraryfolders.vdf candidates - registry path plus legacy defaults
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
                $ms = [regex]::Matches($content, '"path"\s+"([^"]+)"')
                foreach ($m in $ms) {
                    [void]$libs.Add(($m.Groups[1].Value -replace '\\\\', '\'))
                }
            } catch { }
        }
    }

    # Brute-force scan fixed drives for common Steam library folder names.
    # Catches the case where Steam's own config doesn't list the library
    # (e.g. manually created libraries).
    try {
        $drives = Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue |
            Where-Object { $_.Free -gt 0 -and $_.Root -match '^[A-Z]:\\$' }
        foreach ($d in $drives) {
            $driveCandidates = @(
                (Join-Path $d.Root 'SteamLibrary')
                (Join-Path $d.Root 'Steam')
                (Join-Path $d.Root 'Games\SteamLibrary')
                (Join-Path $d.Root 'Games\Steam')
            )
            foreach ($c in $driveCandidates) {
                if (Test-Path $c) { [void]$libs.Add($c) }
            }
        }
    } catch { }

    return ($libs | Select-Object -Unique)
}

$script:WindroseInstallCache = $null

function Find-WindroseInstall {
    # Cache the result - this function is called twice (once by Test-Seaworthy,
    # once by Get-GameVersionInfo) and they should always agree.
    if ($null -ne $script:WindroseInstallCache) {
        return ,@($script:WindroseInstallCache)  # comma operator forces array wrap
    }

    $candidates = New-Object System.Collections.Generic.List[string]

    # Helper: add a path to the list, normalizing it first. Skips empty/bogus entries.
    $addPath = {
        param($p)
        if ([string]::IsNullOrWhiteSpace($p)) { return }
        try {
            # Force to a clean string. Resolve-Path gives a canonical form but fails
            # on non-existent paths, so fall back to trimming.
            $normalized = $null
            try {
                $normalized = (Resolve-Path -LiteralPath $p -ErrorAction Stop).Path
            } catch {
                $normalized = $p.ToString().TrimEnd('\').Trim()
            }
            if (-not [string]::IsNullOrWhiteSpace($normalized) -and $normalized -match ':\\') {
                $candidates.Add($normalized)
            }
        } catch { }
    }

    foreach ($p in (Get-WindrosePaths)) {
        & $addPath $p
    }

    foreach ($lib in (Get-SteamLibraries)) {
        $c1 = Join-Path $lib 'steamapps\common\Windrose'
        $c2 = Join-Path $lib 'common\Windrose'
        if (Test-Path $c1) { & $addPath $c1 }
        if (Test-Path $c2) { & $addPath $c2 }
    }

    # Last resort: scan firewall rules for an already-known Windrose.exe path.
    try {
        $firewallPath = Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue |
            Where-Object { $_.Program -match '\\Windrose\\.*Windrose\.exe$' -or $_.Program -match '\\Windrose\\.*R5.*\.exe$' } |
            Select-Object -ExpandProperty Program -First 1
        if ($firewallPath) {
            # Walk up to the Windrose folder
            $installDir = Split-Path $firewallPath -Parent
            while ($installDir -and (Split-Path $installDir -Leaf) -ne 'Windrose') {
                $parent = Split-Path $installDir -Parent
                if ($parent -eq $installDir) { $installDir = $null; break }
                $installDir = $parent
            }
            if ($installDir -and (Test-Path $installDir)) {
                & $addPath $installDir
            }
        }
    } catch { }

    # Case-insensitive dedupe (Windows paths aren't case-sensitive)
    $seen = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    $unique = New-Object System.Collections.Generic.List[string]
    foreach ($c in $candidates) {
        if ($seen.Add($c)) { $unique.Add($c) }
    }

    # Return as a plain string array, force single-item arrays to stay arrays
    $result = @($unique.ToArray())
    $script:WindroseInstallCache = $result
    return $result
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
    $installs = @(Find-WindroseInstall)
    Write-Section 'Shipyard (Windrose installs)'
    if (-not $installs -or $installs.Count -eq 0) {
        Write-Line 'No install path auto-detected.'
        Add-Finding -Status 'WARN' -Check 'Game install' -Details 'Windrose install not auto-detected.'
        return @()
    }

    foreach ($i in $installs) { Write-Line ([string]$i) }

    foreach ($install in $installs) {
        $installStr = [string]$install
        $exeCandidates = Get-ChildItem -Path $installStr -Recurse -Include *.exe -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'Windrose|R5' } |
            Select-Object -First 5

        if ($exeCandidates) {
            Write-Section "Hull markings in $installStr"
            foreach ($exe in $exeCandidates) {
                Write-Line ("{0} | {1}" -f $exe.FullName, $exe.VersionInfo.FileVersion)
            }
            Add-Finding -Status 'PASS' -Check 'Game install' -Details "Install and version info detected in $installStr."
        } else {
            Add-Finding -Status 'WARN' -Check 'Game version' -Details "Install found at $installStr but no Windrose/R5 exe detected."
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
        Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall' -ErrorAction SilentlyContinue |
            Get-ItemProperty -ErrorAction SilentlyContinue |
            Where-Object { $_.PSObject.Properties.Name -contains 'DisplayName' -and $_.DisplayName -and $_.DisplayName -match 'Visual C\+\+' } |
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
# Redaction (safe-to-post version for Discord/forums)
# -------------------------------------------------------------------------------

function New-RedactedReport {
    <#
        Takes a path to a full report (.txt or .md) and writes a redacted
        version next to it with personal/identifying data replaced by
        <REDACTED> placeholders. Keeps all diagnostic data intact.
    #>
    param(
        [string]$InputPath,
        [string]$OutputPath
    )

    if (-not (Test-Path $InputPath)) { return $false }

    $content = Get-Content $InputPath -Raw

    # Build set of values to scrub dynamically from this run's environment
    $hostname = $env:COMPUTERNAME
    $username = $env:USERNAME
    $userPathEscaped = [regex]::Escape("C:\Users\$username")
    $userHomeEscaped = [regex]::Escape($env:USERPROFILE)

    # --- Specific values (tied to current user/machine) -----------------------

    # Hostname - the most unique identifier
    if ($hostname) {
        $content = $content -replace [regex]::Escape($hostname), '<REDACTED_HOSTNAME>'
    }

    # Username - replace in all forms including file paths
    if ($username) {
        $content = $content -replace [regex]::Escape($username), '<REDACTED_USER>'
    }

    # Full user profile path (in case env var resolves differently)
    $content = $content -replace $userHomeEscaped, 'C:\Users\<REDACTED_USER>'
    $content = $content -replace $userPathEscaped, 'C:\Users\<REDACTED_USER>'

    # --- Generic patterns -----------------------------------------------------

    # Public IPv4 - any non-private IPv4 address
    # Private ranges: 10.x, 172.16-31.x, 192.168.x, 127.x, 169.254.x
    # Everything else is public. We check carefully to avoid redacting
    # localhost, subnet masks, metric numbers, etc.
    $content = [regex]::Replace($content, '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b', {
        param($m)
        $ip = $m.Value
        $parts = $ip.Split('.')
        # Skip if any octet is >255 (not a real IP - probably a version or subnet mask)
        foreach ($p in $parts) {
            if ([int]$p -gt 255) { return $ip }
        }
        $o1 = [int]$parts[0]; $o2 = [int]$parts[1]
        # Keep: localhost, private networks, link-local, multicast, subnet masks
        if ($o1 -eq 0) { return $ip }                                    # 0.0.0.0
        if ($o1 -eq 10) { return $ip }                                   # 10.x private
        if ($o1 -eq 127) { return $ip }                                  # loopback
        if ($o1 -eq 169 -and $o2 -eq 254) { return $ip }                 # link-local
        if ($o1 -eq 172 -and $o2 -ge 16 -and $o2 -le 31) { return $ip }  # 172.16-31 private
        if ($o1 -eq 192 -and $o2 -eq 168) { return $ip }                 # 192.168 private
        if ($o1 -ge 224) { return $ip }                                  # multicast/reserved
        if ($o1 -eq 255) { return $ip }                                  # subnet mask
        # Well-known public DNS that's not really personal (shows up in hosts/DNS)
        if ($ip -in @('1.1.1.1','1.0.0.1','8.8.8.8','8.8.4.4','9.9.9.9')) { return $ip }
        return '<REDACTED_PUBLIC_IP>'
    })

    # Local IPv4 - replace 192.168.x.y and 10.x.y.z host portions but keep subnet shape
    # Keep default gateways recognizable (usually .1 or .254) but redact specific host IPs
    $content = [regex]::Replace($content, '\b192\.168\.\d{1,3}\.\d{1,3}\b', {
        param($m)
        $ip = $m.Value
        $parts = $ip.Split('.')
        $last = [int]$parts[3]
        # Keep .0 (network), .1 (common gateway), .254 (common gateway), .255 (broadcast)
        if ($last -in @(0, 1, 254, 255)) { return $ip }
        return "192.168.$($parts[2]).<REDACTED_HOST>"
    })

    # DHCPv6 DUID - Windows-format includes MAC. IMPORTANT: must run BEFORE the
    # MAC regex below, otherwise MAC substitutions break the DUID pattern.
    $content = $content -replace 'DHCPv6 Client DUID[\.\s]*:\s*[\w\-]+', 'DHCPv6 Client DUID . . . . . . . . : <REDACTED_DUID>'
    $content = $content -replace 'DHCPv6 IAID[\.\s]*:\s*\d+', 'DHCPv6 IAID . . . . . . . . . . . : <REDACTED_IAID>'

    # DHCP lease dates - match Windows' actual format which uses variable dot spacing
    $content = $content -replace '(Lease (?:Obtained|Expires)[\.\s]*:\s*)[A-Za-z]+,\s*[A-Za-z]+\s+\d+,\s*\d+\s+\d+:\d+:\d+\s*[AP]M', '$1<REDACTED_LEASE_TIME>'

    # MAC addresses - both hyphen and colon forms (must run AFTER DUID scrubbing)
    $content = $content -replace '\b([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}\b', '<REDACTED_MAC>'

    # IPv6 - link-local and globals
    # Link-local fe80::/10 - redact interface ID portion
    $content = $content -replace 'fe80::[0-9a-fA-F:]+', 'fe80::<REDACTED>'
    # Any other IPv6 global - full redact (conservative)
    $content = $content -replace '\b(?:[0-9a-fA-F]{1,4}:){3,7}[0-9a-fA-F]{1,4}\b', {
        param($m)
        $v = $m.Value
        if ($v -match '^(fe80|::1|::)' -or $v -eq '::1') { return $v }
        return '<REDACTED_IPV6>'
    }

    # --- File paths - strip drive paths with user folder references -----------
    # F:\SteamLibrary\... and similar are OK (hardware layout is useful to helpers)
    # C:\Users\<anyone>\... is not
    $content = $content -replace '([A-Z]:\\Users\\)[^\\\s]+', '$1<REDACTED_USER>'

    # --- Banner / header ------------------------------------------------------
    # Add a notice at the top so anyone reading knows this is scrubbed
    $banner = @"
===============================================================================
  REDACTED REPORT - safe to share
  Personal data (hostname, username, public IP, MAC, etc.) has been replaced
  with <REDACTED_*> placeholders. Hardware and diagnostic data preserved.
  Generated: $(Get-Date)
===============================================================================

"@

    # Only prepend banner to text reports, not markdown (markdown has its own
    # structure that's cleaner to edit below)
    if ($OutputPath -match '\.txt$') {
        $content = $banner + $content
    } else {
        # For markdown: insert a warning callout after the title
        $content = $content -replace '(?m)^(# Windrose Captain.*?\r?\n)', @"
`$1
> ⚠️ **Redacted for sharing.** Personal data (hostname, username, public IP, MAC, etc.) has been replaced with `<REDACTED_*>` placeholders. Hardware and diagnostic data preserved.

"@
    }

    Set-Content -Path $OutputPath -Value $content -Force
    return $true
}

function Invoke-RedactionFlow {
    <#
        Runs after the normal Export-Summary. Either creates the redacted
        copy automatically (if -Redact passed), asks the user (default),
        or skips entirely (if -NoRedactPrompt passed).
    #>

    $shouldCreate = $false

    if ($NoRedactPrompt) {
        return
    } elseif ($Redact) {
        $shouldCreate = $true
    } else {
        Write-Host ''
        Write-Host 'Redaction option' -ForegroundColor Green
        Write-Host 'Create a redacted version of the report with personal data scrubbed?'
        Write-Host 'Useful for posting in Discord or forums when asking for help.'
        Write-Host 'Strips: hostname, username, public IP, MAC addresses, file paths.'
        $answer = Read-Host 'Create redacted copy? (Y/n)'
        if ([string]::IsNullOrWhiteSpace($answer) -or $answer -match '^[Yy]') {
            $shouldCreate = $true
        }
    }

    if (-not $shouldCreate) { return }

    $redactedTxt = Join-Path $script:RootOut 'CaptainsLog_REDACTED.txt'
    $redactedMd  = Join-Path $script:RootOut 'CaptainsLog_REDACTED.md'

    $okTxt = New-RedactedReport -InputPath $script:ReportFile   -OutputPath $redactedTxt
    $okMd  = New-RedactedReport -InputPath $script:MarkdownFile -OutputPath $redactedMd

    # Rebuild the zip to include the new redacted files
    $zipPath = "$script:RootOut.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path "$script:RootOut\*" -DestinationPath $zipPath -Force

    Write-Section 'Redacted versions created'
    if ($okTxt) { Write-Line "Redacted TXT:  $redactedTxt" }
    if ($okMd)  { Write-Line "Redacted MD:   $redactedMd" }
    Write-Line ''
    Write-Line 'Post the REDACTED version (not CaptainsLog.txt) when sharing publicly.'
    Write-Line 'Quick review before posting: open it in Notepad and skim for anything'
    Write-Line 'that looks personal - the regex catches common things but no tool is perfect.'
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
Test-Seaworthy
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

Invoke-RedactionFlow

Write-Host ''
Write-Host "Chest sealed: $script:RootOut.zip" -ForegroundColor Yellow
Write-Host "Fair winds, Captain." -ForegroundColor Yellow

if (-not $NoPause) {
    Write-Host ''
    Read-Host 'Press Enter to dock'
}
