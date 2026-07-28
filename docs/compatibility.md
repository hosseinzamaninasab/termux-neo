# Compatibility Matrix

This matrix separates observed device evidence from portable fixture coverage.
It does not turn one verified device into a general Android, Termux
distribution, hardware, or shell-support claim.

## Verified reference environment

| Dimension | Verified evidence | Support statement |
| --- | --- | --- |
| Device | Samsung Galaxy Note5, model `SM-N920C` | Reference device only |
| Android | Android `11` | Reference Android release only |
| Physical terminal widths | Portrait `56`, landscape `94` | Recorded on the reference device |
| Reference Bash | `5.2.21(1)-release` | Recorded by the public-beta field gate |
| CLI shell | Bash | Executable and development commands require Bash |
| Startup shell | Interactive Bash | Only `~/.bashrc` integration is supported |
| Termux distribution | Channel and package version not recorded | No distribution-specific claim |

The Task 24 apply gate reads the device model and Android release from the
actual reference device. Task 27 adds measured startup evidence, and Task 28
adds an isolated artifact lifecycle plus physical portrait/landscape terminal
record in [beta-field-report.md](beta-field-report.md). A fixture cannot
satisfy any of those device gates. Other rows are rechecked by portable
compatibility, integration, and startup tests. The supported minimum of 34
columns comes from deterministic renderer coverage, not an additional physical
orientation record.

## Portable compatibility scenarios

| Area | Scenarios | Expected behavior |
| --- | --- | --- |
| Layout | Widths `34`, `56`, `94` | Complete centered output; no line exceeds the terminal width |
| Working directory | Home and a directory below home | Prompt shows `~` or the matching `~/...` path |
| Optional commands | `ip`, `ifconfig`, `getprop`, battery API, and `dumpsys` absent | Safe offline or unavailable fallbacks; no stderr |
| Permission failures | Optional data commands return permission denied | Safe fallbacks; raw errors never reach the UI |
| Network | Wi-Fi, mobile, offline, VPN interface | Stable type, state, local-IP source, and VPN state |
| Battery | Charging, discharging, full, unavailable | Valid percentage suffix or `--` fallback |
| Startup | Interactive and non-interactive Bash | One render in interactive Bash; none in non-interactive Bash |

The network cases use a test-only `TERMUX_NEO_NET_CLASS_ROOT` input. Production
execution leaves it unset and reads `/sys/class/net`. Battery fixtures use the
existing `TERMUX_NEO_POWER_SUPPLY_ROOT` input. Neither input is a user setting
or a persisted configuration key.

The Task 28 field matrix records one real device at this checkpoint. Its
offline and permission-denied cases are deterministic inputs; its portrait and
landscape widths come from interactive terminal rotation. Multiple devices are
accepted when reports are available, but no additional device was available
for this checkpoint. One device must not be generalized into wider support.

The renderer-derived screenshots in
[Project Overview](project-overview.md) use the 56-column portable input set.
They demonstrate frozen output and theme roles, not new compatibility evidence.

## Explicitly unverified

- Android releases other than the reference Android 11 environment
- Devices other than the reference Samsung `SM-N920C`
- Specific Termux distribution channels or package versions
- Automatic startup integration for zsh, fish, or other shells
- Terminal widths below 34 columns

The CLI may be launched by another shell only if that shell correctly executes
the Bash shebang and Bash is installed, but that is not an interactive-shell
support claim. New rows may move into the verified section only after their
real environment evidence and deterministic regression coverage are both
recorded.

Current constraints and safe fallbacks are summarized in
[Known Limitations](known-limitations.md) and
[Troubleshooting](troubleshooting.md).
