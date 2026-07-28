# Safe Uninstallation

Run the uninstaller from a complete Termux Neo source tree:

```bash
bash uninstall.sh
```

The default removes only the owned runtime and stable launcher:

```text
$PREFIX/lib/termux-neo/
$PREFIX/bin/termux-neo
```

The user settings file remains in place:

```text
$HOME/.config/termux-neo/settings.conf
```

Remove that exact file only with explicit consent:

```bash
bash uninstall.sh --remove-config
```

Before changing anything, the uninstaller validates the Termux `HOME` and
`PREFIX` relationship, the complete runtime ownership manifest, the launcher
marker, the optional settings target, and the Bash startup markers. Unknown
runtime or launcher paths, symlinks, duplicate markers, and incomplete markers
fail closed.

The managed Bash startup block is removed through the existing startup
boundary exactly once. Unrelated `.bashrc` content is retained, and the
pre-edit file is backed up. Historical backups are never selected
automatically because later user edits may make them stale.

Runtime, launcher, and explicitly selected settings are first moved to exact
same-parent rollback locations. If removal fails before commit, those paths
and the pre-edit Bash startup file are restored. Recursive deletion is allowed
only for the generated runtime rollback location after its ownership manifest
has been revalidated.

Repeated execution is safe: missing owned paths and an absent startup block
are reported as already absent. The combined terminal output and errors are
saved with mode `0600` at:

```text
$HOME/.cache/termux-neo/uninstall-reports/uninstall-report.txt
```

If the command refuses an unowned path or malformed startup markers, do not
bypass the guard. Preserve the report and follow
[Troubleshooting](troubleshooting.md). Installation ownership is described in
[Installation](installation.md).
