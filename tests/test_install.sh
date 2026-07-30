#!/data/data/com.termux/files/usr/bin/bash
set -e

CACHE_DIR="$HOME/.cache/termux-neo"
fixture="$CACHE_DIR/test-install-$$"
termux_files="$fixture/files"
test_home="$termux_files/home"
test_prefix="$termux_files/usr"
runtime_root="$test_prefix/lib/termux-neo"
command_path="$test_prefix/bin/termux-neo"
config_path="$test_home/.config/termux-neo/settings.conf"
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
    local expected_status="${1-0}"
    local actual_status=0
    local path_value="${2-$PATH}"

    : > "$stdout_file"
    : > "$stderr_file"
    set +e
    HOME="$test_home" PREFIX="$test_prefix" PATH="$path_value" \
        bash install.sh > "$stdout_file" 2> "$stderr_file"
    actual_status=$?
    set -e

    [[ "$actual_status" == "$expected_status" ]] ||
        fail "installer status mismatch: expected $expected_status, got $actual_status"
}

printf 'export EXISTING_VALUE=kept\n' > "$test_home/.bashrc"
cp "$test_home/.bashrc" "$fixture/bashrc-before-install"

# A clean install creates the production layout and user configuration.
run_installer 0
[[ ! -s "$stderr_file" ]] || fail "clean install produced stderr"
grep -Fqx 'Termux Neo installation complete' "$stdout_file" ||
    fail "clean install completion line is missing"
grep -Fqx "changed: created $runtime_root" "$stdout_file" ||
    fail "runtime path change was not reported"
grep -Fqx "changed: created $command_path" "$stdout_file" ||
    fail "command path change was not reported"
grep -Fqx "changed: created $config_path" "$stdout_file" ||
    fail "configuration path change was not reported"
grep -Fqx 'startup integration: unchanged' "$stdout_file" ||
    fail "startup no-change result was not reported"

[[ -d "$runtime_root" && ! -L "$runtime_root" ]] ||
    fail "runtime root was not installed as a directory"
[[ -x "$runtime_root/bin/termux-neo" && -x "$command_path" ]] ||
    fail "installed commands are not executable"
[[ ! -e "$runtime_root/tests" ]] || fail "development tests were installed"
[[ -f "$runtime_root/INSTALL_MANIFEST" ]] ||
    fail "installation manifest is missing"
[[ -f "$runtime_root/docs/update.md" ]] ||
    fail "installed update documentation is missing"
[[ -f "$runtime_root/docs/uninstallation.md" ]] ||
    fail "installed uninstallation documentation is missing"
[[ -f "$runtime_root/docs/release-artifacts.md" ]] ||
    fail "installed release artifact documentation is missing"
grep -Fqx 'format=1' "$runtime_root/INSTALL_MANIFEST" ||
    fail "installation manifest format is missing"
grep -Fqx 'product=termux-neo' "$runtime_root/INSTALL_MANIFEST" ||
    fail "installation manifest ownership is missing"

cmp -s config/settings.example.conf "$config_path" ||
    fail "first install did not create settings from the example"
[[ "$(stat -c '%a' "$config_path")" == "600" ]] ||
    fail "new user settings mode is not 600"
[[ "$($command_path --version)" == "termux-neo 1.0.0" ]] ||
    fail "installed version command failed"
[[ "$(HOME="$test_home" $command_path --config)" == "$config_path" ]] ||
    fail "installed launcher did not select the user settings path"
cmp -s "$test_home/.bashrc" "$fixture/bashrc-before-install" ||
    fail "installer changed the Bash startup file"

resolved_startup_command="$(
    HOME="$test_home" \
    TERMUX_NEO_CONFIG_PATH="$config_path" \
    TERMUX_NEO_COMMAND_PATH="$command_path" \
        bash -c 'source "$1/src/main.sh"; termux_neo_startup_command' \
        _ "$runtime_root"
)" || fail "installed startup command could not be resolved"
[[ "$resolved_startup_command" == "$command_path" ]] ||
    fail "startup integration did not retain the stable installed command"

# Reinstallation preserves existing settings byte-for-byte.
printf '%s\n' \
    'schema_version=1' \
    'display_user=Zoro' \
    'theme=matrix' \
    'color_mode=never' \
    'startup_integration=false' > "$config_path"
chmod 640 "$config_path"
cp -p "$config_path" "$fixture/settings-before-reinstall"

run_installer 0
[[ ! -s "$stderr_file" ]] || fail "reinstall produced stderr"
grep -Fqx "changed: replaced $runtime_root" "$stdout_file" ||
    fail "runtime replacement was not reported"
grep -Fqx "changed: replaced $command_path" "$stdout_file" ||
    fail "command replacement was not reported"
grep -Fqx "preserved: $config_path" "$stdout_file" ||
    fail "preserved configuration was not reported"
cmp -s "$config_path" "$fixture/settings-before-reinstall" ||
    fail "reinstall changed existing settings"
[[ "$(stat -c '%a' "$config_path")" == "640" ]] ||
    fail "reinstall changed existing settings mode"
cmp -s "$test_home/.bashrc" "$fixture/bashrc-before-install" ||
    fail "reinstall changed the Bash startup file"

# A failure after runtime replacement restores the exact prior installation.
printf 'rollback-sentinel\n' > "$runtime_root/ROLLBACK_SENTINEL"
cp "$runtime_root/ROLLBACK_SENTINEL" "$fixture/runtime-sentinel-before-failure"
cp "$command_path" "$fixture/command-before-failure"
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
run_installer 1 "$fake_bin:$PATH"
unset TERMUX_NEO_MV_COUNT_FILE TERMUX_NEO_REAL_MV

grep -Fq 'installation rolled back; the previous state was restored' "$stderr_file" ||
    fail "rollback result was not reported"
cmp -s "$runtime_root/ROLLBACK_SENTINEL" \
    "$fixture/runtime-sentinel-before-failure" ||
    fail "rollback did not restore the previous runtime"
cmp -s "$command_path" "$fixture/command-before-failure" ||
    fail "rollback did not restore the previous command"
cmp -s "$config_path" "$fixture/settings-before-failure" ||
    fail "failed install changed existing settings"
cmp -s "$test_home/.bashrc" "$fixture/bashrc-before-install" ||
    fail "failed install changed the Bash startup file"

shopt -s nullglob
leftovers=(
    "$test_prefix/lib"/.termux-neo.*
    "$test_prefix/bin"/.termux-neo.*
    "$test_home/.config/termux-neo"/.settings.conf.*
)
(( ${#leftovers[@]} == 0 )) || fail "installer left transaction files behind"

# A non-Termux PREFIX relation fails before creating an installation.
invalid_prefix="$fixture/not-termux-prefix"
: > "$stdout_file"
: > "$stderr_file"
set +e
HOME="$test_home" PREFIX="$invalid_prefix" bash install.sh \
    > "$stdout_file" 2> "$stderr_file"
invalid_status=$?
set -e
(( invalid_status != 0 )) || fail "invalid PREFIX relation was accepted"
[[ ! -e "$invalid_prefix" ]] || fail "invalid PREFIX was created or changed"

if grep -Eq '(^|[[:space:]])(sudo|su)([[:space:]]|$)' install.sh; then
    fail "installer introduces a root command"
fi
if grep -Fq -- '--startup' install.sh; then
    fail "installer invokes startup integration"
fi

printf 'PASS: production installer transaction\n'
