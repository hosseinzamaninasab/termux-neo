# Configuration

Termux Neo reads one strict schema-v1 settings file. The installed launcher
selects:

```text
$HOME/.config/termux-neo/settings.conf
```

Print the active path without reading or changing it:

```bash
termux-neo --config
```

## Complete schema

```ini
schema_version=1
display_user=Zoro
theme=neo
color_mode=auto
startup_integration=false
```

| Key | Default | Allowed values | Effect |
| --- | --- | --- | --- |
| `schema_version` | `1` | `1` | Selects the current settings contract. |
| `display_user` | empty | 1–28 letters, numbers, `_`, `.`, `-` | Dashboard and Prompt display name. |
| `theme` | `neo` | `neo`, `matrix` | Built-in semantic color palette. |
| `color_mode` | `auto` | `auto`, `always`, `never` | ANSI output policy. |
| `startup_integration` | `false` | `true`, `false` | Desired interactive-Bash startup-hook state. |

Values are plain data. Do not use shell quotes, variables, command
substitutions, inline comments, multiline values, or duplicate keys. Unknown
keys, control characters, invalid values, and unsupported schema versions fail
closed. The file is parsed; it is never sourced.

Blank lines and full-line comments beginning with `#` are allowed. Spaces
around a key or value are trimmed.

## Display-user precedence

1. Valid `TERMUX_NEO_USER` runtime override
2. Valid `display_user` setting
3. Valid Termux/system username
4. `User`

One resolved value is shared by Dashboard and Prompt.

## Themes and color

- `auto` enables color only when stdout is a supported terminal and
  `NO_COLOR` is empty.
- `always` explicitly enables theme color, including redirected output.
- `never` emits no ANSI escapes.

`termux-neo --theme NAME` accepts `neo` or `matrix`.
`termux-neo --no-color` affects one invocation only. Neither command edits
this file.

## Optional Bash startup

Changing `startup_integration` has no side effect by itself. After saving the
file, explicitly synchronize the managed `~/.bashrc` block:

```bash
termux-neo --startup
```

Set the value to `false` and run the same command to remove the exact managed
block. Only interactive Bash is supported; Termux Neo does not edit zsh, fish,
or other startup files.

## Missing, legacy, and invalid files

A missing file uses safe defaults. A legacy schema-0 file containing only
`display_user` is migrated in memory; a production update can serialize that
supported migration transactionally. Startup never rewrites settings.

An invalid file causes normal rendering to fail before any partial UI is
printed. Diagnose it with:

```bash
termux-neo --diagnose
```

See [Settings Schema v1](settings-schema-v1.md) for the authoritative parser
rules and [Troubleshooting](troubleshooting.md) for recovery steps.
