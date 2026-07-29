# Release Artifacts

Termux Neo release archives are complete, versioned source trees. They install,
update, and uninstall without a Git checkout or branch state.

## Build a local release

From a complete source tree:

```bash
bash scripts/package-release.sh
```

The default output directory is `dist/`. An explicit local output directory is
also accepted:

```bash
bash scripts/package-release.sh "$HOME/storage/downloads/Telegram"
```

For version `0.9.0-beta`, the command creates:

```text
termux-neo-0.9.0-beta.tar.gz
termux-neo-0.9.0-beta.tar.gz.sha256
termux-neo-0.9.0-beta-release-notes.md
termux-neo-0.9.0-beta-release-report.txt
```

`VERSION` is the canonical release identity. The builder requires the CLI,
archive/root name, prospective `v0.9.0-beta` tag, and
`docs/releases/0.9.0-beta.md` metadata to agree before staging. See
[Versioning](versioning.md) for the complete fail-closed contract.

The archive is reproducible: package layout, file order, timestamps, ownership
metadata, permissions, and gzip metadata are normalized. The report is mode
`0600`; the archive, notes, and checksum file are mode `0644`. Existing outputs
are never overwritten.

`release/package-files.txt` is the exact reviewed allowlist. Development-only
tests, CI/Git metadata, and `scripts/quality-check.sh` cannot enter the archive.
Before publication, the builder compares the staged tree to that allowlist,
extracts the archive, validates its internal manifest, and runs the packaged
smoke verification.

The external checksum file contains two entries in deterministic order: the
archive and the exact versioned release notes. A metadata, layout, manifest,
smoke, checksum, or final-move failure leaves no archive, notes, or checksum in
the output directory.

## Verify and install a downloaded archive

Place the archive, release notes, and checksum file in the fixed download
directory, then run:

```bash
cd "$HOME/storage/downloads/Telegram"
sha256sum -c termux-neo-0.9.0-beta.tar.gz.sha256
extract_parent="$(
    mktemp -d "$HOME/storage/downloads/Telegram/termux-neo-extract.XXXXXX"
)"
tar --extract --gzip --same-permissions \
    --file termux-neo-0.9.0-beta.tar.gz \
    --directory "$extract_parent"
cd "$extract_parent/termux-neo-0.9.0-beta"
sha256sum -c RELEASE_MANIFEST.sha256
bash scripts/smoke-release.sh
bash scripts/beta-field-test.sh --self-test
bash install.sh
```

The external checksum verifies archive integrity against the supplied digest;
it also verifies the release-note bytes. It is not a digital signature and
cannot authenticate an untrusted publisher by itself. Obtain all release files
from the trusted project release channel and verify the checksum before
extraction. The internal
`RELEASE_MANIFEST.sha256` covers every packaged file except itself. The
installer, updater, and uninstaller also validate that manifest automatically
before any installed path changes. Unsafe, duplicate, missing, unlisted,
symlinked, or checksum-mismatched entries fail closed.

The builder refuses symlinked source/output boundaries and a symlinked report
target. Archive, release-note, and checksum publication is treated as one
failure-safe boundary: if any final move fails, every half-published
counterpart is removed.

The packaged smoke script checks runtime syntax, version/help dispatch, and a
deterministic no-color render. It reads the extracted tree and uses a private
temporary home; it does not install or modify user settings.

The packaged performance script checks repeated-render stability. The packaged
beta script adds an isolated ten-scenario lifecycle and fallback matrix.
`--self-test` is portable; `--record` additionally requires an interactive real
Termux terminal and produces redacted device evidence.

The extracted tree contains no `.git` directory and does not require Git.
It remains a complete local lifecycle source:

```bash
bash update.sh
bash uninstall.sh
```

User settings retain the same preservation and migration guarantees documented
for source-tree installation. Startup integration remains explicit and is not
enabled by packaging or installation.

## Clean-checkout reproducibility

The release-discipline regression creates two clean checkouts of the same
candidate snapshot with different branch states. Both must produce identical
archive, release-note, checksum, and file-layout bytes. The builder reads no
branch name, commit description, or tag when producing artifacts.

Packaging only reports the derived prospective tag. It never runs `git tag`,
creates a GitHub release, pushes, or uploads an artifact.
