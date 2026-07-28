# Security and Failure-Safety Review

Termux Neo runs entirely as the current Termux user. It does not request root,
open a network connection, install a daemon, or create a persistent child
process. This document records the security boundary reviewed for the
`0.9.0-beta` public-beta checkpoint.

## Trust model

The project protects against malformed settings, unsafe filesystem targets,
partial lifecycle operations, hostile device-command output, and accidental
replacement or deletion of unrelated files.

The following remain trust requirements:

- Obtain release archives and their published checksum from a trusted project
  channel.
- Do not run `install.sh`, `update.sh`, or any other script from an untrusted
  source tree.
- A process already able to modify files as the same Termux user is outside
  the privilege boundary. Ownership markers reduce accidental damage; they
  are not authentication against a hostile same-UID process.
- The published SHA-256 file verifies archive integrity against the supplied
  digest. It is not a digital signature and does not authenticate an
  untrusted publisher by itself.

## Parsed data and command boundaries

- Settings are parsed as a strict, versioned `KEY=value` allowlist. They are
  never sourced or evaluated as shell code.
- Built-in theme files are parsed as seven exact quoted assignments. Unknown,
  duplicate, missing, symlinked, non-SGR, or command-like content fails
  closed. Theme files are never sourced.
- CLI routes and values are allowlisted. No user value is passed through
  `eval`, `bash -c`, or an unquoted command expansion.
- Startup command paths are rendered with Bash `%q` quoting and are accepted
  only as normalized absolute paths.
- Network interface names are validated before they are passed to optional
  commands. Fixture data roots must be normalized absolute non-symlink
  directories.

## Filesystem and lifecycle boundaries

- `HOME` and `PREFIX` must be normalized absolute non-root paths with no `.`
  or `..` component. `PREFIX` must be the Termux-owned sibling of `HOME`.
- Installer and updater source trees reject every symlink in the files they
  copy, including nested runtime files.
- Existing settings, runtime, launcher, startup, report, and release-output
  targets reject symbolic links at their ownership boundaries.
- Runtime ownership requires the complete six-line install manifest. Launcher
  ownership requires the complete generated seven-line launcher, including
  the exact runtime, command, config, and Bash paths.
- Startup backup directories are created mode `0700` and every path component
  is checked before use. `mktemp` owns all transaction names.
- Update, uninstall, and release reports are created under a restrictive
  umask, forced to mode `0600`, and never follow an existing report symlink.
  Their `tee` process is closed and waited for before the command exits.
- Recursive removal uses quoted, explicit paths after lexical, ownership, and
  generated-name checks. No user-controlled glob is used as a delete target.
- Install, update, and uninstall keep same-parent rollback storage until smoke
  verification or removal commit. A pre-commit failure restores the prior
  state; incomplete recovery preserves and reports the recovery location.

## Terminal output and diagnostics

Collected values lose line breaks, all terminal control characters, the
internal `|` delimiter, and the visible `•` delimiter before entering UI
state. Invalid fixed-format values use safe fallbacks. ANSI is added only by
the color renderer after numeric SGR validation.

Optional device probes suppress their own raw stderr. Application and usage
errors still use the documented stderr boundary. Render-once output is
assembled before printing, so a renderer failure emits no partial dashboard.
The two IPC-backed battery probes run through a foreground timeout with a
kill-after boundary; timeout failure is silent and continues to the existing
sysfs or unavailable fallback.

Diagnostics are explicit and bounded; they do not dump the environment or
search for secrets. A diagnostic report does include the selected config and
installation paths, display/system user, device model, Android version, local
IP, network state, battery state, time, and optional-command availability.
Review those fields before sharing a report publicly.

## Release integrity

The release chain is:

1. Build a normalized archive in private temporary storage.
2. Verify the complete internal `RELEASE_MANIFEST.sha256`.
3. Extract the archive and repeat internal verification.
4. Run syntax, CLI, and deterministic render smoke checks from the extracted
   archive.
5. Generate the external archive SHA-256 file.
6. Publish the archive and checksum; if either move fails, remove any
   half-published counterpart.

Verify the external checksum before extraction, then verify the internal
manifest before installation. Detailed commands are in
[release-artifacts.md](release-artifacts.md).

## Exit and stderr contract

| Interface | Success | Ordinary failure | Invalid usage | Signals |
| --- | ---: | ---: | ---: | ---: |
| `termux-neo` | `0` | `1` | `2` | shell default |
| install/update/uninstall | `0` | `1` | `1` | `129`, `130`, `143` |
| package and packaged smoke | `0` | `1` | `1` | `129`, `130`, `143` |
| beta field tool | `0` | `1` | `2` | `129`, `130`, `143` |
| quality runner | `0` | `1` | `2` | shell default |

Optional probe failures become safe values and are not application failures.
Configuration, ownership, integrity, layout, renderer, transaction, and
report-write failures remain nonzero.

## Review evidence

`tests/test_security.sh` exercises command-like settings and themes, symlink
refusal, traversal rejection, strict ownership, private backup/report modes,
control and delimiter injection, stderr containment, diagnostic privacy,
exit-status behavior, checksum tampering, and partial publication cleanup.

The existing configuration, color, module, diagnostics, integration,
installer, updater, uninstaller, artifact, compatibility, and quality tests
remain part of the same canonical pipeline:

```bash
bash scripts/quality-check.sh
```

No critical or release-blocking defect is knowingly left open by this review.
Unverified environments and the absence of publisher signatures remain
explicit limitations rather than implied guarantees.

The public-beta defect counts are maintained in
[beta-issues.md](beta-issues.md). Security fixes remain explicitly allowed
while the [Feature Freeze](feature-freeze.md) is active.
