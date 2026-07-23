# Termux Neo

Termux Neo is a modular, render-once CLI dashboard for Termux. It does not
require root, replace the shell prompt, start a daemon, or run a refresh loop.

## Install

From a complete source tree or a verified extracted release archive:

```bash
bash install.sh
```

The production layout, rollback behavior, configuration-preservation contract,
and supported paths are documented in [docs/installation.md](docs/installation.md).
Published archives install without Git or branch state. Checksum verification,
the internal file manifest, exact local-archive commands, and the reproducible
packaging command are documented in
[docs/release-artifacts.md](docs/release-artifacts.md).

Verified and unverified environment boundaries, responsive widths, data-source
fallback scenarios, and the interactive-shell scope are recorded in
[docs/compatibility.md](docs/compatibility.md).

The portable local/CI quality command, test groups, release-artifact smoke
boundary, and device-only verification checklist are documented in
[docs/quality.md](docs/quality.md).

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

## Uninstall

Remove the owned runtime, stable launcher, and optional Bash startup block
while preserving user settings:

```bash
bash uninstall.sh
```

Configuration removal is a separate, explicit action:

```bash
bash uninstall.sh --remove-config
```

The uninstaller validates ownership before changing any installed path, keeps
rollback points until removal commits, and never restores an ambiguous
historical shell backup over later user edits. The complete contract and
report location are documented in
[docs/uninstallation.md](docs/uninstallation.md).
