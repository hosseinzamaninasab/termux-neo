#!/data/data/com.termux/files/usr/bin/bash
set -e

CACHE_DIR="$HOME/.cache/termux-neo"
fixture="$CACHE_DIR/test-update-$$"
termux_files="$fixture/files"
test_home="$termux_files/home"
test_prefix="$termux_files/usr"
runtime_root="$test_prefix/lib/termux-neo"
command_path="$test_prefix/bin/termux-neo"
config_path="$test_home/.config/termux-neo/settings.conf"
report_path="$test_home/.cache/termux-neo/update-reports/update-report.txt"
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

make_target() {
    local target_dir="${1-}"
    local target_version="${2-}"

    mkdir -p "$target_dir"
    cp -p VERSION LICENSE README.md install.sh update.sh "$target_dir/"
    cp -pR bin config docs src "$target_dir/"
    printf '%s\n' "$target_version" > "$target_dir/VERSION"
    chmod 755 "$target_dir/install.sh" "$target_dir/update.sh"
    [[ ! -e "$target_dir/.git" ]] ||
        fail "target fixture unexpectedly contains Git metadata"
}

run_updater() {
    local target_dir="${1-}"
    local expected_status="${2-0}"
    local path_value="${3-$PATH}"
    shift 3 || true
    local actual_status=0

    : > "$stdout_file"
    : > "$stderr_file"
    set +e
    HOME="$test_home" PREFIX="$test_prefix" PATH="$path_value" \
        bash "$target_dir/update.sh" "$@" \
        > "$stdout_file" 2> "$stderr_file"
    actual_status=$?
    set -e

    [[ "$actual_status" == "$expected_status" ]] ||
        fail "updater status mismatch: expected $expected_status, got $actual_status"
    [[ -f "$report_path" && ! -L "$report_path" ]] ||
        fail "text update report is missing"
    [[ "$(stat -c '%a' "$report_path")" == "600" ]] ||
        fail "text update report mode is not 600"
    grep -Fqx "update report: $report_path" "$stdout_file" ||
        fail "update report path was not printed"
    cmp -s "$stdout_file" "$report_path" ||
        fail "text update report does not match combined terminal output"
}

printf 'export EXISTING_VALUE=kept\n' > "$test_home/.bashrc"
cp "$test_home/.bashrc" "$fixture/bashrc-before-update"

# Establish the Task 20 owned installation without any Git dependency.
HOME="$test_home" PREFIX="$test_prefix" bash install.sh \
    > "$fixture/install-stdout" 2> "$fixture/install-stderr" ||
    fail "production installer fixture failed"
[[ ! -s "$fixture/install-stderr" ]] ||
    fail "production installer fixture produced stderr"

printf '%s\n' \
    'schema_version=1' \
    'display_user=Zoro' \
    'theme=matrix' \
    'color_mode=never' \
    'startup_integration=false' > "$config_path"
chmod 640 "$config_path"
cp -p "$config_path" "$fixture/settings-before-upgrade"

# A newer standalone source tree upgrades the owned runtime and launcher.
target_upgrade="$fixture/target-0.4.0-alpha"
make_target "$target_upgrade" "0.4.0-alpha"
run_updater "$target_upgrade" 0 "$PATH"

[[ ! -s "$stderr_file" ]] || fail "successful update produced stderr"
grep -Fqx 'version relation: upgrade' "$stdout_file" ||
    fail "upgrade relation was not reported"
grep -Fqx 'Termux Neo update complete' "$stdout_file" ||
    fail "update completion line is missing"
grep -Fqx "changed: replaced $runtime_root" "$stdout_file" ||
    fail "runtime replacement was not reported"
grep -Fqx "changed: replaced $command_path" "$stdout_file" ||
    fail "command replacement was not reported"
grep -Fqx "preserved: $config_path" "$stdout_file" ||
    fail "configuration preservation was not reported"
grep -Fqx 'startup integration: unchanged' "$stdout_file" ||
    fail "startup no-change result was not reported"

[[ "$($command_path --version)" == "termux-neo 0.4.0-alpha" ]] ||
    fail "updated command version mismatch"
grep -Fqx 'version=0.4.0-alpha' "$runtime_root/INSTALL_MANIFEST" ||
    fail "updated ownership manifest version mismatch"
[[ -f "$runtime_root/docs/update.md" ]] ||
    fail "update documentation was not installed"
cmp -s "$config_path" "$fixture/settings-before-upgrade" ||
    fail "upgrade changed schema v1 settings bytes"
[[ "$(stat -c '%a' "$config_path")" == "640" ]] ||
    fail "upgrade changed schema v1 settings mode"
cmp -s "$test_home/.bashrc" "$fixture/bashrc-before-update" ||
    fail "upgrade changed the Bash startup file"

# Re-running the same target is a no-op for runtime, launcher, and settings.
printf 'same-version-sentinel\n' > "$runtime_root/SAME_VERSION_SENTINEL"
cp -p "$command_path" "$fixture/command-before-same-version"
cp -p "$config_path" "$fixture/settings-before-same-version"
run_updater "$target_upgrade" 0 "$PATH"

grep -Fqx 'version relation: already current' "$stdout_file" ||
    fail "same-version relation was not reported"
grep -Fqx "unchanged: $runtime_root" "$stdout_file" ||
    fail "same-version runtime no-op was not reported"
[[ -f "$runtime_root/SAME_VERSION_SENTINEL" ]] ||
    fail "same-version update replaced the runtime"
cmp -s "$command_path" "$fixture/command-before-same-version" ||
    fail "same-version update changed the launcher"
cmp -s "$config_path" "$fixture/settings-before-same-version" ||
    fail "same-version update changed schema v1 settings"

# A supported schema 0 file is migrated without replacing same-version code.
printf 'display_user=Neo\n' > "$config_path"
chmod 640 "$config_path"
run_updater "$target_upgrade" 0 "$PATH"

grep -Fqx "changed: migrated schema 0 to 1 at $config_path" "$stdout_file" ||
    fail "configuration migration was not reported"
grep -Fqx 'schema_version=1' "$config_path" ||
    fail "migrated settings schema version is missing"
grep -Fqx 'display_user=Neo' "$config_path" ||
    fail "migrated settings lost the display user"
grep -Fqx 'theme=neo' "$config_path" ||
    fail "migrated settings theme default mismatch"
grep -Fqx 'color_mode=auto' "$config_path" ||
    fail "migrated settings color default mismatch"
grep -Fqx 'startup_integration=false' "$config_path" ||
    fail "migrated settings startup default mismatch"
[[ "$(stat -c '%a' "$config_path")" == "640" ]] ||
    fail "configuration migration changed settings mode"
[[ -f "$runtime_root/SAME_VERSION_SENTINEL" ]] ||
    fail "configuration-only migration replaced the runtime"
cmp -s "$test_home/.bashrc" "$fixture/bashrc-before-update" ||
    fail "configuration migration changed the Bash startup file"

# Advance once more so an older source can exercise downgrade refusal.
target_newer="$fixture/target-0.4.1-alpha"
make_target "$target_newer" "0.4.1-alpha"
run_updater "$target_newer" 0 "$PATH"
[[ "$($command_path --version)" == "termux-neo 0.4.1-alpha" ]] ||
    fail "second upgrade version mismatch"

printf 'downgrade-refusal-sentinel\n' \
    > "$runtime_root/DOWNGRADE_REFUSAL_SENTINEL"
cp -p "$command_path" "$fixture/command-before-refused-downgrade"
cp -p "$config_path" "$fixture/settings-before-refused-downgrade"
run_updater "$target_upgrade" 1 "$PATH"

grep -Fq 'downgrade refused; use --force-downgrade explicitly' \
    "$stdout_file" ||
    fail "downgrade refusal was not reported"
[[ -f "$runtime_root/DOWNGRADE_REFUSAL_SENTINEL" ]] ||
    fail "refused downgrade changed the runtime"
cmp -s "$command_path" "$fixture/command-before-refused-downgrade" ||
    fail "refused downgrade changed the launcher"
cmp -s "$config_path" "$fixture/settings-before-refused-downgrade" ||
    fail "refused downgrade changed settings"

# The same older target is accepted only with the explicit force flag.
run_updater "$target_upgrade" 0 "$PATH" --force-downgrade
grep -Fqx 'version relation: forced downgrade' "$stdout_file" ||
    fail "forced downgrade relation was not reported"
[[ "$($command_path --version)" == "termux-neo 0.4.0-alpha" ]] ||
    fail "forced downgrade version mismatch"
[[ ! -e "$runtime_root/DOWNGRADE_REFUSAL_SENTINEL" ]] ||
    fail "forced downgrade did not replace the runtime"

# Invalid target shell bytes fail before any installed target is replaced.
target_invalid="$fixture/target-invalid"
make_target "$target_invalid" "0.5.0-alpha"
printf 'if invalid target syntax\n' >> "$target_invalid/src/main.sh"
printf 'preflight-sentinel\n' > "$runtime_root/PREFLIGHT_SENTINEL"
cp -p "$command_path" "$fixture/command-before-invalid-target"
cp -p "$config_path" "$fixture/settings-before-invalid-target"
run_updater "$target_invalid" 1 "$PATH"

grep -Fq 'target shell syntax check failed' "$stdout_file" ||
    fail "invalid target executable failure was not reported"
[[ -f "$runtime_root/PREFLIGHT_SENTINEL" ]] ||
    fail "invalid target executable changed the runtime"
cmp -s "$command_path" "$fixture/command-before-invalid-target" ||
    fail "invalid target executable changed the launcher"
cmp -s "$config_path" "$fixture/settings-before-invalid-target" ||
    fail "invalid target executable changed settings"

# A forced mid-swap failure restores the exact previous installation.
target_failure="$fixture/target-0.5.0-alpha"
make_target "$target_failure" "0.5.0-alpha"
printf 'rollback-sentinel\n' > "$runtime_root/ROLLBACK_SENTINEL"
printf '# rollback-command-sentinel\n' >> "$command_path"
cp "$runtime_root/ROLLBACK_SENTINEL" \
    "$fixture/runtime-sentinel-before-failure"
cp -p "$command_path" "$fixture/command-before-failure"
cp -p "$config_path" "$fixture/settings-before-failure"

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
if (( count == 4 )); then
    exit 77
fi
exec "$TERMUX_NEO_REAL_MV" "$@"
MOCK
chmod 755 "$fake_bin/mv"

export TERMUX_NEO_MV_COUNT_FILE="$mv_count_file"
export TERMUX_NEO_REAL_MV="$real_mv"
run_updater "$target_failure" 1 "$fake_bin:$PATH"
unset TERMUX_NEO_MV_COUNT_FILE TERMUX_NEO_REAL_MV

grep -Fq 'update rolled back; the previous state was restored' "$stdout_file" ||
    fail "update rollback result was not reported"
cmp -s "$runtime_root/ROLLBACK_SENTINEL" \
    "$fixture/runtime-sentinel-before-failure" ||
    fail "rollback did not restore the previous runtime"
cmp -s "$command_path" "$fixture/command-before-failure" ||
    fail "rollback did not restore the previous launcher"
cmp -s "$config_path" "$fixture/settings-before-failure" ||
    fail "failed update changed settings"
cmp -s "$test_home/.bashrc" "$fixture/bashrc-before-update" ||
    fail "failed update changed the Bash startup file"

# A post-swap smoke failure also restores a migrated legacy configuration.
target_smoke_failure="$fixture/target-0.5.1-alpha"
make_target "$target_smoke_failure" "0.5.1-alpha"
printf '\nif [[ "$PROJECT_ROOT" == %q ]]; then\n    exit 88\nfi\n' \
    "$runtime_root" >> "$target_smoke_failure/src/main.sh"
printf 'config-rollback-sentinel\n' \
    > "$runtime_root/CONFIG_ROLLBACK_SENTINEL"
printf 'display_user=RollbackUser\n' > "$config_path"
chmod 600 "$config_path"
cp "$runtime_root/CONFIG_ROLLBACK_SENTINEL" \
    "$fixture/config-rollback-runtime-before"
cp -p "$command_path" "$fixture/config-rollback-command-before"
cp -p "$config_path" "$fixture/config-rollback-settings-before"

run_updater "$target_smoke_failure" 1 "$PATH"

grep -Fq 'updated command failed its smoke test' "$stdout_file" ||
    fail "post-swap smoke failure was not reported"
grep -Fq 'update rolled back; the previous state was restored' "$stdout_file" ||
    fail "post-swap configuration rollback was not reported"
cmp -s "$runtime_root/CONFIG_ROLLBACK_SENTINEL" \
    "$fixture/config-rollback-runtime-before" ||
    fail "post-swap rollback did not restore the runtime"
cmp -s "$command_path" "$fixture/config-rollback-command-before" ||
    fail "post-swap rollback did not restore the launcher"
cmp -s "$config_path" "$fixture/config-rollback-settings-before" ||
    fail "post-swap rollback did not restore legacy settings bytes"
[[ "$(stat -c '%a' "$config_path")" == "600" ]] ||
    fail "post-swap rollback did not restore legacy settings mode"
cmp -s "$test_home/.bashrc" "$fixture/bashrc-before-update" ||
    fail "post-swap rollback changed the Bash startup file"

shopt -s nullglob
leftovers=(
    "$test_prefix/lib"/.termux-neo.update-*
    "$test_prefix/bin"/.termux-neo.update-*
    "$test_home/.config/termux-neo"/.settings.conf.update.*
    "$test_home/.config/termux-neo"/.termux-neo.update-*
)
(( ${#leftovers[@]} == 0 )) ||
    fail "updater left transaction files behind"

if grep -Eq '(^|[[:space:]])(sudo|su)([[:space:]]|$)' update.sh; then
    fail "updater introduces a root command"
fi
if grep -Eq '(^|[^[:alnum:]_])git([^[:alnum:]_]|$)' update.sh; then
    fail "updater requires Git"
fi
if grep -Fq -- '--startup' update.sh; then
    fail "updater invokes startup integration"
fi
if grep -Fq '.bashrc' update.sh; then
    fail "updater references the Bash startup file"
fi

printf 'PASS: safe update and configuration migration\n'
