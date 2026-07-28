#!/data/data/com.termux/files/usr/bin/bash
set -e

CACHE_DIR="$HOME/.cache/termux-neo"
fixture="$CACHE_DIR/test-quality-pipeline-$$"
list_file="$fixture/tests.list"
stderr_file="$fixture/stderr"

mkdir -p "$fixture"
trap 'rm -rf "$fixture"' EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

bash -n \
    scripts/performance-check.sh \
    scripts/quality-check.sh \
    scripts/smoke-release.sh ||
    fail "quality scripts failed syntax validation"

bash scripts/quality-check.sh --list > "$list_file" 2> "$stderr_file" ||
    fail "quality test registry could not be listed"
[[ ! -s "$stderr_file" ]] ||
    fail "quality test registry produced stderr"
[[ "$(wc -l < "$list_file")" == "23" ]] ||
    fail "quality registry does not contain 23 tests"
[[ "$(LC_ALL=C sort -u "$list_file" | wc -l)" == "23" ]] ||
    fail "quality registry contains duplicate tests"

while IFS= read -r test_path; do
    grep -Fqx "$test_path" "$list_file" ||
        fail "test is not assigned to the quality pipeline: $test_path"
done < <(
    find tests -maxdepth 1 -type f -name 'test_*.sh' -print |
        LC_ALL=C sort
)

set +e
bash scripts/quality-check.sh --unknown \
    > "$fixture/invalid.stdout" 2> "$fixture/invalid.stderr"
invalid_status=$?
set -e
[[ "$invalid_status" == "2" ]] ||
    fail "invalid quality option did not return status 2"
[[ ! -s "$fixture/invalid.stdout" ]] ||
    fail "invalid quality option produced stdout"
grep -Fqx \
    'termux-neo quality: usage: bash scripts/quality-check.sh [--list]' \
    "$fixture/invalid.stderr" ||
    fail "invalid quality usage message is inconsistent"

grep -Fq 'uses: actions/checkout@v4' .github/workflows/quality.yml ||
    fail "CI checkout action is not pinned to its major version"
grep -Fq 'permissions:' .github/workflows/quality.yml ||
    fail "CI permissions boundary is missing"
grep -Fq 'contents: read' .github/workflows/quality.yml ||
    fail "CI repository permission is not read-only"
grep -Fq 'bash scripts/quality-check.sh' .github/workflows/quality.yml ||
    fail "CI does not call the canonical quality runner"

for portable_test in \
    tests/test_integration.sh \
    tests/test_startup_integration.sh
do
    if tail -n +2 "$portable_test" |
       grep -Fq '#!/data/data/com.termux/files/usr/bin/bash'
    then
        fail "portable tests generate a hard-coded Termux fixture shebang"
    fi
done

grep -Fq 'CI does not establish device compatibility' docs/quality.md ||
    fail "CI/device evidence boundary is undocumented"
grep -Fq 'Device-only verification checklist' docs/quality.md ||
    fail "device-only checklist is missing"
grep -Fq 'bash scripts/smoke-release.sh' docs/quality.md ||
    fail "artifact smoke command is undocumented"
grep -Fq 'bash scripts/performance-check.sh --self-test' docs/quality.md ||
    fail "portable performance command is undocumented"
grep -Fq 'CI does not establish reference-device timing' docs/quality.md ||
    fail "CI/performance evidence boundary is undocumented"

grep -Fq '"$SOURCE_ROOT/scripts/smoke-release.sh"' \
    scripts/package-release.sh ||
    fail "release builder does not require the smoke script"
grep -Fq \
    'bash "$verify_root/$package_name/scripts/smoke-release.sh"' \
    scripts/package-release.sh ||
    fail "release builder does not execute smoke from the extracted artifact"

printf 'PASS: automated quality pipeline contract\n'
