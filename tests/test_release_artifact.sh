#!/data/data/com.termux/files/usr/bin/bash
set -e

CACHE_DIR="$HOME/.cache/termux-neo"
fixture="$CACHE_DIR/test-release-artifact-$$"
source_fixture="$fixture/source-no-git"
output_a="$fixture/output-a"
output_b="$fixture/output-b"
output_c="$fixture/output-c"
extract_root="$fixture/extract"
tampered_root="$fixture/tampered"
termux_files="$fixture/files"
test_home="$termux_files/home"
test_prefix="$termux_files/usr"
runtime_root="$test_prefix/lib/termux-neo"
command_path="$test_prefix/bin/termux-neo"
config_path="$test_home/.config/termux-neo/settings.conf"
archive_name="termux-neo-0.5.0-beta.tar.gz"
checksum_name="$archive_name.sha256"
report_name="termux-neo-0.5.0-beta-release-report.txt"
package_root="$extract_root/termux-neo-0.5.0-beta"

mkdir -p \
    "$source_fixture/scripts" \
    "$output_a" \
    "$output_b" \
    "$output_c" \
    "$extract_root" \
    "$test_home" \
    "$test_prefix/bin"
ln -s "$(command -v bash)" "$test_prefix/bin/bash"
trap 'rm -rf "$fixture"' EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

cp -p VERSION LICENSE README.md install.sh update.sh uninstall.sh \
    "$source_fixture/"
cp -pR bin config docs src "$source_fixture/"
cp -p scripts/package-release.sh "$source_fixture/scripts/"
[[ ! -e "$source_fixture/.git" ]] ||
    fail "release source fixture unexpectedly contains Git metadata"

fake_bin="$fixture/fake-bin"
mkdir "$fake_bin"
cat > "$fake_bin/git" <<'MOCK'
#!/usr/bin/env bash
printf 'Git must not be used by release artifact workflows\n' >&2
exit 97
MOCK
chmod 755 "$fake_bin/git"
test_path="$fake_bin:$PATH"

PATH="$test_path" bash "$source_fixture/scripts/package-release.sh" "$output_a" \
    > "$fixture/package-a.stdout" 2> "$fixture/package-a.stderr" ||
    fail "first release package build failed"
PATH="$test_path" bash "$source_fixture/scripts/package-release.sh" "$output_b" \
    > "$fixture/package-b.stdout" 2> "$fixture/package-b.stderr" ||
    fail "second release package build failed"

[[ ! -s "$fixture/package-a.stderr" &&
   ! -s "$fixture/package-b.stderr" ]] ||
    fail "successful release packaging produced stderr"
grep -Fqx 'PASS: reproducible release artifact created and verified' \
    "$fixture/package-a.stdout" ||
    fail "release package success line is missing"

for output_dir in "$output_a" "$output_b"; do
    [[ -f "$output_dir/$archive_name" &&
       ! -L "$output_dir/$archive_name" ]] ||
        fail "versioned archive is missing"
    [[ -f "$output_dir/$checksum_name" &&
       ! -L "$output_dir/$checksum_name" ]] ||
        fail "archive checksum is missing"
    [[ -f "$output_dir/$report_name" &&
       ! -L "$output_dir/$report_name" ]] ||
        fail "release report is missing"
    [[ "$(stat -c '%a' "$output_dir/$archive_name")" == "644" ]] ||
        fail "archive mode is not 644"
    [[ "$(stat -c '%a' "$output_dir/$checksum_name")" == "644" ]] ||
        fail "checksum mode is not 644"
    [[ "$(stat -c '%a' "$output_dir/$report_name")" == "600" ]] ||
        fail "release report mode is not 600"
    (
        cd "$output_dir"
        sha256sum -c "$checksum_name"
    ) > "$fixture/checksum.stdout" ||
        fail "external archive checksum verification failed"
done

cmp -s "$output_a/$archive_name" "$output_b/$archive_name" ||
    fail "two clean builds produced different archive bytes"
cmp -s "$output_a/$checksum_name" "$output_b/$checksum_name" ||
    fail "two clean builds produced different checksum bytes"

tar -tzf "$output_a/$archive_name" > "$fixture/archive-list"
grep -Fqx 'termux-neo-0.5.0-beta/RELEASE_MANIFEST.sha256' \
    "$fixture/archive-list" ||
    fail "internal release manifest is missing from the archive"
if grep -Eq '(^/|(^|/)\.\.(/|$)|(^|/)\.git(/|$)|(^|/)tests(/|$))' \
    "$fixture/archive-list"
then
    fail "archive contains an unsafe or development-only path"
fi

tar --extract --gzip --same-permissions \
    --file "$output_a/$archive_name" \
    --directory "$extract_root"
[[ -d "$package_root" && ! -L "$package_root" ]] ||
    fail "versioned archive root is missing"
[[ ! -e "$package_root/.git" && ! -e "$package_root/tests" ]] ||
    fail "extracted release contains development metadata"
(
    cd "$package_root"
    sha256sum -c RELEASE_MANIFEST.sha256
) > "$fixture/manifest.stdout" ||
    fail "internal release manifest verification failed"

PATH="$test_path" bash "$package_root/scripts/package-release.sh" "$output_c" \
    > "$fixture/package-c.stdout" 2> "$fixture/package-c.stderr" ||
    fail "extracted release could not reproduce itself"
[[ ! -s "$fixture/package-c.stderr" ]] ||
    fail "self-reproduced release packaging produced stderr"
cmp -s "$output_a/$archive_name" "$output_c/$archive_name" ||
    fail "extracted release did not reproduce identical archive bytes"
cmp -s "$output_a/$checksum_name" "$output_c/$checksum_name" ||
    fail "extracted release did not reproduce identical checksum bytes"

[[ "$(stat -c '%a' "$package_root/install.sh")" == "755" ]] ||
    fail "packaged installer mode is not 755"
[[ "$(stat -c '%a' "$package_root/update.sh")" == "755" ]] ||
    fail "packaged updater mode is not 755"
[[ "$(stat -c '%a' "$package_root/uninstall.sh")" == "755" ]] ||
    fail "packaged uninstaller mode is not 755"
[[ "$(stat -c '%a' "$package_root/scripts/package-release.sh")" == "755" ]] ||
    fail "packaged release builder mode is not 755"

# A changed package file fails manifest validation before any installed path
# is created.
cp -pR "$package_root" "$tampered_root"
printf 'tampered\n' >> "$tampered_root/README.md"
set +e
HOME="$test_home" PREFIX="$test_prefix" PATH="$test_path" \
    bash "$tampered_root/install.sh" \
    > "$fixture/tampered.stdout" 2> "$fixture/tampered.stderr"
tampered_status=$?
set -e
(( tampered_status != 0 )) ||
    fail "tampered release artifact was accepted"
grep -Fq 'release manifest: checksum mismatch: ./README.md' \
    "$fixture/tampered.stderr" ||
    fail "tampered artifact failure was not reported"
[[ ! -e "$runtime_root" && ! -e "$command_path" ]] ||
    fail "tampered artifact changed installed paths"

# The extracted artifact performs a clean install without Git.
printf 'export EXISTING_VALUE=kept\n' > "$test_home/.bashrc"
cp -p "$test_home/.bashrc" "$fixture/bashrc-before-lifecycle"
HOME="$test_home" PREFIX="$test_prefix" PATH="$test_path" \
    bash "$package_root/install.sh" \
    > "$fixture/install.stdout" 2> "$fixture/install.stderr" ||
    fail "packaged clean install failed"
[[ ! -s "$fixture/install.stderr" ]] ||
    fail "packaged clean install produced stderr"
[[ "$("$command_path" --version)" == "termux-neo 0.5.0-beta" ]] ||
    fail "packaged command version mismatch"
[[ -f "$runtime_root/INSTALL_MANIFEST" ]] ||
    fail "packaged clean install has no ownership manifest"

# A packaged upgrade preserves settings bytes and mode.
printf '%s\n' \
    'schema_version=1' \
    'display_user=ArchiveUser' \
    'theme=matrix' \
    'color_mode=never' \
    'startup_integration=false' > "$config_path"
chmod 640 "$config_path"
cp -p "$config_path" "$fixture/settings-before-update"
printf '0.4.0-alpha\n' > "$runtime_root/VERSION"
sed -i 's/^version=.*/version=0.4.0-alpha/' \
    "$runtime_root/INSTALL_MANIFEST"

HOME="$test_home" PREFIX="$test_prefix" PATH="$test_path" \
    bash "$package_root/update.sh" \
    > "$fixture/update.stdout" 2> "$fixture/update.stderr" ||
    fail "packaged update failed"
[[ ! -s "$fixture/update.stderr" ]] ||
    fail "packaged update produced stderr"
grep -Fqx 'version relation: upgrade' "$fixture/update.stdout" ||
    fail "packaged update relation mismatch"
[[ "$("$command_path" --version)" == "termux-neo 0.5.0-beta" ]] ||
    fail "packaged update version mismatch"
cmp -s "$config_path" "$fixture/settings-before-update" ||
    fail "packaged update changed settings bytes"
[[ "$(stat -c '%a' "$config_path")" == "640" ]] ||
    fail "packaged update changed settings mode"

# Packaged uninstall removes only owned paths and preserves settings by default.
printf 'keep-library-neighbor\n' > "$test_prefix/lib/neighbor.txt"
printf 'keep-bin-neighbor\n' > "$test_prefix/bin/neighbor.txt"
printf 'keep-config-neighbor\n' > "$test_home/.config/termux-neo/neighbor.txt"

HOME="$test_home" PREFIX="$test_prefix" PATH="$test_path" \
    bash "$package_root/uninstall.sh" \
    > "$fixture/uninstall.stdout" 2> "$fixture/uninstall.stderr" ||
    fail "packaged uninstall failed"
[[ ! -s "$fixture/uninstall.stderr" ]] ||
    fail "packaged uninstall produced stderr"
[[ ! -e "$runtime_root" && ! -e "$command_path" ]] ||
    fail "packaged uninstall left owned code paths"
cmp -s "$config_path" "$fixture/settings-before-update" ||
    fail "packaged uninstall changed preserved settings"
[[ -f "$test_prefix/lib/neighbor.txt" &&
   -f "$test_prefix/bin/neighbor.txt" &&
   -f "$test_home/.config/termux-neo/neighbor.txt" ]] ||
    fail "packaged uninstall removed an unowned neighboring file"
cmp -s "$test_home/.bashrc" "$fixture/bashrc-before-lifecycle" ||
    fail "packaged lifecycle changed unrelated Bash startup content"

printf 'PASS: reproducible Git-independent release artifact lifecycle\n'
