# Termux Neo

Termux Neo is a modular, render-once CLI dashboard for Termux. It does not
require root, replace the shell prompt, start a daemon, or run a refresh loop.

## Install

From a complete source tree:

```bash
bash install.sh
```

The production layout, rollback behavior, configuration-preservation contract,
and supported paths are documented in [docs/installation.md](docs/installation.md).

After installation:

```bash
termux-neo --help
termux-neo --diagnose
```

User settings are stored at:

```text
$HOME/.config/termux-neo/settings.conf
```

Optional Bash startup integration remains disabled until it is explicitly
enabled in that settings file and synchronized with `termux-neo --startup`.

## Update

Run the updater from a complete source tree for the target version:

```bash
bash update.sh
```

The updater does not require the installed runtime to be a Git checkout. It
validates and stages the target runtime before replacement, preserves current
schema settings byte-for-byte, migrates supported legacy settings through the
configuration boundary, and restores runtime, launcher, and settings on
failure. Downgrades are rejected unless `--force-downgrade` is explicit.

The complete update contract and report location are documented in
[docs/update.md](docs/update.md).
