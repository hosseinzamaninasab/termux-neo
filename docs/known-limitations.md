# Known Limitations

This document describes the frozen `0.9.0-beta` boundary. A limitation is not
an implied future commitment.

## Environment evidence

- Physical evidence covers one Samsung `SM-N920C` running Android `11`.
- Physical terminal widths recorded are `56` and `94` columns.
- Widths `34`, `56`, and `94` pass portable fixtures, but widths below `34`
  are unsupported.
- Other devices, Android releases, and specific Termux distribution channels
  are explicitly unverified.
- Only interactive Bash startup through `~/.bashrc` is supported. zsh, fish,
  and other startup files are not managed.

## Product behavior

- The dashboard renders once and exits; there is no live refresh, daemon,
  service, widget, notification, or background monitor.
- Only one CLI option is accepted per invocation.
- Only `neo` and `matrix` themes exist.
- Settings are limited to the five schema-v1 keys.
- The prompt-shaped view is display output; Termux Neo does not replace the
  shell prompt or modify `PS1`.
- Optional device/network/battery data may show safe fallbacks when commands,
  permissions, interfaces, or data files are unavailable.
- ANSI color in `auto` mode depends on terminal capability and `NO_COLOR`.
  Concrete shades vary with the terminal palette.

## Installation and release

- The lifecycle supports only the canonical Termux `HOME`/`PREFIX` layout.
- Existing unowned runtime or launcher paths are refused rather than replaced
  or deleted.
- Published SHA-256 files detect mismatch against the supplied digest but are
  not digital signatures and do not authenticate an untrusted publisher.
- The project does not make a root, Android-app, or Termux-application-fork
  claim.

## Evidence and performance

- CI and portable fixtures do not establish physical compatibility,
  orientation, distribution provenance, or device performance.
- Recorded startup measurements are specific to the reference device and
  measured software checkpoint; they are not a universal performance target.
- No additional real device was available at the public-beta checkpoint.

## Freeze

New commands, settings, themes, background behavior, supported shells,
installation paths, telemetry, and broader support claims are deferred while
[Feature Freeze](feature-freeze.md) is active.

See [Compatibility](compatibility.md) for the evidence matrix and
[Troubleshooting](troubleshooting.md) for safe fallback behavior.
