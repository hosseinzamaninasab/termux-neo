# Termux Neo Settings Schema v1

Termux Neo settings are plain data. The application parses this file itself;
it never sources or evaluates configuration as shell code.

## Syntax

- One `KEY=value` record per line.
- Blank lines and full-line comments beginning with `#` are allowed.
- Spaces around the key and value are trimmed.
- Shell quotes, variables, command substitutions, inline comments, multiline
  values, control characters, duplicate keys, and unknown keys are rejected.

## Schema

| Key | Default | Allowed values | Runtime effect |
| --- | --- | --- | --- |
| `schema_version` | `1` | `1` | Selects the supported settings contract. |
| `display_user` | empty | 1–28 letters, numbers, `_`, `.`, `-` | Used by Dashboard and Prompt after precedence resolution. |
| `theme` | `neo` | `neo`, `matrix` | Selects a built-in semantic color palette. |
| `color_mode` | `auto` | `auto`, `always`, `never` | Controls ANSI color output. |
| `startup_integration` | `false` | `true`, `false` | Selects whether `termux-neo --startup` installs or removes the Bash startup hook. |

Changing `startup_integration` never edits a shell file by itself. Run
`termux-neo --startup` to explicitly apply the saved preference. This keeps
normal rendering, diagnostics, and configuration loading side-effect free.

## Themes and color modes

The default `neo` palette uses restrained cyan and magenta accents. The
optional `matrix` palette uses a restrained green accent without changing UI
text, geometry, or layout behavior.

- `auto` enables color only for a supported terminal and disables it when a
  non-empty `NO_COLOR` environment variable is present.
- `always` is an explicit application preference and emits color even when
  output is redirected or `NO_COLOR` is set.
- `never` emits complete plain-text output with no ANSI escapes.

Theme escape sequences are introduced only while rendering. Configuration,
UI state, validation, and visible-width calculations always contain plain
text, so colored and uncolored output have identical visible geometry.

## Display-user precedence

1. Valid `TERMUX_NEO_USER` runtime override
2. Valid configured `display_user`
3. Valid system/Termux username
4. `User`

## Missing files and keys

A missing settings file is valid and uses safe defaults. Missing optional keys
also use their defaults. An explicitly present key with an empty or invalid
value is rejected.

## Unknown keys and unsupported versions

Unknown keys fail closed. A file declaring an unsupported `schema_version`
also fails closed. Invalid settings never reach UI state, and rendering emits
no partial output.

## Migration rule

The Task 14 format had no `schema_version` and allowed only `display_user`.
Such a file is treated as legacy schema 0 and migrated in memory to schema 1;
the application never rewrites the user's file during startup.

All new settings require an explicit `schema_version=1`. Future schema changes
must add an explicit, sequential migration path and deterministic tests before
the new version is accepted. Unsupported future versions remain rejected.
