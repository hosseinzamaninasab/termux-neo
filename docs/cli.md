# Termux Neo Command Interface

Termux Neo is a render-once command-line application. It never installs a
shell prompt, starts a daemon, or creates a background refresh loop.

## Commands

| Command | Behavior |
| --- | --- |
| `termux-neo` | Load configuration, collect safe device data, render once, and exit. |
| `termux-neo --help` | Print command help without probing the device or rendering UI. |
| `termux-neo --version` | Print the version from `VERSION` without probing the device or rendering UI. |
| `termux-neo --diagnose` | Print the privacy-safe built-in diagnostics report and exit. |
| `termux-neo --config` | Print the active configuration path without reading or changing the file. |
| `termux-neo --startup` | Make the Bash startup hook match the saved `startup_integration` setting. |
| `termux-neo --theme NAME` | Render once with the `neo` or `matrix` theme, without saving the override. |
| `termux-neo --no-color` | Render once with ANSI color disabled, without changing the saved color mode. |

Only one option is accepted per invocation. Runtime theme and color overrides
are validated by the existing configuration boundary and never rewrite the
user's settings file.

## Output and exit status

- Normal command output is written to stdout.
- Argument and availability errors are concise and written to stderr.
- Status `0` means the requested command completed successfully.
- Status `1` means runtime data, configuration, layout, rendering, or version
  loading failed.
- Status `2` means the command line is invalid.
- Status `3` remains reserved for a recognized command route that is not
  implemented at a future development checkpoint.

Help, version, and config-path paths do not call data modules or renderers.
Diagnostics explicitly collects only approved application/configuration state,
optional-command availability, selected network/battery sources, and safe module
values. It never dumps the environment, reads secrets, calls UI renderers, or
emits ANSI color. A valid or missing configuration returns status 0; an invalid
configuration path, invalid configuration, or unavailable application version
returns status 1 after a complete report. The startup command is the only CLI
path allowed to edit a shell startup file. It never changes `PS1` or starts a
background process.

## Optional Bash startup integration

Startup integration is disabled by default. To enable it, set
`startup_integration=true` in the active settings file, then run:

```bash
termux-neo --startup
```

The command validates the complete settings file before editing `~/.bashrc`,
creates a backup before each real edit, and installs one uniquely marked block.
Running it again is idempotent. The block runs Termux Neo once only when Bash
is interactive; it does not own or modify the shell prompt.

To remove the managed block, set `startup_integration=false` and run the same
command again. Removal targets only the exact marked block. Incomplete or
duplicate markers fail without changing the startup file. Only Bash is
supported at this checkpoint; no other shell startup file is modified.

## Diagnostics fields

The report uses stable `LABEL: value` lines and includes:

- application version and installation path;
- config path, validation status, and schema status;
- terminal width, selected theme, and selected color mode;
- availability of `ip`, `ifconfig`, `termux-battery-status`, `dumpsys`, and
  `getprop`;
- selected network (`NETWORK_SOURCE`) and battery (`BATTERY_SOURCE`) data
  sources when determinable;
- the same cleaned device, network, VPN, battery, and time values used by the
  production modules.

Unavailable optional data is labeled `Unavailable` or `unavailable`. The
report is generated only when the user explicitly runs `--diagnose`.
