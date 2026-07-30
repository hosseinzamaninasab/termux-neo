# Release-Gating Issue Ledger

This is the release-gating defect ledger for stable `1.0.0`.

## Open release gate

```text
Open critical security defects: 0
Open high-severity defects: 0
Open release-blocking defects: 0
```

No unresolved critical, high-severity, or release-blocking defect is recorded.

## Entry contract

Every accepted beta issue must record:

- a stable issue identifier;
- affected version and artifact checksum;
- device model, Android release, and Termux provenance when known;
- exact reproduction steps;
- expected and actual behavior;
- severity and release impact;
- whether the report contains sensitive paths or values;
- status, owner, and verification evidence.

Severity is one of:

| Severity | Release meaning |
| --- | --- |
| Critical security | Exploitable trust-boundary failure; blocks every release |
| Release blocker | Core install, update, uninstall, render, or artifact path is unusable or unsafe |
| High | Serious defect with a viable workaround; must be dispositioned before RC |
| Normal | Non-blocking correctness, compatibility, or documentation defect |
| Enhancement | New capability; requires a separately approved post-1.0 milestone |

An issue may be closed only after a regression or repeatable verification
demonstrates the fix. A portability fixture is not a substitute for real-device
evidence when the defect is device-specific.
