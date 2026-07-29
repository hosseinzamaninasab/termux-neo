# Architecture

Termux Neo separates command dispatch, validated state collection, layout,
rendering, lifecycle transactions, and release verification.

## Runtime flow

```text
bin/termux-neo
  -> src/main.sh
     -> src/cli.sh
     -> src/config.sh + src/colors.sh
     -> src/modules/*.sh
     -> src/layout.sh
     -> Dashboard + Status + Prompt renderers
     -> stdout, then exit
```

`bin/termux-neo` resolves the project root and executes `src/main.sh`.
`src/main.sh` loads the runtime boundaries, then dispatches exactly one CLI
route.

For a normal render:

1. `src/config.sh` parses schema-v1 settings into safe defaults or validated
   values.
2. `src/colors.sh` parses one built-in theme and decides whether ANSI is
   enabled.
3. Device, network, VPN, battery, date/time, and working-directory values are
   collected and cleaned.
4. `src/layout.sh` calculates responsive geometry before output begins.
5. `src/dashboard.sh`, `src/status.sh`, and `src/prompt.sh` build one complete
   output value.
6. The result is printed once. No render loop or persistent child remains.

Network-interface and battery-source selections are cached only for one render
or diagnostic cycle and then cleared. IPC-backed battery probes are bounded by
the timeout policy in `src/modules/common.sh`.

## Ownership map

| Boundary | Owner |
| --- | --- |
| CLI grammar and statuses | `src/cli.sh` |
| Settings schema and migration | `src/config.sh` |
| Theme parsing and ANSI roles | `src/colors.sh`, `src/themes/*.theme` |
| Device data and safe fallbacks | `src/modules/*.sh` |
| Width, truncation, status, and prompt geometry | `src/layout.sh` |
| Visible UI | `src/dashboard.sh`, `src/status.sh`, `src/prompt.sh` |
| Explicit Bash startup hook | `src/startup_integration.sh` |
| Privacy-safe report | `src/diagnostics.sh` |
| Installed-file manifest verification | `src/release.sh` |

## Lifecycle boundary

The source-root scripts are the only production lifecycle owners:

- `install.sh` stages and installs the runtime, launcher, and first settings
  file.
- `update.sh` validates SemVer direction, stages the target, preserves or
  migrates settings, and swaps owned paths transactionally.
- `uninstall.sh` removes only owned runtime/launcher paths and optionally the
  exact settings file.

All three validate the canonical Termux `HOME`/`PREFIX` relationship and refuse
unsafe, symlinked, or unowned targets. Update and uninstall write private
reports. Startup integration remains a separate explicit command boundary.

## Release boundary

`VERSION` owns the release identity. `scripts/package-release.sh` derives the
CLI expectation, package/archive names, prospective tag, and release-notes
path from that one value and fails closed when any version-bearing input
disagrees.

`release/package-files.txt` is the reviewed package allowlist. The builder
copies exactly that layout, creates `RELEASE_MANIFEST.sha256`, extracts the
normalized archive, verifies its layout and manifest again, and runs
`scripts/smoke-release.sh` before publication. The external checksum covers
both the archive and the exact versioned release-notes output.

Development tests and Git metadata are excluded. The extracted artifact can
install, update, uninstall, reproduce itself, and run its portable smoke,
performance, and beta checks without Git.

## Quality boundary

`scripts/quality-check.sh` is the single registry and runner for all 26 test
files. Tests are assigned to unit, fixture, integration, package, or lifecycle
groups. An unassigned test fails the registry.

See [Development](development.md) for commands and
[Security Review](security.md) for the trust model.
