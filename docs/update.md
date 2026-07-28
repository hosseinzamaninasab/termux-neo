# Safe Update and Configuration Migration

Run the updater from a complete source tree containing the target version:

```bash
bash update.sh
```

The installed copy does not need to be a Git checkout. The updater reads the
current version from the owned installation manifest and runtime, reads the
target version from the source tree, and compares them with SemVer ordering.
An older target is rejected before staging unless the downgrade is explicit:

```bash
bash update.sh --force-downgrade
```

Only these Task 20-owned paths can be replaced:

```text
$PREFIX/lib/termux-neo/
$PREFIX/bin/termux-neo
$HOME/.config/termux-neo/settings.conf
```

The target runtime and launcher are staged, syntax-checked, and executed with
`--version` before the installed copy is replaced. Runtime and launcher
rollback points remain available until the installed `--version`, `--config`,
and configuration smoke tests pass.

An existing schema v1 settings file is preserved byte-for-byte and retains its
mode. A supported legacy schema 0 file is validated through `src/config.sh`,
serialized as schema v1 in a same-directory staging file, and swapped only
inside the runtime/launcher/config transaction. Unsupported or invalid
settings stop the update before installed paths change. A missing settings
file remains missing.

The updater never invokes startup synchronization or edits shell startup
files. It writes the combined terminal output and errors to:

```text
$HOME/.cache/termux-neo/update-reports/update-report.txt
```

If rollback itself cannot complete, rollback storage is retained and its exact
paths are printed in the report.

Do not delete retained rollback storage until the installed state has been
reviewed. See [Troubleshooting](troubleshooting.md) for downgrade, report, and
recovery guidance; see [Configuration](configuration.md) for the schema
contract.
