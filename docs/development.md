# Development and Testing

Termux Neo is a Bash project. Runtime development should be done from a Git
working tree; packaged source trees intentionally omit Git metadata and tests.

## Prerequisites

The canonical pipeline requires Bash, Git, and the standard command-line tools
checked by `scripts/quality-check.sh`. ShellCheck is optional: when available,
error-level findings are enforced; otherwise that phase is reported as
skipped.

Android-only commands are not required for portable tests. Deterministic
fixtures replace optional `getprop`, network, battery, and terminal inputs.

## Canonical commands

List all assigned tests:

```bash
bash scripts/quality-check.sh --list
```

Run syntax, whitespace/static checks, and all 25 tests:

```bash
bash scripts/quality-check.sh
```

Run one focused test:

```bash
bash tests/test_cli.sh
bash tests/test_documentation.sh
```

Run portable packaged checks:

```bash
bash scripts/performance-check.sh --self-test
bash scripts/beta-field-test.sh --self-test
```

Build and verify a local artifact:

```bash
bash scripts/package-release.sh
```

The default artifact directory is `dist/`. The builder normalizes archive
metadata, generates the internal manifest, extracts the result, and runs the
packaged smoke test before publishing the archive/checksum pair.

## Test groups

| Group | Purpose |
| --- | --- |
| Unit | CLI, settings, layout, colors, content, and renderer primitives |
| Fixtures | Device/network/battery fallbacks and portable compatibility |
| Integration | Complete runtime, diagnostics, startup, security, performance, beta, documentation, and registry contracts |
| Package | Reproducible extracted-artifact lifecycle |
| Lifecycle | Transactional install, update, and uninstall |

Every `tests/test_*.sh` file must be assigned to exactly one group. The
registry fails on unassigned files and verifies a canonical total of 25.

## Evidence levels

Portable tests establish deterministic behavior only. They do not establish:

- physical device or Android compatibility;
- a Termux distribution-channel claim;
- physical terminal orientation;
- reference-device startup timing.

Those claims require the strict device workflows recorded in
[Compatibility](compatibility.md),
[Performance](performance.md), and
[Beta Testing](beta-testing.md).

## Release-tree boundary

The package includes lifecycle scripts, runtime source, configuration examples,
all public docs/assets, and the smoke/performance/beta tools. It excludes
`.git`, `tests/`, CI configuration, and unrelated development files.

See [Release Artifacts](release-artifacts.md) for exact verification commands
and [Architecture](architecture.md) for component ownership.
