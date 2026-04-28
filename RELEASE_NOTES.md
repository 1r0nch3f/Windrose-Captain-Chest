# 🏴‍☠️ Windrose Captain's Chest v2.2.0

**New diagnostic capability.** The chest now reads the salvaged R5 server logs and grades the at-sea rubber-banding problem so you don't have to scroll through 6,000 lines of log to find what's wrong.

Builds on v2.1.0 (Crow's Nest live network profile, crew invite generator, CaptainsSignal). Both tools and all v2.1.0 features remain.

## 🆕 What's new in v2.2.0

### Logbook scan (R5.log slow-task analysis)

After Salvage runs, a new section parses every `R5*.log` file it pulled in and counts the server's own `R5BLDalAsyncQueue::DetectProblems` slow-task warnings. These are the warnings the Windrose dedicated server emits when its RocksDB commit pipeline is bottlenecked, and they correlate directly with the at-sea rubber-banding pattern reported across every Windrose host (Nitrado, SurvivalServers, LOW.MS, all of them).

The scan buckets every hit by the actual ms value into three tiers:

- **Slow** (under 1 second)
- **Quite slow** (1 to 5 seconds)
- **EXTREMELY slow** (5 seconds and up, sometimes 20+ seconds in the wild)

Then it reports total counts, worst single task, per-file breakdown when multiple logs were salvaged, and the worst offending line truncated to 240 chars so a helper on Discord can eyeball the actual entry.

### Plain-English diagnosis and mitigation playbook

When the scan finds a WARN or FAIL grade worth of slow tasks, the report prints the mitigation list inline:

```
--- DIAGNOSIS ---

These warnings come from the Windrose server itself flagging that
its own RocksDB commit transactions are taking too long. When a
commit blocks during boat movement, the server cannot confirm
your position in time and snaps you back. That is your rubber-band.

There are three contributing factors, in order of impact:
  1. Kraken Express co-op backend routing (acknowledged publicly,
     hotfix shipped 16 Apr 2026, more fixes still in testing).
     Nothing the player can do about this one.
  2. Server-side resource pressure (CPU pegging, slow disk,
     memory bloat over uptime). Fixable.
  3. Network path issues (port 3478 blocks, IPv6 prioritization).
     Caught by the Fleet check above.

--- MITIGATIONS (in order of effort vs payoff) ---

  * Restart the server daily. Schedule at 4 AM or off-hours.
    The R5 server process leaks memory in early access; a
    restart resets the clock. Single biggest win.

  * Match server build to client patch. After every Windrose
    update, update the dedicated server through Steam Update
    BEFORE anyone joins. Version drift breaks worlds.

  * Run the world off an SSD. RocksDB hates spinning disks.
    See the Seaworthy section for whether your system drive
    is SSD; the server world drive should be too.

  * Cap the player count at 4. Kraken supports 8 but
    recommends 4 for a reason. Each extra player multiplies
    entity simulation cost and slow-task rate.

  * Verify CPU headroom on the host. The dedicated server
    pegs 100% CPU at idle on some setups (known issue).
    [...]
```

### Severity grading

| Condition | Grade |
|-----------|-------|
| 0 slow-task hits | PASS |
| Only minor "slow" hits | INFO (below visible-rubber-band threshold) |
| Any "quite slow" but no extreme | INFO (mild lag possible) |
| 1 to 4 EXTREMELY slow hits, worst under 10 seconds | WARN |
| 5+ EXTREMELY slow hits, or worst case 10 seconds or more | FAIL |

### Why this belongs in the tool

Captain's Chest already salvaged R5.log files into the chest, but until now the user had to read them by hand to find anything useful. Players have been pointing each other at `R5\Saved\Logs\R5.log` on Discord and the Steam forums for diagnosis, which works for the technically inclined but leaves everyone else stuck. The Logbook scan turns that into a one-line summary plus a finding in the Captain's summary, and it works whether you're a player diagnosing your friend's hosted server or a server operator running the chest on the host machine itself.

The case-insensitive regex matches all three observed wordings ("Slow task", "quite slow task", "EXTREMELY slow task") by anchoring on the shared `slow task. Task was finished in N ms` suffix, so the bucketing reflects the actual ms value rather than relying on the qualifier text the engine happens to use.

## 📥 Quick start

1. Download **CaptainsChest-v2.2.0.zip** below
2. Extract anywhere
3. Double-click `CaptainsChest.exe` — SmartScreen "More info" → "Run anyway", then UAC → Yes
4. Pick any mode — Logbook scan runs in all three (it operates on whatever Salvage collects)

For just the crew invite (v2.1.0 feature, still here): right-click `CaptainsSignal.ps1` → Run with PowerShell (as admin).

### ⚠️ Antivirus note

Same as always — the exe is compiled with `ps2exe`, Windows Defender sometimes flags it as a false positive. Source `.ps1` files are in the same zip for inspection.

## 💬 What does it actually look like?

If your server is healthy:

```
=== Logbook scan (R5.log slow-task analysis) ===
Scanned 1 log file(s) under Salvage.

No slow-task warnings found. The server-side RocksDB commit
pipeline is keeping up - this rules out the most common cause
of at-sea rubber-banding on dedicated servers.
```

If your server is hurting:

```
=== Logbook scan (R5.log slow-task analysis) ===
Scanned 1 log file(s) under Salvage.

Total slow-task warnings:    47
  Slow (under 1s):           28
  Quite slow (1-5s):         15
  EXTREMELY slow (5s+):      4
Worst single task:           21,698 ms (21.7 seconds)
In file:                     R5.log

Worst line (truncated to 240 chars):
  [2026.04.21-10.01.21:778][510]R5LogBLDalAQ: Warning: [...]
  EXTREMELY slow task. Task was finished in 21698 ms. DebugInfo

[diagnosis and mitigations follow]
```

## 📖 See also

- [Wiki](https://github.com/1r0nch3f/Windrose-Captain-Chest/wiki) — usage guide, troubleshooting
- [Changelog](https://github.com/1r0nch3f/Windrose-Captain-Chest/blob/main/CHANGELOG.md) — full release history
- [Issues](https://github.com/1r0nch3f/Windrose-Captain-Chest/issues) — report bugs or share log samples that don't match the regex

Fair winds, Captain. 🏴‍☠️
