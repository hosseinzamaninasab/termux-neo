# Troubleshooting

Start with:

```bash
termux-neo --version
termux-neo --config
termux-neo --diagnose
```

Review diagnostic output before sharing it; it can contain local paths,
usernames, device details, local IP, battery state, and time.

## `termux-neo: command not found`

The stable launcher should be:

```text
$PREFIX/bin/termux-neo
```

Run `bash install.sh` from a complete trusted source tree or verified extracted
archive. If install reports an unowned existing command/runtime, stop and
inspect that path; do not force replacement.

## Rendering exits with no dashboard

Termux Neo assembles output before printing, so invalid settings or unsupported
geometry can fail without a partial UI.

- Run `termux-neo --diagnose`.
- Confirm the active path with `termux-neo --config`.
- Compare the file with [Configuration](configuration.md).
- Remove shell quotes, inline comments, duplicate/unknown keys, and unsupported
  values.
- Widen the terminal to at least 34 columns.

A missing settings file is valid and uses defaults. An invalid file is not
silently ignored.

## Network, IP, or battery is unavailable

`Offline`, `DOWN`, `Unavailable`, `OFF`, and `--` are safe fallbacks. Check
`OPTIONAL_COMMAND`, `NETWORK_SOURCE`, and `BATTERY_SOURCE` in diagnostics.
Optional commands may be absent or permission-restricted; raw probe errors are
suppressed.

Do not treat fixture success as proof that an unrecorded device or Termux
distribution is supported.

## Color is missing or unwanted

In `auto` mode, color is disabled when stdout is not a capable terminal or
`NO_COLOR` is non-empty.

- Save `color_mode=always` to explicitly enable the theme.
- Save `color_mode=never`, or run `termux-neo --no-color`, to disable ANSI.

Concrete colors depend on the terminal palette. Theme selection does not alter
visible geometry.

## Startup integration does not run

Startup integration is off by default and supports only interactive Bash.

1. Set `startup_integration=true`.
2. Run `termux-neo --startup`.
3. Start a new interactive Bash session.

To disable it, set the value to `false` and run the same command. Normal
install/update never enables it.

If the command reports incomplete or duplicated markers, preserve
`~/.bashrc`, inspect the two exact lines below, and resolve the malformed block
before retrying:

```text
# >>> termux-neo startup >>>
# <<< termux-neo startup <<<
```

The command refuses ambiguous marker state instead of editing it.

## Update is refused

Run updates from the complete target source tree:

```bash
bash update.sh
```

An older target is rejected. Only if the downgrade is deliberate:

```bash
bash update.sh --force-downgrade
```

Read the private combined report at:

```text
$HOME/.cache/termux-neo/update-reports/update-report.txt
```

If rollback cannot complete, the report prints retained recovery paths. Do not
delete them until the installed state is understood.

## Uninstall is refused

Default removal preserves settings:

```bash
bash uninstall.sh
```

Use `--remove-config` only to remove the exact settings file. The uninstaller
refuses symlinked/unowned paths and ambiguous startup markers.

Report:

```text
$HOME/.cache/termux-neo/uninstall-reports/uninstall-report.txt
```

## Checksum or manifest mismatch

Stop. Do not install, update, or run lifecycle scripts from that tree. Obtain
the archive and checksum again from the trusted project channel, verify the
external SHA-256 before extraction, then verify
`RELEASE_MANIFEST.sha256`.

A matching supplied checksum establishes integrity against that digest; it
does not authenticate an untrusted publisher.

See [Release Artifacts](release-artifacts.md),
[Security Review](security.md), and
[Known Limitations](known-limitations.md).
