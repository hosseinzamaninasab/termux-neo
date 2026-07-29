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
0.9.0-beta
```

## Derived identities

Every other release identity is derived from `VERSION`:

| Consumer | Required value for `0.9.0-beta` |
| --- | --- |
| CLI | `termux-neo 0.9.0-beta` |
| Package root | `termux-neo-0.9.0-beta/` |
| Archive | `termux-neo-0.9.0-beta.tar.gz` |
| Prospective Git tag | `v0.9.0-beta` |
| Verified notes source | `docs/releases/0.9.0-beta.md` |
| Published notes filename | `termux-neo-0.9.0-beta-release-notes.md` |

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

A future version change must update `VERSION`, add the matching
`docs/releases/VERSION.md` source, update the package layout, and pass the
complete release-discipline test together. Editing only one consumer fails.

## Publication boundary

Packaging does not create a Git tag, GitHub release, or remote upload. At this
checkpoint `v0.9.0-beta` is only the derived prospective tag. Creation and
publication of `v1.0.0-rc.1` remain a separate release-candidate task.
