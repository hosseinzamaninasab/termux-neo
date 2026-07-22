# Termux Neo Command Interface

Termux Neo is a render-once command-line application. It never installs a
shell prompt, starts a daemon, or creates a background refresh loop.

## Commands

| Command | Behavior |
| --- | --- |
| `termux-neo` | Load configuration, collect safe device data, render once, and exit. |
| `termux-neo --help` | Print command help without probing the device or rendering UI. |
| `termux-neo --version` | Print the version from `VERSION` without probing the device or rendering UI. |
| `termux-neo --diagnose` | Enter the stable diagnostics route. The report implementation is added in Task 18; until then this route exits with status 3 and a concise error. |
| `termux-neo --config` | Print the active configuration path without reading or changing the file. |
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
- Status `3` means a recognized command is not implemented at the current
  development checkpoint.

Help, version, config-path, and unavailable-diagnostics paths do not call data
modules or renderers. No CLI path changes `PS1`, installs startup integration,
or starts a background process.
