# Automated Quality Pipeline

Termux Neo uses one portable quality runner for local development and CI:

```bash
bash scripts/quality-check.sh
```

The runner fails closed when a test is not assigned to exactly one group. It
performs Bash syntax checks, `git diff --check`, ShellCheck error-level static
analysis when ShellCheck is available, and the complete test suite.

## Portable groups

| Group | Coverage |
| --- | --- |
| Unit | CLI, configuration, layout, colors, content, renderers, and UI |
| Fixtures | Compatibility, module fallbacks, and safe data modules |
| Integration | Diagnostics, render-once flow, startup, pipeline, security/failure-safety, and performance/stability contracts |
| Package | Reproducible artifact lifecycle and internal artifact smoke test |
| Lifecycle | Installer, updater, and uninstaller transactions |

`.github/workflows/quality.yml` runs the same command for pushes, pull
requests, and manual dispatch. The workflow has read-only repository
permission. It covers only logic that can run on a non-Android Bash host.

CI does not establish device compatibility and does not replace reference
device testing. A portable green result must never be recorded as device
evidence.

The portable stability gate can also be run directly:

```bash
bash scripts/performance-check.sh --self-test
```

It checks deterministic repeated rendering, child processes, background jobs,
and file descriptors with fixed inputs.
CI does not establish reference-device timing. The measured Samsung
`SM-N920C` before/after result and its
measurement-derived budget are recorded separately in
[`performance-baseline.md`](performance-baseline.md).

## Release artifact smoke verification

`scripts/package-release.sh` extracts every newly built archive, validates its
complete internal manifest, and runs the packaged
`scripts/smoke-release.sh`. The smoke script checks packaged syntax, the
version command, help, and one deterministic no-color render at width 56.
Failure prevents the archive and checksum from being published to the output
directory.

An extracted archive can repeat its own smoke verification:

```bash
bash scripts/smoke-release.sh
```

## Device-only verification checklist

Run these checks on the real reference environment. Record raw commands and
results separately from CI evidence.

- Confirm `getprop ro.product.manufacturer`, `getprop ro.product.model`, and
  `getprop ro.build.version.release` report `samsung`, `SM-N920C`, and `11`.
- Build the release archive and verify its external checksum and internal
  manifest on the device.
- Run the artifact's own smoke script on the device before installation.
- Exercise clean install, existing-settings update, and owned-only uninstall
  with the real Termux `$HOME` and `$PREFIX`.
- Verify live Wi-Fi/mobile/offline/VPN and battery
  charging/discharging/full/unavailable observations where those states can
  be produced safely.
- Verify portrait and landscape rendering in the real terminal; keep widths
  34, 56, and 94 covered by the portable fixtures.
- Verify optional startup integration only in interactive Bash and confirm
  disabling it restores the exact managed boundary.
- Confirm no daemon, refresh loop, background job, or persistent child process
  remains after render-once execution.

Unobserved device states remain unverified. Do not substitute fixtures, CI,
emulators, or guessed distribution details for real-device evidence.
