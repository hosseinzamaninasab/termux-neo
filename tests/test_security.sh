#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

CACHE_DIR="$HOME/.cache/termux-neo"
fixture="$CACHE_DIR/test-security-$$"
PROJECT_ROOT="$PWD"

mkdir -p -- "$fixture"

cleanup() {
    if [[ "$fixture" == "$CACHE_DIR"/test-security-* &&
          -d "$fixture" && ! -L "$fixture" ]]
    then
        rm -rf -- "$fixture"
    fi
}

trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

expect_lifecycle_failure() {
    local label="${1-}"
    local script_path="${2-}"
    local test_home="${3-}"
    local test_prefix="${4-}"
    shift 4
    local status=0

    set +e
    HOME="$test_home" PREFIX="$test_prefix" \
        bash "$script_path" "$@" \
        > "$fixture/$label.stdout" 2> "$fixture/$label.stderr"
    status=$?
    set -e

    [[ "$status" == "1" ]] ||
        fail "$label returned $status instead of failure status 1"
}

source src/main.sh

# Settings remain data and symbolic-link indirection is rejected.
valid_config="$fixture/valid.conf"
printf '%s\n' \
    'schema_version=1' \
    'display_user=SecurityUser' \
    'theme=neo' \
    'color_mode=never' \
    'startup_integration=false' > "$valid_config"

config_link="$fixture/settings-link.conf"
ln -s -- "$valid_config" "$config_link"
if termux_neo_config_load "$config_link"; then
    fail "configuration parser followed a symbolic link"
fi
[[ "$TERMUX_NEO_CONFIG_THEME" == "neo" &&
   "$TERMUX_NEO_CONFIG_COLOR_MODE" == "auto" ]] ||
    fail "rejected configuration left partial state"

# Theme files are parsed as data and never executed.
malicious_theme_dir="$fixture/malicious-themes"
theme_marker="$fixture/theme-command-ran"
mkdir -p -- "$malicious_theme_dir"
{
    printf '%s\n' \
        'TERMUX_NEO_THEME_NAME="neo"' \
        'TERMUX_NEO_THEME_BORDER="36"' \
        'TERMUX_NEO_THEME_TITLE="1;35"' \
        'TERMUX_NEO_THEME_LABEL="1;36"' \
        'TERMUX_NEO_THEME_VALUE="37"' \
        'TERMUX_NEO_THEME_STATUS="36"' \
        'TERMUX_NEO_THEME_PROMPT="1;35"'
    printf 'touch %q\n' "$theme_marker"
} > "$malicious_theme_dir/neo.theme"

TERMUX_NEO_THEME_DIR="$malicious_theme_dir"
if termux_neo_color_load_theme neo; then
    fail "command-bearing theme content was accepted"
fi
[[ ! -e "$theme_marker" ]] || fail "theme content executed as shell code"

symlink_theme_dir="$fixture/symlink-themes"
mkdir -p -- "$symlink_theme_dir"
ln -s -- "$PROJECT_ROOT/src/themes/neo.theme" \
    "$symlink_theme_dir/neo.theme"
TERMUX_NEO_THEME_DIR="$symlink_theme_dir"
if termux_neo_color_load_theme neo; then
    fail "theme loader followed a symbolic link"
fi
TERMUX_NEO_THEME_DIR="$PROJECT_ROOT/src/themes"

# All terminal controls and both structural delimiters leave collected data.
dirty_value=$'  A|B•C\nD\tE\e[31mF\aG\bH\x7fI\u009bJ  '
clean_value="$(module_clean_value "$dirty_value" "Fallback")"
[[ -n "$clean_value" ]] || fail "sanitized value became empty"
[[ "$clean_value" != *"|"* && "$clean_value" != *"•"* ]] ||
    fail "sanitized value retained a delimiter"
if [[ "$clean_value" =~ [[:cntrl:]] ]]; then
    fail "sanitized value retained a terminal control character"
fi

unsafe_prompt_dir="$fixture/"$'unsafe\a|•prompt'
mkdir -p -- "$unsafe_prompt_dir" "$fixture/prompt-home"
prompt_value="$(
    cd "$unsafe_prompt_dir"
    HOME="$fixture/prompt-home" termux_neo_prompt_path
)"
[[ -n "$prompt_value" &&
   "$prompt_value" != *"|"* &&
   "$prompt_value" != *"•"* ]] ||
    fail "Prompt path retained an unsafe delimiter"
if [[ "$prompt_value" =~ [[:cntrl:]] ]]; then
    fail "Prompt path retained a terminal control character"
fi

# Fixture roots and command arguments reject traversal and option injection.
network_root="$fixture/network-root"
mkdir -p -- "$network_root/wlan0"
printf 'up\n' > "$network_root/wlan0/operstate"

TERMUX_NEO_NET_CLASS_ROOT="$network_root"
[[ "$(module_network_class_root)" == "$network_root" ]] ||
    fail "valid network data root was rejected"
TERMUX_NEO_NET_CLASS_ROOT="$network_root/../network-root"
if module_network_class_root >/dev/null 2>&1; then
    fail "network data root accepted traversal"
fi

primary_interface="$(
    TERMUX_NEO_NET_CLASS_ROOT="$network_root"
    ip() {
        printf 'default dev --help\n'
    }
    module_network_primary_interface
)"
[[ "$primary_interface" == "wlan0" ]] ||
    fail "option-like interface name reached the command boundary"

power_root="$fixture/power-root"
mkdir -p -- "$power_root/battery"
printf 'Battery\n' > "$power_root/battery/type"
printf '50\n' > "$power_root/battery/capacity"
printf 'Discharging\n' > "$power_root/battery/status"
TERMUX_NEO_POWER_SUPPLY_ROOT="$power_root"
[[ "$(module_battery_from_sysfs)" == "50|Discharging" ]] ||
    fail "valid battery data root was rejected"
TERMUX_NEO_POWER_SUPPLY_ROOT="$power_root/../power-root"
if module_battery_from_sysfs >/dev/null 2>&1; then
    fail "battery data root accepted traversal"
fi
unset TERMUX_NEO_NET_CLASS_ROOT TERMUX_NEO_POWER_SUPPLY_ROOT

# Optional-probe stderr is contained, while diagnostics do not dump secrets.
probe_value="$(
    noisy_probe() {
        printf 'RAW_PROBE_SECRET\n' >&2
        return 1
    }
    termux_neo_collect_value noisy_probe SafeFallback
)" 2> "$fixture/probe.stderr"
[[ "$probe_value" == "SafeFallback" ]] ||
    fail "failed optional probe did not use its fallback"
[[ ! -s "$fixture/probe.stderr" ]] ||
    fail "failed optional probe leaked raw stderr"

TERMUX_NEO_CONFIG_PATH="$valid_config"
TERMUX_NEO_SECURITY_SECRET="DO_NOT_EXPOSE_SECURITY_SENTINEL"
export TERMUX_NEO_SECURITY_SECRET
termux_neo_cli_dispatch --diagnose \
    > "$fixture/diagnostics.stdout" 2> "$fixture/diagnostics.stderr" ||
    fail "security diagnostics fixture failed"
[[ ! -s "$fixture/diagnostics.stderr" ]] ||
    fail "successful diagnostics produced stderr"
if grep -Fq "$TERMUX_NEO_SECURITY_SECRET" "$fixture/diagnostics.stdout"; then
    fail "diagnostics dumped an unrelated secret"
fi
unset TERMUX_NEO_SECURITY_SECRET

# Startup backups refuse a symlinked cache path and use private directories.
startup_home="$fixture/startup-symlink-home"
startup_external="$fixture/startup-external-cache"
mkdir -p -- "$startup_home" "$startup_external"
printf 'export KEEP_STARTUP=1\n' > "$startup_home/.bashrc"
cp -p -- "$startup_home/.bashrc" "$fixture/startup-before"
ln -s -- "$startup_external" "$startup_home/.cache"
printf '%s\n' \
    'schema_version=1' \
    'display_user=SecurityUser' \
    'theme=neo' \
    'color_mode=never' \
    'startup_integration=true' > "$fixture/startup-enabled.conf"

set +e
HOME="$startup_home" \
TERMUX_NEO_CONFIG_PATH="$fixture/startup-enabled.conf" \
TERMUX_NEO_COMMAND_PATH="$PROJECT_ROOT/bin/termux-neo" \
    termux_neo_startup_sync \
    > "$fixture/startup-symlink.stdout" \
    2> "$fixture/startup-symlink.stderr"
startup_symlink_status=$?
set -e
[[ "$startup_symlink_status" == "1" ]] ||
    fail "startup integration accepted a symlinked cache path"
cmp -s "$startup_home/.bashrc" "$fixture/startup-before" ||
    fail "failed startup integration changed .bashrc"
[[ -z "$(find "$startup_external" -mindepth 1 -print -quit)" ]] ||
    fail "failed startup integration wrote through the cache symlink"

startup_private_home="$fixture/startup-private-home"
mkdir -p -- "$startup_private_home"
printf 'export KEEP_STARTUP=1\n' > "$startup_private_home/.bashrc"
HOME="$startup_private_home" \
TERMUX_NEO_CONFIG_PATH="$fixture/startup-enabled.conf" \
TERMUX_NEO_COMMAND_PATH="$PROJECT_ROOT/bin/termux-neo" \
    termux_neo_startup_sync \
    > "$fixture/startup-private.stdout" \
    2> "$fixture/startup-private.stderr" ||
    fail "startup integration failed with a private cache"
[[ ! -s "$fixture/startup-private.stderr" ]] ||
    fail "private startup integration produced stderr"
[[ "$(stat -c '%a' "$startup_private_home/.cache/termux-neo")" == "700" &&
   "$(stat -c '%a' \
       "$startup_private_home/.cache/termux-neo/startup-backups")" == "700" ]] ||
    fail "startup backup directories are not mode 700"

# Lifecycle environment paths reject lexical traversal before mutation.
traversal_files="$fixture/traversal-files"
mkdir -p -- \
    "$traversal_files/home" \
    "$traversal_files/usr/bin" \
    "$traversal_files/alias"
ln -s -- "$(command -v bash)" "$traversal_files/usr/bin/bash"
traversal_home="$traversal_files/alias/../home"
traversal_prefix="$traversal_files/alias/../usr"
for lifecycle_script in install.sh update.sh uninstall.sh; do
    expect_lifecycle_failure \
        "traversal-${lifecycle_script%.sh}" \
        "$lifecycle_script" \
        "$traversal_home" \
        "$traversal_prefix"
done
[[ ! -e "$traversal_files/usr/lib/termux-neo" &&
   ! -e "$traversal_files/usr/bin/termux-neo" ]] ||
    fail "traversal refusal changed an installed path"

# A two-line marker does not establish runtime ownership.
partial_files="$fixture/partial-owner-files"
partial_home="$partial_files/home"
partial_prefix="$partial_files/usr"
partial_runtime="$partial_prefix/lib/termux-neo"
mkdir -p -- "$partial_home" "$partial_prefix/bin" "$partial_runtime"
ln -s -- "$(command -v bash)" "$partial_prefix/bin/bash"
printf '%s\n' \
    'format=1' \
    'product=termux-neo' > "$partial_runtime/INSTALL_MANIFEST"
printf 'partial-owner-sentinel\n' > "$partial_runtime/KEEP"
for lifecycle_script in install.sh update.sh uninstall.sh; do
    expect_lifecycle_failure \
        "partial-${lifecycle_script%.sh}" \
        "$lifecycle_script" \
        "$partial_home" \
        "$partial_prefix"
done
grep -Fqx 'partial-owner-sentinel' "$partial_runtime/KEEP" ||
    fail "partial ownership marker allowed runtime replacement or removal"

# The launcher must match all seven generated lines for every lifecycle owner.
strict_files="$fixture/strict-owner-files"
strict_home="$strict_files/home"
strict_prefix="$strict_files/usr"
strict_runtime="$strict_prefix/lib/termux-neo"
strict_command="$strict_prefix/bin/termux-neo"
mkdir -p -- "$strict_home" "$strict_prefix/bin"
ln -s -- "$(command -v bash)" "$strict_prefix/bin/bash"
HOME="$strict_home" PREFIX="$strict_prefix" bash install.sh \
    > "$fixture/strict-install.stdout" 2> "$fixture/strict-install.stderr" ||
    fail "strict ownership fixture could not be installed"
[[ ! -s "$fixture/strict-install.stderr" ]] ||
    fail "strict ownership fixture install produced stderr"
printf '# appended unowned content\n' >> "$strict_command"
cp -p -- "$strict_command" "$fixture/strict-command-before"
for lifecycle_script in install.sh update.sh uninstall.sh; do
    expect_lifecycle_failure \
        "strict-${lifecycle_script%.sh}" \
        "$lifecycle_script" \
        "$strict_home" \
        "$strict_prefix"
    cmp -s "$strict_command" "$fixture/strict-command-before" ||
        fail "$lifecycle_script changed an invalid launcher"
    [[ -d "$strict_runtime" ]] ||
        fail "$lifecycle_script removed runtime with an invalid launcher"
done

# The release report never follows a symlink.
version="$(< VERSION)"
archive_name="termux-neo-$version.tar.gz"
checksum_name="$archive_name.sha256"
notes_name="termux-neo-$version-release-notes.md"
report_name="termux-neo-$version-release-report.txt"
symlink_output="$fixture/release-symlink-output"
report_target="$fixture/report-target"
mkdir -p -- "$symlink_output"
printf 'keep-report-target\n' > "$report_target"
cp -p -- "$report_target" "$fixture/report-target-before"
ln -s -- "$report_target" "$symlink_output/$report_name"
set +e
bash scripts/package-release.sh "$symlink_output" \
    > "$fixture/release-symlink.stdout" \
    2> "$fixture/release-symlink.stderr"
release_symlink_status=$?
set -e
[[ "$release_symlink_status" == "1" ]] ||
    fail "release builder accepted a symlinked report"
cmp -s "$report_target" "$fixture/report-target-before" ||
    fail "release builder wrote through a report symlink"
[[ ! -e "$symlink_output/$archive_name" &&
   ! -e "$symlink_output/$checksum_name" &&
   ! -e "$symlink_output/$notes_name" ]] ||
    fail "report-symlink failure published release files"

# A failure after archive/notes publication removes every public release file.
partial_output="$fixture/release-partial-output"
fake_bin="$fixture/release-fake-bin"
mkdir -p -- "$partial_output" "$fake_bin"
printf '%s\n' \
    "#!$(command -v bash)" \
    'set -Eeuo pipefail' \
    'destination="${!#}"' \
    'if [[ "$destination" == *.sha256 ]]; then exit 91; fi' \
    'exec "$TERMUX_NEO_TEST_REAL_MV" "$@"' > "$fake_bin/mv"
chmod 755 -- "$fake_bin/mv"
set +e
TERMUX_NEO_TEST_REAL_MV="$(command -v mv)" \
PATH="$fake_bin:$PATH" \
    bash scripts/package-release.sh "$partial_output" \
    > "$fixture/release-partial.stdout" \
    2> "$fixture/release-partial.stderr"
release_partial_status=$?
set -e
[[ "$release_partial_status" == "91" ]] ||
    fail "partial release fixture returned $release_partial_status"
[[ ! -e "$partial_output/$archive_name" &&
   ! -e "$partial_output/$checksum_name" &&
   ! -e "$partial_output/$notes_name" ]] ||
    fail "partial release publication left a release file"

# A real published checksum rejects changed archive bytes before extraction.
verified_output="$fixture/release-verified-output"
mkdir -p -- "$verified_output"
bash scripts/package-release.sh "$verified_output" \
    > "$fixture/release-verified.stdout" \
    2> "$fixture/release-verified.stderr" ||
    fail "verified release fixture could not be built"
[[ ! -s "$fixture/release-verified.stderr" ]] ||
    fail "verified release build produced stderr"
[[ "$(stat -c '%a' "$verified_output/$report_name")" == "600" ]] ||
    fail "release report is not mode 600"
cmp -s "$fixture/release-verified.stdout" \
    "$verified_output/$report_name" ||
    fail "release report was not synchronously completed"
printf 'tampered-after-publication\n' >> "$verified_output/$archive_name"
set +e
(
    cd "$verified_output"
    sha256sum -c "$checksum_name"
) > "$fixture/checksum-tamper.stdout" 2> "$fixture/checksum-tamper.stderr"
checksum_status=$?
set -e
(( checksum_status != 0 )) ||
    fail "external checksum accepted changed archive bytes"

# Public documentation records trust, disclosure, and checksum limitations.
grep -Fq 'Theme files are never sourced' docs/security.md ||
    fail "safe theme parsing is undocumented"
grep -Fq 'It is not a digital signature' docs/security.md ||
    fail "checksum trust limitation is undocumented"
grep -Fq 'Review those fields before sharing' docs/security.md ||
    fail "diagnostic disclosure guidance is missing"
grep -Fq '[docs/security.md](docs/security.md)' README.md ||
    fail "security review is not linked from README"

# Status contracts remain distinct for runtime failure and invalid CLI usage.
set +e
termux_neo_cli_dispatch --unknown \
    > "$fixture/cli-invalid.stdout" 2> "$fixture/cli-invalid.stderr"
cli_invalid_status=$?
TERMUX_NEO_CONFIG_PATH="$config_link" \
    termux_neo_cli_dispatch \
    > "$fixture/runtime-invalid.stdout" 2> "$fixture/runtime-invalid.stderr"
runtime_invalid_status=$?
set -e
[[ "$cli_invalid_status" == "2" ]] ||
    fail "invalid CLI usage did not return status 2"
[[ "$runtime_invalid_status" == "1" ]] ||
    fail "runtime security failure did not return status 1"
[[ ! -s "$fixture/runtime-invalid.stdout" ]] ||
    fail "runtime security failure produced partial output"

printf 'PASS: security and failure-safety review\n'
