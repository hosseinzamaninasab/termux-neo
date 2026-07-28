# Diagnostics

Run the explicit, privacy-safe diagnostic route:

```bash
termux-neo --diagnose
```

It prints a stable 26-line report and exits. It does not render the UI, emit
ANSI color, dump the environment, search for secrets, edit settings, or change
startup files.

## Report fields

| Field | Meaning |
| --- | --- |
| `TERMUX NEO DIAGNOSTICS` | Fixed report heading |
| `VERSION` | Application `VERSION` value |
| `INSTALLATION_PATH` | Runtime/project root used by the command |
| `CONFIG_PATH` | Active settings path |
| `CONFIG_STATUS` | `valid`, `invalid`, `missing (defaults)`, or `invalid-path` |
| `SCHEMA_STATUS` | Active schema, default schema, or `invalid` |
| `TERMINAL_WIDTH` | Positive `tput cols` result or `Unavailable` |
| `THEME` | Effective saved/default theme |
| `COLOR_MODE` | Effective saved/default color mode |
| `OPTIONAL_COMMAND ip` | `available` or `unavailable` |
| `OPTIONAL_COMMAND ifconfig` | `available` or `unavailable` |
| `OPTIONAL_COMMAND termux-battery-status` | `available` or `unavailable` |
| `OPTIONAL_COMMAND dumpsys` | `available` or `unavailable` |
| `OPTIONAL_COMMAND getprop` | `available` or `unavailable` |
| `NETWORK_SOURCE` | `ip`, `ifconfig`, `getprop`, or `unavailable` |
| `BATTERY_SOURCE` | `termux-battery-status`, `sysfs`, `dumpsys`, or `unavailable` |
| `DISPLAY_USER` | Resolved configured/runtime/system display user |
| `SYSTEM_USER` | Cleaned Termux/system username |
| `DEVICE` | Cleaned manufacturer/model value or fallback |
| `SYSTEM` | Cleaned Android value or fallback |
| `NETWORK_TYPE` | `Wi-Fi`, `Mobile`, `VPN`, or `Offline` |
| `NETWORK_STATE` | `UP` or `DOWN` |
| `LOCAL_IP` | Valid discovered IPv4 address or `Unavailable` |
| `VPN_STATE` | `ON` or `OFF` |
| `BATTERY` | Percentage, charging `+` suffix, or `--` |
| `TIME` | `HH:MM` or `--:--` |

## Exit status

- `0`: version and configuration are usable; missing optional data is allowed.
- `1`: the version, configuration path, or settings file is invalid or
  unavailable. The command still prints the complete bounded report when it
  can.

Optional command failures are observations, not diagnostic failure by
themselves.

## Privacy

The report can contain local paths, usernames, device model, Android version,
local IP, network state, battery state, and current time. Review and redact
those values before posting it publicly. It intentionally excludes unrelated
environment variables and raw optional-command errors.

Use [Troubleshooting](troubleshooting.md) to interpret common failures and
[Security Review](security.md) for the data boundary.
