# Themes and Color

Termux Neo has exactly two built-in themes. Themes change semantic ANSI roles;
they do not change text, state, width, truncation, or layout.

## Preview

| `neo` | `matrix` |
| --- | --- |
| ![neo renderer capture](assets/dashboard-neo.svg) | ![matrix renderer capture](assets/dashboard-matrix.svg) |

The images are renderer-derived documentation fixtures at 56 columns. They are
not extra physical-device evidence. Concrete shades are representative because
each terminal controls its ANSI palette.

## Select a theme

Persist a theme in the settings file:

```ini
schema_version=1
display_user=Zoro
theme=matrix
color_mode=auto
startup_integration=false
```

Or override one render without saving:

```bash
termux-neo --theme neo
termux-neo --theme matrix
```

Any other name fails with CLI status `2`.

## Semantic palettes

The files under `src/themes/` contain seven strictly parsed assignments:

| Role | `neo` SGR | `matrix` SGR |
| --- | ---: | ---: |
| Border | `36` | `32` |
| Title | `1;35` | `1;32` |
| Label | `1;36` | `1;32` |
| Value | `37` | `37` |
| Status | `36` | `32` |
| Prompt | `1;35` | `1;32` |

Theme files are application data. Unknown keys, duplicate/missing roles,
symlinks, non-numeric SGR values, and command-like content fail closed; the
files are never sourced as shell code.

## Color modes

| Mode | Behavior |
| --- | --- |
| `auto` | Color only on a capable terminal with empty `NO_COLOR` |
| `always` | Explicitly emit the selected palette, even when redirected |
| `never` | Emit complete plain text with no ANSI escapes |

Disable color for one invocation:

```bash
termux-neo --no-color
```

Runtime theme/color overrides never rewrite settings. See
[Configuration](configuration.md) for the full schema.
