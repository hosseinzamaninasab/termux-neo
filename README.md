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
