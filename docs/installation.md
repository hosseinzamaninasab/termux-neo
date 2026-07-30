# Production Installation

The stable `v1.0.0` archive is public at:

```text
https://github.com/hosseinzamaninasab/termux-neo/releases/tag/v1.0.0
```

Download the archive, checksum, and release notes from that page. Exact
anonymous download, checksum, extraction, and manifest commands are in
[release-artifacts.md](release-artifacts.md).

Run the installer from the verified, extracted release archive or from a
complete Termux Neo source tree:

```bash
bash install.sh
```

A published archive does not require Git, GitHub authentication, root, or
branch selection. Verify its
external checksum and complete internal file manifest before installation.
Exact local-archive commands and the reproducible packaging command are in
[release-artifacts.md](release-artifacts.md). When the internal manifest is
present, the installer validates it again automatically before any installed
path changes.

The installer writes only these owned locations:

```text
$PREFIX/lib/termux-neo/
$PREFIX/bin/termux-neo
$HOME/.config/termux-neo/settings.conf
```

The runtime and stable launcher are staged and validated before replacement.
If any replacement or smoke test fails, the previous runtime and launcher are
restored. An existing settings file is never replaced. On first installation,
the settings example is copied to the user settings path with mode `0600`.

The canonical Termux relationship is required: `$PREFIX` must be the
Termux-owned `usr` sibling of `$HOME`. Symlinked, unsafe, or unowned existing
runtime/launcher targets are refused.

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
`bash update.sh`; see [update.md](update.md).

Safe removal is performed from a complete source tree with
`bash uninstall.sh`; see [uninstallation.md](uninstallation.md). User settings
are preserved unless `--remove-config` is explicit.

After installation, see [Configuration](configuration.md),
[CLI](cli.md), and [Troubleshooting](troubleshooting.md). The complete
installed/release trust boundary is in [Security Review](security.md).
