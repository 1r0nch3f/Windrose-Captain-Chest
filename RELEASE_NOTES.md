# 🏴‍☠️ Windrose Captain's Chest v1.1.0

Big new feature: **Fleet check** for Windrose backend services.

## 🆕 What's new

### Fleet check — diagnoses "Connection Services: N/A"

If the game shows **N/A** for EU & NA, SEA, or CIS in its Connection Services screen, this release tells you *why*.

The Chest now probes Windrose's own backend endpoints and diagnoses what's happening:

- `r5coopapigateway-eu-release.windrose.support` (EU/NA gateway)
- `r5coopapigateway-ru-release.windrose.support` (CIS gateway)
- `r5coopapigateway-sea-release.windrose.support` (SEA gateway)
- `windrose.support:3478` (STUN/TURN — P2P signaling)

Each endpoint is resolved via **both** your system DNS and Google's 8.8.8.8, then tested on TCP. The diagnosis distinguishes between:

| Finding | What it means |
|--------|---------------|
| **ISP blocking** | Your ISP/router blocks the domain. Google DNS resolves it fine, yours doesn't. |
| **DNS spoofing** | Your DNS is returning 127.0.0.1 or null — VPN, parental controls, or NextDNS-style filter |
| **IPv6-only** | Only IPv6 returned but Windrose is IPv4-only. Needs a registry tweak. |
| **DNS timeout** | Your DNS server isn't responding at all |
| **All reachable** | Backend is fine from your end — issue is elsewhere |
| **Partial outage** | Some regions work, others don't — likely a dev-side regional issue |
| **All down** | Backend entirely unreachable — check the official Discord for outage announcements |

### Fix instructions included in the report

When a problem is detected, the report includes the exact fix directly — DNS switch instructions for Google/Cloudflare, the precise wording to use when contacting your ISP, or the registry command to prioritize IPv4 over IPv6. No need to scour forums.

### New flag

- `-SkipServiceCheck` — skip the Fleet check if you don't need it

## Why this matters

The Windrose devs have publicly asked for help diagnosing ISP connectivity issues. Some ISPs — particularly in EU and NA — are blocking the backend domains. Before this release, a user seeing "N/A" in the game had no way to distinguish between "my ISP is blocking it" and "the servers are down." Now helpers on Discord can triage in seconds.

## 📥 Quick start

Same as before — download `CaptainsChest-v1.1.0.zip`, extract, double-click the exe, accept SmartScreen/UAC, pick a mode.

The Fleet check runs automatically in all three modes. Takes about 5 seconds to add to a run.

## Full changelog

See the [changelog](https://github.com/1r0nch3f/Windrose-Captain-Chest/blob/main/CHANGELOG.md) for complete release history.

---

Fair winds. 🏴‍☠️
