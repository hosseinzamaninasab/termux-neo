#!/data/data/com.termux/files/usr/bin/bash
set -e

CACHE_DIR="$HOME/.cache/termux-neo"
fixture="$CACHE_DIR/test-uninstall-$$"
termux_files="$fixture/files"
test_home="$termux_files/home"
test_prefix="$termux_files/usr"
runtime_root="$test_prefix/lib/termux-neo"
command_path="$test_prefix/bin/termux-neo"
config_path="$test_home/.config/termux-neo/settings.conf"
report_path="$test_home/.cache/termux-neo/uninstall-reports/uninstall-report.txt"
stdout_file="$fixture/stdout"
stderr_file="$fixture/stderr"
real_mv="$(command -v mv)"

mkdir -p "$test_home" "$test_prefix/bin"
ln -s "$(command -v bash)" "$test_prefix/bin/bash"
trap 'rm -rf "$fixture"' EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

run_installer() {
    HOME="$test_home" PREFIX="$test_prefix" bash install.sh \
        > "$fixture/install-stdout" 2> "$fixture/install-stderr" ||
        fail "production installer fixture failed"
    [[ ! -s "$fixture/install-stderr" ]] ||
        fail "production installer fixture produced stderr"
}

run_uninstaller() {
    local expected_status="${1-0}"
    local path_value="${2-$PATH}"
    shift 2 || true
    local actual_status=0

    : > "$stdout_file"
    : > "$stderr_file"
    set +e
    HOME="$test_home" PREFIX="$test_prefix" PATH="$path_value" \
        bash uninstall.sh "$@" \
        > "$stdout_file" 2> "$stderr_file"
    actual_status=$?
    set -e

    [[ "$actual_status" == "$expected_status" ]] ||
        fail "uninstaller status mismatch: expected $expected_status, got $actual_status"
    [[ -f "$report_path" && ! -L "$report_path" ]] ||
        fail "text uninstall report is missing"
    [[ "$(stat -c '%a' "$report_path")" == "600" ]] ||
        fail "text uninstall report mode is not 600"
    grep -Fqx "uninstall report: $report_path" "$stdout_file" ||
        fail "uninstall report path was not printed"
    cmp -s "$stdout_file" "$report_path" ||
        fail "text uninstall report does not match combined terminal output"
}

enable_startup() {
    printf '%s\n' \
        'schema_version=1' \
        'display_user=Zoro' \
        'theme=neo' \
        'color_mode=never' \
        'startup_integration=true' > "$config_path"
    HOME="$test_home" "$command_path" --startup \
        > "$fixture/startup-stdout" 2> "$fixture/startup-stderr" ||
        fail "startup fixture could not be enabled"
    [[ ! -s "$fixture/startup-stderr" ]] ||
        fail "startup fixture produced stderr"
}

printf '%s\n' \
    'export EXISTING_VALUE=kept' \
    'alias ll="ls -l"' > "$test_home/.bashrc"
cp -p "$test_home/.bashrc" "$fixture/bashrc-before-startup"

# Default removal deletes only owned code, removes one managed startup block,
# and preserves settings bytes and mode.
run_installer
printf 'preserved-settings\n' >> "$config_path"
chmod 640 "$config_path"
enable_startup
cp -p "$config_path" "$fixture/settings-before-uninstall"

backup_files_before=(
    "$test_home"/.cache/termux-neo/startup-backups/bashrc.*.bak
)
(( ${#backup_files_before[@]} == 1 )) ||
    fail "startup installation backup count mismatch"

run_uninstaller 0 "$PATH"
[[ ! -s "$stderr_file" ]] || fail "successful uninstall produced stderr"
grep -Fqx 'Termux Neo uninstall complete' "$stdout_file" ||
    fail "uninstall completion line is missing"
grep -Fqx "removed: $runtime_root" "$stdout_file" ||
    fail "runtime removal was not reported"
grep -Fqx "removed: $command_path" "$stdout_file" ||
    fail "command removal was not reported"
grep -Fqx "preserved: $config_path" "$stdout_file" ||
    fail "configuration preservation was not reported"
grep -Fqx 'startup integration: removed' "$stdout_file" ||
    fail "startup removal was not reported"

[[ ! -e "$runtime_root" && ! -L "$runtime_root" ]] ||
    fail "owned runtime remains after uninstall"
[[ ! -e "$command_path" && ! -L "$command_path" ]] ||
    fail "owned launcher remains after uninstall"
cmp -s "$config_path" "$fixture/settings-before-uninstall" ||
    fail "default uninstall changed settings bytes"
[[ "$(stat -c '%a' "$config_path")" == "640" ]] ||
    fail "default uninstall changed settings mode"
cmp -s "$test_home/.bashrc" "$fixture/bashrc-before-startup" ||
    fail "uninstall did not preserve unrelated Bash startup content"

backup_files_after=(
    "$test_home"/.cache/termux-neo/startup-backups/bashrc.*.bak
)
(( ${#backup_files_after[@]} == 2 )) ||
    fail "startup removal did not create exactly one backup"

# Repeated removal is a byte-idempotent no-op.
cp -p "$test_home/.bashrc" "$fixture/bashrc-before-second-uninstall"
cp -p "$config_path" "$fixture/settings-before-second-uninstall"
run_uninstaller 0 "$PATH"
grep -Fqx "already absent: $runtime_root" "$stdout_file" ||
    fail "second uninstall did not report absent runtime"
grep -Fqx "already absent: $command_path" "$stdout_file" ||
    fail "second uninstall did not report absent command"
grep -Fqx 'startup integration: already absent' "$stdout_file" ||
    fail "second uninstall did not report absent startup block"
cmp -s "$test_home/.bashrc" "$fixture/bashrc-before-second-uninstall" ||
    fail "second uninstall changed the Bash startup file"
cmp -s "$config_path" "$fixture/settings-before-second-uninstall" ||
    fail "second uninstall changed preserved settings"
backup_files_second=(
    "$test_home"/.cache/termux-neo/startup-backups/bashrc.*.bak
)
(( ${#backup_files_second[@]} == 2 )) ||
    fail "idempotent uninstall created a startup backup"

# Explicit removal deletes the exact settings file and no broader content.
run_installer
printf 'keep-neighbor\n' > "$test_home/.config/termux-neo/neighbor.txt"
run_uninstaller 0 "$PATH" --remove-config
grep -Fqx "removed: $config_path" "$stdout_file" ||
    fail "explicit settings removal was not reported"
[[ ! -e "$config_path" && ! -L "$config_path" ]] ||
    fail "explicit uninstall preserved settings"
[[ -f "$test_home/.config/termux-neo/neighbor.txt" ]] ||
    fail "explicit settings removal deleted a neighboring file"
[[ ! -e "$runtime_root" && ! -e "$command_path" ]] ||
    fail "explicit uninstall left owned code paths"

# Unknown ownership fails closed before touching any target.
mkdir -p "$runtime_root"
printf '%s\n' 'format=1' 'product=not-termux-neo' \
    > "$runtime_root/INSTALL_MANIFEST"
printf 'unowned-runtime\n' > "$runtime_root/UNOWNED_SENTINEL"
cp -p "$test_home/.bashrc" "$fixture/bashrc-before-unowned"
run_uninstaller 1 "$PATH"
grep -Fq 'refusing to remove an unowned runtime path' "$stdout_file" ||
    fail "unowned runtime refusal was not reported"
[[ -f "$runtime_root/UNOWNED_SENTINEL" ]] ||
    fail "uninstaller removed an unowned runtime"
cmp -s "$test_home/.bashrc" "$fixture/bashrc-before-unowned" ||
    fail "unowned runtime refusal changed the Bash startup file"
rm -rf "$runtime_root"

# Invalid startup markers fail before owned runtime, launcher, or settings move.
run_installer
printf '%s\n' \
    'export EXISTING_VALUE=kept' \
    '# >>> termux-neo startup >>>' \
    'incomplete block' > "$test_home/.bashrc"
cp -p "$test_home/.bashrc" "$fixture/bashrc-before-invalid-markers"
cp -p "$command_path" "$fixture/command-before-invalid-markers"
cp -p "$config_path" "$fixture/settings-before-invalid-markers"
run_uninstaller 1 "$PATH"
grep -Fq 'Bash startup markers are incomplete or duplicated' "$stdout_file" ||
    fail "invalid startup marker failure was not reported"
[[ -d "$runtime_root" ]] ||
    fail "invalid startup markers removed the runtime"
cmp -s "$command_path" "$fixture/command-before-invalid-markers" ||
    fail "invalid startup markers changed the launcher"
cmp -s "$config_path" "$fixture/settings-before-invalid-markers" ||
    fail "invalid startup markers changed settings"
cmp -s "$test_home/.bashrc" "$fixture/bashrc-before-invalid-markers" ||
    fail "invalid startup markers changed the Bash startup file"

# A failure after startup removal restores the shell and all owned paths.
printf '%s\n' \
    'export EXISTING_VALUE=kept' \
    'alias ll="ls -l"' > "$test_home/.bashrc"
enable_startup
printf 'runtime-rollback-sentinel\n' > "$runtime_root/ROLLBACK_SENTINEL"
cp -p "$test_home/.bashrc" "$fixture/bashrc-before-rollback"
cp -p "$runtime_root/ROLLBACK_SENTINEL" \
    "$fixture/runtime-before-rollback"
cp -p "$command_path" "$fixture/command-before-rollback"
cp -p "$config_path" "$fixture/settings-before-rollback"

fake_bin="$fixture/fake-bin"
mv_count_file="$fixture/mv-count"
mkdir "$fake_bin"
printf '0\n' > "$mv_count_file"
cat > "$fake_bin/mv" <<'MOCK'
#!/usr/bin/env bash
count=0
IFS= read -r count < "$TERMUX_NEO_MV_COUNT_FILE" || count=0
(( count += 1 ))
printf '%s\n' "$count" > "$TERMUX_NEO_MV_COUNT_FILE"
if (( count == 2 )); then
    exit 77
fi
exec "$TERMUX_NEO_REAL_MV" "$@"
MOCK
chmod 755 "$fake_bin/mv"

export TERMUX_NEO_MV_COUNT_FILE="$mv_count_file"
export TERMUX_NEO_REAL_MV="$real_mv"
run_uninstaller 1 "$fake_bin:$PATH"
unset TERMUX_NEO_MV_COUNT_FILE TERMUX_NEO_REAL_MV

grep -Fq 'uninstall rolled back; the previous state was restored' \
    "$stdout_file" ||
    fail "uninstall rollback result was not reported"
cmp -s "$test_home/.bashrc" "$fixture/bashrc-before-rollback" ||
    fail "rollback did not restore the Bash startup file"
cmp -s "$runtime_root/ROLLBACK_SENTINEL" \
    "$fixture/runtime-before-rollback" ||
    fail "rollback did not preserve the runtime"
cmp -s "$command_path" "$fixture/command-before-rollback" ||
    fail "rollback did not preserve the launcher"
cmp -s "$config_path" "$fixture/settings-before-rollback" ||
    fail "rollback did not preserve settings"

shopt -s nullglob
leftovers=(
    "$test_prefix/lib"/.termux-neo.uninstall-*
    "$test_prefix/bin"/.termux-neo.uninstall-*
    "$test_home/.config/termux-neo"/.termux-neo.uninstall-*
)
(( ${#leftovers[@]} == 0 )) ||
    fail "uninstaller left transaction paths behind"

if grep -Eq '(^|[[:space:]])(sudo|su)([[:space:]]|$)' uninstall.sh; then
    fail "uninstaller introduces a root command"
fi
if grep -Eq '(^|[^[:alnum:]_])git([^[:alnum:]_]|$)' uninstall.sh; then
    fail "uninstaller requires Git"
fi
[[ "$(grep -Fc 'rm -rf -- "$runtime_original"' uninstall.sh)" == "1" ]] ||
    fail "uninstaller recursive deletion is not singular and guarded"

printf 'PASS: safe uninstaller transaction\n'
