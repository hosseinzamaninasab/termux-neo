#!/data/data/com.termux/files/usr/bin/bash
set -e

CACHE_DIR="$HOME/.cache/termux-neo"
fixture="$CACHE_DIR/test-beta-$$"
stdout_file="$fixture/stdout"
stderr_file="$fixture/stderr"
probe_bin="$fixture/external-probe-bin"
probe_sentinel="$fixture/external-probe-used"
legacy_release_prefix="/data/data/com.termux/files/home/.cache/termux-neo/test-release-artifact-4194304/tnb.ABCDEF/matrix/files/usr"
legacy_release_shebang="#!$legacy_release_prefix/bin/bash"
long_parent="$fixture/legacy-shebang-limit-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

mkdir -p "$fixture" "$probe_bin" "$long_parent"
trap 'rm -rf "$fixture"' EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

real_bash="$(command -v bash)" ||
    fail "Bash is unavailable"
for probe_command in \
    ip ifconfig getprop termux-battery-status dumpsys
do
    printf '#!%s\nprintf "used\\n" >> %q\nexit 1\n' \
        "$real_bash" "$probe_sentinel" > "$probe_bin/$probe_command"
    chmod 755 "$probe_bin/$probe_command"
done

bash -n scripts/beta-field-test.sh tests/test_beta.sh ||
    fail "beta scripts failed syntax validation"

PATH="$probe_bin:$PATH" TMPDIR="$fixture" \
    bash scripts/beta-field-test.sh --self-test \
        > "$stdout_file" 2> "$stderr_file" ||
    fail "portable beta field matrix failed"
[[ ! -s "$stderr_file" ]] ||
    fail "portable beta field matrix produced stderr"
[[ ! -e "$probe_sentinel" ]] ||
    fail "portable beta field matrix used a real external probe"
(( ${#legacy_release_shebang} + 1 <= 128 )) ||
    fail "portable beta path exceeds the legacy Android shebang limit"
grep -Fqx 'PASS: portable stable release field matrix (10 scenarios)' \
    "$stdout_file" ||
    fail "portable stable success contract is missing"

set +e
TMPDIR="$long_parent" \
    bash scripts/beta-field-test.sh --self-test \
        > "$fixture/long-path.stdout" 2> "$fixture/long-path.stderr"
long_path_status=$?
set -e
[[ "$long_path_status" == "1" ]] ||
    fail "overlong isolated prefix did not fail with status 1"
grep -Fq 'isolated prefix exceeds the legacy Android shebang limit' \
    "$fixture/long-path.stderr" ||
    fail "overlong isolated prefix failure was not actionable"

set +e
TMPDIR="$fixture" \
    bash scripts/beta-field-test.sh --unknown \
        > "$fixture/invalid.stdout" 2> "$fixture/invalid.stderr"
invalid_status=$?
set -e
[[ "$invalid_status" == "2" ]] ||
    fail "invalid beta option did not return status 2"
[[ ! -s "$fixture/invalid.stdout" ]] ||
    fail "invalid beta option produced stdout"
grep -Fq 'usage: bash scripts/beta-field-test.sh' \
    "$fixture/invalid.stderr" ||
    fail "invalid beta usage message is missing"

[[ "$(cat VERSION)" == "1.0.0" ]] ||
    fail "stable release version is inconsistent"
grep -Fq 'Current stable release: `1.0.0`' README.md ||
    fail "README stable checkpoint is missing"
grep -Fq '[docs/beta-testing.md](docs/beta-testing.md)' README.md ||
    fail "README beta testing link is missing"

grep -Fqx 'COMPLETE — 1.0.0' docs/feature-freeze.md ||
    fail "feature freeze is not complete"
for allowed_change in \
    'a fix for a release-blocking defect' \
    'a security fix' \
    'a compatibility fix backed by repeatable evidence' \
    'a documentation correction that matches existing behavior'
do
    grep -Fq "$allowed_change" docs/feature-freeze.md ||
        fail "feature freeze allowlist is incomplete"
done

grep -Fqx 'Open critical security defects: 0' docs/beta-issues.md ||
    fail "critical defect gate is not zero"
grep -Fqx 'Open high-severity defects: 0' docs/beta-issues.md ||
    fail "high-severity defect gate is not zero"
grep -Fqx 'Open release-blocking defects: 0' docs/beta-issues.md ||
    fail "release-blocking defect gate is not zero"
grep -Fqx -- '- Feature freeze: ACTIVE' docs/beta-field-report.md ||
    fail "field report does not record the freeze"
grep -Fqx -- '- Task 28 result: PASS' docs/beta-field-report.md ||
    fail "field report Task 28 result is missing"

for scenario in \
    'Fresh isolated Termux HOME/PREFIX' \
    'Clean install' \
    'Existing-config install' \
    'Update from prior alpha' \
    'Uninstall with config preserved' \
    'Uninstall with config removed' \
    'Offline startup' \
    'Restricted-permission startup' \
    'Portrait render' \
    'Landscape render'
do
    grep -F "| $scenario | PASS |" docs/beta-field-report.md >/dev/null ||
        fail "field report scenario is missing: $scenario"
done

grep -Fq 'scripts/beta-field-test.sh' scripts/package-release.sh ||
    fail "release artifact does not carry the beta field tool"
grep -Fq 'bash scripts/beta-field-test.sh --self-test' docs/quality.md ||
    fail "portable beta command is undocumented"
grep -Fq 'portable matrix only.' docs/quality.md ||
    fail "portable/device beta evidence boundary is undocumented"
grep -Fq 'did not mutate the user installation' \
    docs/beta-field-report.md ||
    grep -Fq 'uses isolated temporary HOME/PREFIX paths' \
        docs/beta-field-report.md ||
    fail "field report isolation boundary is missing"

printf 'PASS: stable field matrix and completed feature freeze\n'
