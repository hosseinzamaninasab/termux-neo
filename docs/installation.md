# Production Installation

Run the installer from a complete Termux Neo source tree:

```bash
bash install.sh
```

The installer does not require root and writes only these owned locations:

```text
$PREFIX/lib/termux-neo/
$PREFIX/bin/termux-neo
$HOME/.config/termux-neo/settings.conf
```

The runtime and stable launcher are staged and validated before replacement.
If any replacement or smoke test fails, the previous runtime and launcher are
restored. An existing settings file is never replaced. On first installation,
the settings example is copied to the user settings path with mode `0600`.

Running the installer again is safe. It replaces only paths carrying the
Termux Neo ownership markers, preserves user settings byte-for-byte, validates
the installed `--version` and `--config` routes, and reports every lasting path
change.

The installer never edits `.bashrc` or activates startup integration. That
feature remains an explicit user action through the saved setting and:

```bash
termux-neo --startup
```

Updates are performed separately from a complete target source tree with
`bash update.sh`; see [update.md](update.md). Uninstall behavior remains owned
by its later lifecycle task.
