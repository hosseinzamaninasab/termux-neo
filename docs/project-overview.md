# Project Overview

Termux Neo is a small terminal dashboard with a deliberately narrow product
boundary: collect safe local state, render it once, and exit.

## What it shows

Each successful default invocation produces three coordinated views:

1. **Dashboard** — display user, device, Android system, network type, and
   local IP.
2. **Status** — network, VPN, battery, and time.
3. **Prompt view** — the same resolved display user and a home-relative
   working-directory path.

The UI adapts to terminal width, truncates untrusted values before layout, and
adds ANSI color only after visible geometry is complete. Optional device probes
fall back to stable values instead of leaking raw errors.

## What it is not

Termux Neo is not:

- a replacement shell prompt or `PS1` framework;
- a daemon, live monitor, background service, or refresh loop;
- a root tool;
- a telemetry or network client;
- a Termux application fork or Android package;
- a promise of compatibility with unrecorded devices or distributions.

Optional startup integration adds one managed command block to interactive
Bash. The command still renders once and exits.

## Renderer captures

### `neo`

![The released Termux Neo renderer using the neo theme](assets/dashboard-neo.svg)

### `matrix`

![The released Termux Neo renderer using the matrix theme](assets/dashboard-matrix.svg)

These SVGs use the same deterministic input set and the exact visible
transcript emitted by the frozen `0.9.0-beta` renderer at 56 columns. Theme
roles change color only; text and geometry remain identical. The fixture uses
the reserved documentation address `192.0.2.10`.

The images demonstrate renderer behavior, not a second device result. Physical
evidence remains limited to the environment recorded in
[Compatibility](compatibility.md) and the
[Public Beta Field Report](beta-field-report.md).

## Design priorities

- **Bounded work:** all probes and rendering complete in the foreground.
- **Safe fallbacks:** unavailable optional sources do not break ordinary
  rendering.
- **Strict input boundaries:** settings and themes are parsed as allowlisted
  data, never evaluated as shell code.
- **Atomic lifecycle operations:** install, update, and uninstall stage and
  validate changes with rollback points.
- **Evidence-scoped claims:** portable fixtures, CI, and physical device
  records are never conflated.

See [Architecture](architecture.md) for component ownership and
[Known limitations](known-limitations.md) for the current boundary.
