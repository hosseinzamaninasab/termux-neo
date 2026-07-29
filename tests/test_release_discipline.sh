#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="$HOME/.cache/termux-neo"
fixture="$CACHE_DIR/test-release-discipline-$$"
candidate="$fixture/candidate"
checkout_a="$fixture/checkout-a"
checkout_b="$fixture/checkout-b"
output_a="$fixture/output-a"
output_b="$fixture/output-b"
extract_root="$fixture/extract"
fake_bin="$fixture/fake-bin"
archive_name="termux-neo-0.9.0-beta.tar.gz"
checksum_name="$archive_name.sha256"
notes_name="termux-neo-0.9.0-beta-release-notes.md"
report_name="termux-neo-0.9.0-beta-release-report.txt"
package_root="$extract_root/termux-neo-0.9.0-beta"

mkdir -p "$fixture" "$candidate" "$fake_bin"
trap 'rm -rf "$fixture"' EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

for required_command in \
    bash cmp cp dirname find git grep mkdir sed sha256sum sort tar wc
do
    command -v "$required_command" >/dev/null 2>&1 ||
        fail "required command is unavailable: $required_command"
done

cd "$PROJECT_ROOT"

[[ "$(cat VERSION)" == "0.9.0-beta" ]] ||
    fail "release discipline changed the frozen VERSION"
grep -Fqx 'ACTIVE — 0.9.0-beta' docs/feature-freeze.md ||
    fail "release discipline changed the active Feature Freeze"
[[ -z "$(git tag --list v0.9.0-beta)" ]] ||
    fail "the prospective beta tag already exists"
[[ -z "$(git tag --list v1.0.0-rc.1)" ]] ||
    fail "the deferred release-candidate tag already exists"

# Capture the exact candidate worktree, including new Task 30 paths, into one
# temporary commit. Two clones of that commit are then genuine clean checkouts.
candidate_paths="$fixture/candidate-paths.bin"
{
    git ls-files -z
    git ls-files --others --exclude-standard -z
} | LC_ALL=C sort -z -u > "$candidate_paths"

while IFS= read -r -d '' relative_path; do
    [[ -f "$PROJECT_ROOT/$relative_path" &&
       ! -L "$PROJECT_ROOT/$relative_path" ]] ||
        fail "candidate path is not a regular file: $relative_path"
    mkdir -p "$candidate/$(dirname "$relative_path")"
    cp -p "$PROJECT_ROOT/$relative_path" "$candidate/$relative_path"
done < "$candidate_paths"

git -C "$candidate" init -q
git -C "$candidate" config user.name "Termux Neo Test"
git -C "$candidate" config user.email "termux-neo-test@example.invalid"
git -C "$candidate" add --all
git -C "$candidate" commit -qm "test: candidate release snapshot"

git clone -q --no-hardlinks "$candidate" "$checkout_a"
git clone -q --no-hardlinks "$candidate" "$checkout_b"
git -C "$checkout_a" checkout -q --detach
git -C "$checkout_b" checkout -qb alternate-release-context

[[ -z "$(git -C "$checkout_a" status --short)" &&
   -z "$(git -C "$checkout_b" status --short)" ]] ||
    fail "candidate release checkouts are not clean"
[[ -z "$(git -C "$checkout_a" symbolic-ref -q --short HEAD || true)" ]] ||
    fail "first release checkout is not detached"
[[ "$(git -C "$checkout_b" symbolic-ref --short HEAD)" == \
   "alternate-release-context" ]] ||
    fail "second release checkout does not have the alternate branch state"

{
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' \
        'printf "Git must not be used while building release outputs\n" >&2'
    printf '%s\n' 'exit 97'
} > "$fake_bin/git"
chmod 755 "$fake_bin/git"
test_path="$fake_bin:$PATH"

PATH="$test_path" \
    bash "$checkout_a/scripts/package-release.sh" "$output_a" \
    > "$fixture/package-a.stdout" 2> "$fixture/package-a.stderr" ||
    fail "first clean-checkout package build failed"
PATH="$test_path" \
    bash "$checkout_b/scripts/package-release.sh" "$output_b" \
    > "$fixture/package-b.stdout" 2> "$fixture/package-b.stderr" ||
    fail "second clean-checkout package build failed"

[[ ! -s "$fixture/package-a.stderr" &&
   ! -s "$fixture/package-b.stderr" ]] ||
    fail "clean-checkout package build produced stderr"

for output_dir in "$output_a" "$output_b"; do
    for output_name in \
        "$archive_name" "$checksum_name" "$notes_name" "$report_name"
    do
        [[ -f "$output_dir/$output_name" &&
           ! -L "$output_dir/$output_name" ]] ||
            fail "clean-checkout output is missing: $output_name"
    done
    [[ "$(wc -l < "$output_dir/$checksum_name")" == "2" ]] ||
        fail "external checksum does not cover exactly two release files"
    (
        cd "$output_dir"
        sha256sum -c "$checksum_name"
    ) > "$fixture/checksum.stdout" ||
        fail "clean-checkout external checksum verification failed"
    grep -Fqx 'version: 0.9.0-beta' "$output_dir/$report_name" ||
        fail "release report version is inconsistent"
    grep -Fqx 'prospective tag: v0.9.0-beta' \
        "$output_dir/$report_name" ||
        fail "release report prospective tag is inconsistent"
done

cmp -s "$output_a/$archive_name" "$output_b/$archive_name" ||
    fail "two clean checkouts produced different archive bytes"
cmp -s "$output_a/$checksum_name" "$output_b/$checksum_name" ||
    fail "two clean checkouts produced different checksum bytes"
cmp -s "$output_a/$notes_name" "$output_b/$notes_name" ||
    fail "two clean checkouts produced different release-note bytes"
cmp -s "$checkout_a/docs/releases/0.9.0-beta.md" \
    "$output_a/$notes_name" ||
    fail "generated release notes differ from their verified source"

tar -tzf "$output_a/$archive_name" > "$fixture/archive.list"
grep -v '/$' "$fixture/archive.list" |
    sed 's|^termux-neo-0.9.0-beta/||' |
    LC_ALL=C sort > "$fixture/archive-files.list"
{
    cat "$checkout_a/release/package-files.txt"
    printf '%s\n' RELEASE_MANIFEST.sha256
} | LC_ALL=C sort > "$fixture/expected-files.list"
cmp -s "$fixture/expected-files.list" "$fixture/archive-files.list" ||
    fail "clean-checkout archive layout differs from the reviewed allowlist"

if grep -Eq '(^|/)(\.git|\.github|tests)(/|$)|scripts/quality-check\.sh$' \
    "$fixture/archive.list"
then
    fail "clean-checkout archive contains development-only content"
fi

mkdir "$extract_root"
tar --extract --gzip --same-permissions \
    --file "$output_a/$archive_name" \
    --directory "$extract_root"
(
    cd "$package_root"
    sha256sum -c RELEASE_MANIFEST.sha256
) > "$fixture/manifest.stdout" ||
    fail "clean-checkout internal manifest verification failed"

[[ -z "$(git -C "$checkout_a" status --short)" &&
   -z "$(git -C "$checkout_b" status --short)" ]] ||
    fail "release build changed a clean checkout"
[[ -z "$(git -C "$checkout_a" tag --list)" &&
   -z "$(git -C "$checkout_b" tag --list)" ]] ||
    fail "release build created a Git tag"

# Strict project SemVer rejects malformed or unsupported release identities
# before it creates an output directory.
invalid_semver="$fixture/invalid-semver"
git clone -q --no-hardlinks "$candidate" "$invalid_semver"
invalid_index=0
while IFS= read -r invalid_version; do
    invalid_index=$((invalid_index + 1))
    printf '%s\n' "$invalid_version" > "$invalid_semver/VERSION"
    invalid_output="$fixture/invalid-output-$invalid_index"
    set +e
    PATH="$test_path" \
        bash "$invalid_semver/scripts/package-release.sh" "$invalid_output" \
        > "$fixture/invalid-$invalid_index.stdout" \
        2> "$fixture/invalid-$invalid_index.stderr"
    invalid_status=$?
    set -e
    (( invalid_status != 0 )) ||
        fail "release builder accepted invalid VERSION: $invalid_version"
    grep -Fq 'VERSION is not valid project SemVer' \
        "$fixture/invalid-$invalid_index.stderr" ||
        fail "invalid VERSION failure is inconsistent: $invalid_version"
    [[ ! -e "$invalid_output" ]] ||
        fail "invalid VERSION created release output"
done <<'INVALID_VERSIONS'
01.0.0
1.0.0-01
1.0.0-alpha..1
1.0.0+build.1
INVALID_VERSIONS

printf '%s\n%s\n' '0.9.0-beta' 'unexpected' \
    > "$invalid_semver/VERSION"
set +e
PATH="$test_path" \
    bash "$invalid_semver/scripts/package-release.sh" \
        "$fixture/multiline-output" \
    > "$fixture/multiline.stdout" 2> "$fixture/multiline.stderr"
multiline_status=$?
set -e
(( multiline_status != 0 )) ||
    fail "release builder accepted a multiline VERSION"
grep -Fq 'VERSION must contain exactly one line' \
    "$fixture/multiline.stderr" ||
    fail "multiline VERSION failure is inconsistent"
[[ ! -e "$fixture/multiline-output" ]] ||
    fail "multiline VERSION created release output"

# Version-bearing release-note metadata is an asserted input, not a guessed
# value. One contradictory second tag line must prevent every public output.
notes_mismatch="$fixture/notes-mismatch"
git clone -q --no-hardlinks "$candidate" "$notes_mismatch"
printf '\nProspective tag: `v9.9.9`\n' \
    >> "$notes_mismatch/docs/releases/0.9.0-beta.md"
set +e
PATH="$test_path" \
    bash "$notes_mismatch/scripts/package-release.sh" \
        "$fixture/notes-mismatch-output" \
    > "$fixture/notes-mismatch.stdout" 2> "$fixture/notes-mismatch.stderr"
notes_mismatch_status=$?
set -e
(( notes_mismatch_status != 0 )) ||
    fail "release builder accepted mismatched release-note metadata"
grep -Fq 'release notes metadata is inconsistent' \
    "$fixture/notes-mismatch.stderr" ||
    fail "release-note mismatch failure is inconsistent"
[[ ! -e "$fixture/notes-mismatch-output" ]] ||
    fail "release-note mismatch created release output"

# CLI output is checked independently even though production reads VERSION.
cli_mismatch="$fixture/cli-mismatch"
git clone -q --no-hardlinks "$candidate" "$cli_mismatch"
sed -i \
    '2i if [[ "${1-}" == "--version" ]]; then printf "termux-neo 9.9.9\\n"; exit 0; fi' \
    "$cli_mismatch/src/main.sh"
set +e
PATH="$test_path" \
    bash "$cli_mismatch/scripts/package-release.sh" \
        "$fixture/cli-mismatch-output" \
    > "$fixture/cli-mismatch.stdout" 2> "$fixture/cli-mismatch.stderr"
cli_mismatch_status=$?
set -e
(( cli_mismatch_status != 0 )) ||
    fail "release builder accepted a mismatched CLI version"
grep -Fq 'VERSION and CLI version disagree' \
    "$fixture/cli-mismatch.stderr" ||
    fail "CLI version mismatch failure is inconsistent"
[[ ! -e "$fixture/cli-mismatch-output" ]] ||
    fail "CLI version mismatch created release output"

printf 'PASS: Semantic Versioning, release identity, and clean-checkout packaging\n'
