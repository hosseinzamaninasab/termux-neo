#!/data/data/com.termux/files/usr/bin/bash
set -e

CACHE_DIR="$HOME/.cache/termux-neo"
fixture="$CACHE_DIR/test-config-$$"
mkdir -p "$fixture"
trap 'rm -rf "$fixture"' EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_defaults() {
    [[ "$TERMUX_NEO_CONFIG_SCHEMA_VERSION" == "1" ]] ||
        fail "schema default mismatch"
    [[ -z "$TERMUX_NEO_CONFIG_DISPLAY_USER" ]] ||
        fail "display-user default mismatch"
    [[ "$TERMUX_NEO_CONFIG_THEME" == "neo" ]] ||
        fail "theme default mismatch"
    [[ "$TERMUX_NEO_CONFIG_COLOR_MODE" == "auto" ]] ||
        fail "color-mode default mismatch"
    [[ "$TERMUX_NEO_CONFIG_STARTUP_INTEGRATION" == "false" ]] ||
        fail "startup-integration default mismatch"
}

source_output="$(bash -c 'source src/config.sh')" ||
    fail "config.sh could not be sourced"
[[ -z "$source_output" ]] || fail "sourcing config.sh produced output"

source src/config.sh

termux_neo_config_reset
assert_defaults
[[ "$TERMUX_NEO_CONFIG_SOURCE_SCHEMA_VERSION" == "1" ]] ||
    fail "source schema reset mismatch"

termux_neo_config_load "$fixture/missing.conf" ||
    fail "missing config rejected"
assert_defaults
[[ "$TERMUX_NEO_CONFIG_SOURCE_SCHEMA_VERSION" == "1" ]] ||
    fail "missing config source schema mismatch"

printf '' > "$fixture/empty-file.conf"
termux_neo_config_load "$fixture/empty-file.conf" ||
    fail "empty config rejected"
assert_defaults
[[ "$TERMUX_NEO_CONFIG_SOURCE_SCHEMA_VERSION" == "0" ]] ||
    fail "empty legacy config source schema mismatch"

cat > "$fixture/valid.conf" <<'CONFIG'
# Versioned settings contract
schema_version = 1
display_user = Zoro
theme = matrix
color_mode = never
startup_integration = true
CONFIG

termux_neo_config_load "$fixture/valid.conf" || fail "valid schema rejected"
[[ "$TERMUX_NEO_CONFIG_SCHEMA_VERSION" == "1" ]] || fail "schema mismatch"
[[ "$TERMUX_NEO_CONFIG_SOURCE_SCHEMA_VERSION" == "1" ]] ||
    fail "source schema mismatch"
[[ "$TERMUX_NEO_CONFIG_DISPLAY_USER" == "Zoro" ]] || fail "user mismatch"
[[ "$TERMUX_NEO_CONFIG_THEME" == "matrix" ]] || fail "theme mismatch"
[[ "$TERMUX_NEO_CONFIG_COLOR_MODE" == "never" ]] || fail "color mismatch"
[[ "$TERMUX_NEO_CONFIG_STARTUP_INTEGRATION" == "true" ]] ||
    fail "startup mismatch"

termux_neo_config_validate_schema_version "1" || fail "schema validator"
termux_neo_config_validate_display_user "1234567890123456789012345678" ||
    fail "28-character display user rejected"
if termux_neo_config_validate_display_user "12345678901234567890123456789"; then
    fail "29-character display user accepted"
fi
termux_neo_config_validate_theme "neo" || fail "neo theme validator"
termux_neo_config_validate_theme "matrix" || fail "matrix theme validator"
termux_neo_config_validate_color_mode "auto" || fail "auto color validator"
termux_neo_config_validate_color_mode "always" || fail "always color validator"
termux_neo_config_validate_color_mode "never" || fail "never color validator"
termux_neo_config_validate_startup_integration "true" ||
    fail "true startup validator"
termux_neo_config_validate_startup_integration "false" ||
    fail "false startup validator"

printf 'display_user=Zoro\n' > "$fixture/legacy.conf"
termux_neo_config_load "$fixture/legacy.conf" || fail "legacy schema rejected"
[[ "$TERMUX_NEO_CONFIG_SCHEMA_VERSION" == "1" ]] ||
    fail "legacy schema was not migrated"
[[ "$TERMUX_NEO_CONFIG_SOURCE_SCHEMA_VERSION" == "0" ]] ||
    fail "legacy source schema was not exposed"
[[ "$TERMUX_NEO_CONFIG_DISPLAY_USER" == "Zoro" ]] ||
    fail "legacy display user mismatch"
[[ "$TERMUX_NEO_CONFIG_THEME" == "neo" ]] || fail "legacy theme default"
[[ "$TERMUX_NEO_CONFIG_COLOR_MODE" == "auto" ]] ||
    fail "legacy color default"
[[ "$TERMUX_NEO_CONFIG_STARTUP_INTEGRATION" == "false" ]] ||
    fail "legacy startup default"

termux_neo_config_write_current "$fixture/migrated.conf" ||
    fail "legacy schema could not be serialized"
grep -Fqx 'schema_version=1' "$fixture/migrated.conf" ||
    fail "serialized schema version is missing"
grep -Fqx 'display_user=Zoro' "$fixture/migrated.conf" ||
    fail "serialized display user mismatch"
grep -Fqx 'theme=neo' "$fixture/migrated.conf" ||
    fail "serialized theme default mismatch"
grep -Fqx 'color_mode=auto' "$fixture/migrated.conf" ||
    fail "serialized color default mismatch"
grep -Fqx 'startup_integration=false' "$fixture/migrated.conf" ||
    fail "serialized startup default mismatch"
termux_neo_config_load "$fixture/migrated.conf" ||
    fail "serialized schema could not be reloaded"
[[ "$TERMUX_NEO_CONFIG_SOURCE_SCHEMA_VERSION" == "1" ]] ||
    fail "serialized schema did not become current"
[[ "$TERMUX_NEO_CONFIG_DISPLAY_USER" == "Zoro" ]] ||
    fail "serialized display user did not round-trip"

printf 'display_user=\n' > "$fixture/empty-value.conf"
printf 'display_user=Bad User\n' > "$fixture/space.conf"
printf 'display_user=Bad•User\n' > "$fixture/bullet.conf"
printf 'display_user=12345678901234567890123456789\n' > "$fixture/long.conf"
printf 'schema_version=2\n' > "$fixture/future.conf"
printf 'theme=neo\n' > "$fixture/versionless-v1.conf"
printf 'schema_version=1\nunknown=value\n' > "$fixture/unknown.conf"
printf 'schema_version=1\nschema_version=1\n' > "$fixture/duplicate.conf"
printf 'schema_version=1\ndisplay_user=Zoro\nRoot\n' > "$fixture/multiline.conf"
printf 'schema_version=1\ntheme=cyber\n' > "$fixture/theme.conf"
printf 'schema_version=1\ncolor_mode=maybe\n' > "$fixture/color.conf"
printf 'schema_version=1\nstartup_integration=yes\n' > "$fixture/startup.conf"
printf 'schema_version=1\ndisplay_user=Zoro # inline\n' > "$fixture/inline.conf"
printf 'schema_version=1\ndisplay_user=\tZoro\n' > "$fixture/tab.conf"
printf 'schema_version=1\r\n' > "$fixture/cr.conf"
printf 'schema_version=1\ndisplay_user=\e[31mZoro\n' > "$fixture/escape.conf"

for name in \
    empty-value space bullet long future versionless-v1 unknown duplicate \
    multiline theme color startup inline tab cr escape
do
    termux_neo_config_load "$fixture/valid.conf" || fail "valid reload failed"
    if termux_neo_config_load "$fixture/$name.conf"; then
        fail "invalid config accepted: $name"
    fi
    assert_defaults
done

marker="$fixture/executed"
cat > "$fixture/command.conf" <<CONFIG
schema_version=1
display_user=\$(touch "$marker")
CONFIG

if termux_neo_config_load "$fixture/command.conf"; then
    fail "command-like config accepted"
fi
[[ ! -e "$marker" ]] || fail "config content executed"
assert_defaults

termux_neo_config_load "config/settings.conf" ||
    fail "production settings file rejected"
[[ "$TERMUX_NEO_CONFIG_DISPLAY_USER" == "Zoro" ]] ||
    fail "production display user mismatch"

termux_neo_config_load "config/settings.example.conf" ||
    fail "user-facing settings example rejected"

resolved="$(termux_neo_config_resolve_display_user "Neo" "u0_a191")"
[[ "$resolved" == "Neo" ]] || fail "valid override did not win"

resolved="$(termux_neo_config_resolve_display_user "Bad User" "u0_a191")"
[[ "$resolved" == "Zoro" ]] || fail "invalid override bypassed config"

source src/main.sh

TEST_TERM_WIDTH=56
tput() {
    [[ "${1-}" == "cols" ]] || return 1
    printf '%s' "$TEST_TERM_WIDTH"
}

module_device_user() { printf 'u0_a191'; }
module_device_name() { printf 'Samsung Note5'; }
module_system_name() { printf 'Android 11'; }
module_network_type() { printf 'Wi-Fi'; }
module_network_local_ip() { printf '192.168.0.135'; }
module_network_state() { printf 'UP'; }
module_vpn_state() { printf 'OFF'; }
module_battery_value() { printf '54'; }
module_time_value() { printf '07:03'; }

TERMUX_NEO_CONFIG_PATH="$fixture/valid.conf"
TERMUX_NEO_USER=""
termux_neo_prepare_state || fail "configured state failed"
[[ "${UI_ROWS[0]}" == "USER|Zoro" ]] || fail "Dashboard config mismatch"
[[ "$UI_PROMPT_USER" == "Zoro" ]] || fail "Prompt config mismatch"

TERMUX_NEO_USER="Neo"
termux_neo_prepare_state || fail "environment override failed"
[[ "${UI_ROWS[0]}" == "USER|Neo" ]] || fail "Dashboard override mismatch"
[[ "$UI_PROMPT_USER" == "Neo" ]] || fail "Prompt override mismatch"

TERMUX_NEO_USER="Bad User"
termux_neo_prepare_state || fail "invalid override fallback failed"
[[ "${UI_ROWS[0]}" == "USER|Zoro" ]] || fail "invalid override bypassed config"
[[ "$UI_PROMPT_USER" == "Zoro" ]] || fail "Prompt invalid override mismatch"

TERMUX_NEO_CONFIG_PATH="$fixture/missing.conf"
TERMUX_NEO_USER=""
termux_neo_prepare_state || fail "system fallback failed"
[[ "${UI_ROWS[0]}" == "USER|u0_a191" ]] ||
    fail "system Dashboard fallback mismatch"
[[ "$UI_PROMPT_USER" == "u0_a191" ]] ||
    fail "system Prompt fallback mismatch"

TERMUX_NEO_CONFIG_PATH="$fixture/theme.conf"
if termux_neo_render_once >"$fixture/out" 2>"$fixture/err"; then
    fail "invalid config rendered"
fi
[[ ! -s "$fixture/out" ]] || fail "invalid config produced partial output"
[[ ! -s "$fixture/err" ]] || fail "invalid config produced stderr"

printf 'PASS: versioned settings schema\n'
printf 'PASS: settings defaults and validation\n'
printf 'PASS: settings migration rules\n'
printf 'PASS: shared Dashboard and Prompt user\n'
