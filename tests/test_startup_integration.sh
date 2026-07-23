#!/data/data/com.termux/files/usr/bin/bash
set -e

ORIGINAL_HOME="$HOME"
CACHE_DIR="$HOME/.cache/termux-neo"
fixture="$CACHE_DIR/test-startup-integration-$$"
test_home="$fixture/home"
config_file="$fixture/settings.conf"
fake_command="$fixture/termux-neo"
stdout_file="$fixture/stdout"
stderr_file="$fixture/stderr"
probe_file="$fixture/probe"

mkdir -p "$test_home"
trap 'HOME="$ORIGINAL_HOME"; rm -rf "$fixture"' EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

write_config() {
    local enabled="${1-}"

    printf '%s\n' \
        'schema_version=1' \
        'display_user=Zoro' \
        'theme=neo' \
        'color_mode=never' \
        "startup_integration=$enabled" > "$config_file"
}

source_output="$(bash -c 'source src/main.sh')" ||
    fail "main.sh could not be sourced"
[[ -z "$source_output" ]] || fail "sourcing main.sh produced output"

source src/main.sh

printf '#!%s\n' "$(command -v bash)" > "$fake_command"
cat >> "$fake_command" <<'MOCK'
printf 'started\n' >> "$STARTUP_PROBE_FILE"
printf 'startup-rendered\n'
MOCK
chmod 755 "$fake_command"

termux_neo_startup_command() {
    printf '%s' "$fake_command"
}

HOME="$test_home"
export HOME
TERMUX_NEO_CONFIG_PATH="$config_file"

printf '%s\n' 'export EXISTING_VALUE=kept' 'alias ll="ls -l"' > "$HOME/.bashrc"
cp "$HOME/.bashrc" "$fixture/original-bashrc"

# Disabled is the safe default and performs no edit.
write_config false
termux_neo_startup_sync > "$stdout_file" 2> "$stderr_file" ||
    fail "disabled startup synchronization failed"
[[ ! -s "$stderr_file" ]] || fail "disabled synchronization produced stderr"
cmp -s "$HOME/.bashrc" "$fixture/original-bashrc" ||
    fail "disabled synchronization changed .bashrc"
[[ ! -e "$HOME/.cache/termux-neo/startup-backups" ]] ||
    fail "no-op synchronization created a backup"

# Enabling creates one managed interactive-Bash block and one backup.
write_config true
termux_neo_startup_sync > "$stdout_file" 2> "$stderr_file" ||
    fail "startup installation failed"
[[ ! -s "$stderr_file" ]] || fail "startup installation produced stderr"
grep -Fqx 'startup integration: enabled' "$stdout_file" ||
    fail "enabled status is missing"
[[ "$(grep -Fxc "$TERMUX_NEO_STARTUP_BEGIN_MARKER" "$HOME/.bashrc")" == "1" ]] ||
    fail "startup begin marker is not unique"
[[ "$(grep -Fxc "$TERMUX_NEO_STARTUP_END_MARKER" "$HOME/.bashrc")" == "1" ]] ||
    fail "startup end marker is not unique"
if grep -Fq 'PS1' "$HOME/.bashrc"; then
    fail "startup block changes the shell prompt"
fi
[[ ! -e "$HOME/.zshrc" && ! -e "$HOME/.profile" ]] ||
    fail "unsupported shell startup files were modified"

backup_files=("$HOME"/.cache/termux-neo/startup-backups/bashrc.*.bak)
(( ${#backup_files[@]} == 1 )) || fail "installation backup count mismatch"
cmp -s "${backup_files[0]}" "$fixture/original-bashrc" ||
    fail "installation backup does not match the pre-edit file"

# A second install is byte-idempotent and does not create another backup.
cp "$HOME/.bashrc" "$fixture/enabled-bashrc"
termux_neo_startup_sync > "$stdout_file" 2> "$stderr_file" ||
    fail "idempotent startup installation failed"
cmp -s "$HOME/.bashrc" "$fixture/enabled-bashrc" ||
    fail "second startup installation changed .bashrc"
backup_files=("$HOME"/.cache/termux-neo/startup-backups/bashrc.*.bak)
(( ${#backup_files[@]} == 1 )) || fail "no-op installation created a backup"

# The hook runs once for an interactive Bash and remains silent otherwise.
: > "$probe_file"
STARTUP_PROBE_FILE="$probe_file" \
    bash --noprofile --rcfile "$HOME/.bashrc" -i -c 'exit' \
    > "$stdout_file" 2> "$stderr_file" ||
    fail "interactive Bash startup failed"
[[ "$(grep -c '^started$' "$probe_file")" == "1" ]] ||
    fail "interactive Bash did not render exactly once"
grep -Fq 'startup-rendered' "$stdout_file" ||
    fail "interactive Bash did not invoke the managed command"

: > "$probe_file"
STARTUP_PROBE_FILE="$probe_file" \
    bash --noprofile --rcfile "$HOME/.bashrc" -c 'exit' \
    > "$stdout_file" 2> "$stderr_file" ||
    fail "non-interactive Bash check failed"
[[ ! -s "$probe_file" ]] || fail "non-interactive Bash invoked the startup hook"

# Disabling removes only the marked block and backs up the enabled file.
write_config false
termux_neo_startup_sync > "$stdout_file" 2> "$stderr_file" ||
    fail "startup removal failed"
[[ ! -s "$stderr_file" ]] || fail "startup removal produced stderr"
grep -Fqx 'startup integration: disabled' "$stdout_file" ||
    fail "disabled status is missing"
cmp -s "$HOME/.bashrc" "$fixture/original-bashrc" ||
    fail "startup removal did not preserve the original .bashrc"
backup_files=("$HOME"/.cache/termux-neo/startup-backups/bashrc.*.bak)
(( ${#backup_files[@]} == 2 )) || fail "removal backup count mismatch"

# Repeated removal is a no-op.
termux_neo_startup_sync > "$stdout_file" 2> "$stderr_file" ||
    fail "idempotent startup removal failed"
cmp -s "$HOME/.bashrc" "$fixture/original-bashrc" ||
    fail "second startup removal changed .bashrc"
backup_files=("$HOME"/.cache/termux-neo/startup-backups/bashrc.*.bak)
(( ${#backup_files[@]} == 2 )) || fail "no-op removal created a backup"

# Invalid config and damaged markers fail closed without editing.
printf '%s\n' 'schema_version=1' 'startup_integration=yes' > "$config_file"
cp "$HOME/.bashrc" "$fixture/before-invalid-config"
if termux_neo_startup_sync > "$stdout_file" 2> "$stderr_file"; then
    fail "invalid startup configuration was accepted"
fi
cmp -s "$HOME/.bashrc" "$fixture/before-invalid-config" ||
    fail "invalid startup configuration changed .bashrc"

write_config true
printf '%s\n' \
    'export EXISTING_VALUE=kept' \
    "$TERMUX_NEO_STARTUP_BEGIN_MARKER" \
    'incomplete managed block' > "$HOME/.bashrc"
cp "$HOME/.bashrc" "$fixture/before-invalid-markers"
if termux_neo_startup_sync > "$stdout_file" 2> "$stderr_file"; then
    fail "incomplete startup markers were accepted"
fi
cmp -s "$HOME/.bashrc" "$fixture/before-invalid-markers" ||
    fail "invalid startup markers changed .bashrc"

printf 'PASS: optional Bash startup integration\n'
