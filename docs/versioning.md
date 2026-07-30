# Versioning and Release Identity

Termux Neo uses [Semantic Versioning 2.0.0](https://semver.org/) for public
release identities. The repository-root `VERSION` file is the only committed
source of the current release version.

## Canonical value

`VERSION` must contain exactly one newline-terminated value. The project
release profile accepts:

```text
MAJOR.MINOR.PATCH
MAJOR.MINOR.PATCH-PRERELEASE
```

Core numbers cannot contain leading zeroes. Prerelease identifiers are
dot-separated ASCII alphanumeric/hyphen values; a numeric identifier cannot
contain a leading zero. The file does not include a leading `v` or SemVer build
metadata. Omitting build metadata keeps one precedence-bearing identity across
the updater, package name, tag, and release notes.

The current value is:

```text
1.0.0
```

## Derived identities

Every other release identity is derived from `VERSION`:

| Consumer | Required value for `1.0.0` |
| --- | --- |
| CLI | `termux-neo 1.0.0` |
| Package root | `termux-neo-1.0.0/` |
| Archive | `termux-neo-1.0.0.tar.gz` |
| Prospective Git tag | `v1.0.0` |
| Verified notes source | `docs/releases/1.0.0.md` |
| Published notes filename | `termux-neo-1.0.0-release-notes.md` |

The `v` prefix belongs only to a prospective Git tag. It is never written into
`VERSION`.

## Fail-closed synchronization

`scripts/package-release.sh` stops before publishing any artifact when:

- `VERSION` is not one strict project SemVer value;
- `termux-neo --version` does not report that value;
- the version-derived release-notes source is missing;
- release-note version, tag, archive, or publication metadata disagrees;
- `release/package-files.txt` is unsafe, unsorted, duplicated, stale, or
  contains a development-only path;
- staged or extracted manifest, layout, syntax, or smoke verification fails.

The archive name and prospective tag are derived in memory and are not
independent configuration inputs.

## Verified release notes

Release notes are reviewed repository content, not a summary generated from an
untrusted branch name or arbitrary Git range. The current source file records
only changes already established by the project test, security, performance,
beta, documentation, and packaging gates. The builder copies that exact file
to the versioned output and includes both the archive and release-note digests
in the external checksum file.

A version change must update `VERSION`, add the matching
`docs/releases/VERSION.md` source, update the package layout, and pass the
complete release-discipline test together. Editing only one consumer fails.

Prerelease versions require the exact publication field
`release candidate; GitHub prerelease only.` Stable versions require
`stable public release; GitHub release.` The builder derives which value is
valid from `VERSION`; release notes cannot select it independently.

## Publication boundary

Packaging does not create a Git tag, GitHub release, or remote upload. The
immutable annotated `v1.0.0-rc.1` tag and prerelease remain the verified
candidate checkpoint. The stable transaction may create annotated `v1.0.0`
only after the complete quality, artifact, defect, anonymous-public, and
reference-device gates pass. The stable commit and tag must be pushed
atomically, and the non-prerelease GitHub release's three public assets must
match the locally verified archive, release notes, and checksum byte-for-byte.
