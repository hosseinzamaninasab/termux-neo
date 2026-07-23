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

For version `0.5.0-beta`, the command creates:

```text
termux-neo-0.5.0-beta.tar.gz
termux-neo-0.5.0-beta.tar.gz.sha256
termux-neo-0.5.0-beta-release-report.txt
```

The archive is reproducible: file order, timestamps, ownership metadata, and
gzip metadata are normalized. The report is mode `0600`; the archive and
checksum file are mode `0644`. Existing artifacts are never overwritten.
Before publication, the builder extracts the archive, validates its internal
manifest, and runs the packaged smoke verification. A smoke failure leaves no
archive or checksum in the output directory.

## Verify and install a downloaded archive

Place both published files in the fixed download directory, then run:

```bash
cd "$HOME/storage/downloads/Telegram"
sha256sum -c termux-neo-0.5.0-beta.tar.gz.sha256
tar --extract --gzip --same-permissions \
    --file termux-neo-0.5.0-beta.tar.gz
cd termux-neo-0.5.0-beta
sha256sum -c RELEASE_MANIFEST.sha256
bash scripts/smoke-release.sh
bash install.sh
```

The external checksum authenticates the archive bytes. The internal
`RELEASE_MANIFEST.sha256` covers every packaged file except itself. The
installer, updater, and uninstaller also validate that manifest automatically
before any installed path changes. Unsafe, duplicate, missing, unlisted,
symlinked, or checksum-mismatched entries fail closed.

The packaged smoke script checks runtime syntax, version/help dispatch, and a
deterministic no-color render. It reads the extracted tree and uses a private
temporary home; it does not install or modify user settings.

The extracted tree contains no `.git` directory and does not require Git.
It remains a complete local lifecycle source:

```bash
bash update.sh
bash uninstall.sh
```

User settings retain the same preservation and migration guarantees documented
for source-tree installation. Startup integration remains explicit and is not
enabled by packaging or installation.
