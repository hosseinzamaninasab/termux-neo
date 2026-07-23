#!/data/data/com.termux/files/usr/bin/bash
set -e

CACHE_DIR="$HOME/.cache/termux-neo"
fixture="$CACHE_DIR/test-diagnostics-$$"
stdout_file="$fixture/stdout"
stderr_file="$fixture/stderr"

mkdir -p "$fixture"
trap 'rm -rf "$fixture"' EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

run_diagnostics() {
    local expected_status="$1"
    local actual_status=0

    : > "$stdout_file"
    : > "$stderr_file"

    set +e
    termux_neo_cli_dispatch --diagnose > "$stdout_file" 2> "$stderr_file"
    actual_status=$?
    set -e

    [[ "$actual_status" == "$expected_status" ]] ||
        fail "unexpected diagnostics status: $actual_status"
    [[ ! -s "$stderr_file" ]] || fail "diagnostics produced stderr"
}

source src/main.sh

cat > "$fixture/settings.conf" <<'CONFIG'
schema_version=1
display_user=Zoro
theme=matrix
color_mode=never
startup_integration=false
CONFIG

TERMUX_NEO_CONFIG_PATH="$fixture/settings.conf"
TERMUX_NEO_TEST_SECRET="do-not-print-this"

module_command_exists() {
    case "${1-}" in
        ip|termux-battery-status|getprop|tput) return 0 ;;
        *) return 1 ;;
    esac
}

tput() {
    [[ "${1-}" == "cols" ]] || return 1
    printf '56'
}

module_device_user() { printf 'u0_a191'; }
module_device_name() { printf 'Samsung Note5'; }
module_system_name() { printf 'Android 11'; }
module_network_type() { printf 'Wi-Fi'; }
module_network_state() { printf 'UP'; }
module_network_local_ip() { printf '192.168.0.135'; }
module_network_local_ip_source() { printf 'ifconfig'; }
module_vpn_state() { printf 'ON'; }
module_battery_value() { printf '82+'; }
module_battery_source() { printf 'sysfs'; }
module_time_value() { printf '21:35'; }

render_count=0
termux_neo_render_once() {
    (( render_count += 1 ))
    return 1
}

run_diagnostics 0

mapfile -t lines < "$stdout_file"
(( ${#lines[@]} == 26 )) || fail "diagnostics report line count mismatch"

grep -Fqx 'TERMUX NEO DIAGNOSTICS' "$stdout_file" ||
    fail "diagnostics heading mismatch"
grep -Fqx 'VERSION: 0.5.0-beta' "$stdout_file" ||
    fail "diagnostics version mismatch"
grep -Fqx "INSTALLATION_PATH: $PROJECT_ROOT" "$stdout_file" ||
    fail "diagnostics installation path mismatch"
grep -Fqx "CONFIG_PATH: $TERMUX_NEO_CONFIG_PATH" "$stdout_file" ||
    fail "diagnostics config path mismatch"
grep -Fqx 'CONFIG_STATUS: valid' "$stdout_file" ||
    fail "valid config status mismatch"
grep -Fqx 'SCHEMA_STATUS: v1' "$stdout_file" ||
    fail "valid schema status mismatch"
grep -Fqx 'TERMINAL_WIDTH: 56' "$stdout_file" ||
    fail "terminal width mismatch"
grep -Fqx 'THEME: matrix' "$stdout_file" || fail "theme mismatch"
grep -Fqx 'COLOR_MODE: never' "$stdout_file" || fail "color mode mismatch"
grep -Fqx 'OPTIONAL_COMMAND ip: available' "$stdout_file" ||
    fail "optional ip status mismatch"
grep -Fqx 'OPTIONAL_COMMAND ifconfig: unavailable' "$stdout_file" ||
    fail "optional ifconfig status mismatch"
grep -Fqx 'OPTIONAL_COMMAND termux-battery-status: available' "$stdout_file" ||
    fail "optional battery command status mismatch"
grep -Fqx 'OPTIONAL_COMMAND dumpsys: unavailable' "$stdout_file" ||
    fail "optional dumpsys status mismatch"
grep -Fqx 'OPTIONAL_COMMAND getprop: available' "$stdout_file" ||
    fail "optional getprop status mismatch"
grep -Fqx 'NETWORK_SOURCE: ifconfig' "$stdout_file" ||
    fail "network source mismatch"
grep -Fqx 'BATTERY_SOURCE: sysfs' "$stdout_file" ||
    fail "battery source mismatch"
grep -Fqx 'DISPLAY_USER: Zoro' "$stdout_file" ||
    fail "display user mismatch"
grep -Fqx 'SYSTEM_USER: u0_a191' "$stdout_file" ||
    fail "system user mismatch"
grep -Fqx 'DEVICE: Samsung Note5' "$stdout_file" || fail "device mismatch"
grep -Fqx 'SYSTEM: Android 11' "$stdout_file" || fail "system mismatch"
grep -Fqx 'NETWORK_TYPE: Wi-Fi' "$stdout_file" ||
    fail "network type mismatch"
grep -Fqx 'NETWORK_STATE: UP' "$stdout_file" ||
    fail "network state mismatch"
grep -Fqx 'LOCAL_IP: 192.168.0.135' "$stdout_file" ||
    fail "local IP mismatch"
grep -Fqx 'VPN_STATE: ON' "$stdout_file" || fail "VPN state mismatch"
grep -Fqx 'BATTERY: 82+' "$stdout_file" || fail "battery mismatch"
grep -Fqx 'TIME: 21:35' "$stdout_file" || fail "time mismatch"

(( render_count == 0 )) || fail "diagnostics invoked the UI renderer"
if grep -Fq "$TERMUX_NEO_TEST_SECRET" "$stdout_file"; then
    fail "diagnostics leaked an unrelated environment value"
fi
if grep -q $'\e\[' "$stdout_file"; then
    fail "diagnostics emitted ANSI color"
fi

cat > "$fixture/invalid.conf" <<'CONFIG'
schema_version=1
display_user=Zoro
unknown_key=value
CONFIG

TERMUX_NEO_CONFIG_PATH="$fixture/invalid.conf"
run_diagnostics 1
(( $(wc -l < "$stdout_file") == 26 )) ||
    fail "invalid-config diagnostics report was incomplete"
grep -Fqx 'CONFIG_STATUS: invalid' "$stdout_file" ||
    fail "invalid config status mismatch"
grep -Fqx 'SCHEMA_STATUS: invalid' "$stdout_file" ||
    fail "invalid schema status mismatch"
grep -Fqx 'THEME: neo' "$stdout_file" ||
    fail "invalid config did not preserve safe theme default"

TERMUX_NEO_CONFIG_PATH="$fixture/missing.conf"
run_diagnostics 0
grep -Fqx 'CONFIG_STATUS: missing (defaults)' "$stdout_file" ||
    fail "missing config status mismatch"
grep -Fqx 'SCHEMA_STATUS: v1 (defaults)' "$stdout_file" ||
    fail "missing schema status mismatch"

TERMUX_NEO_CONFIG_PATH=$'bad\npath'
run_diagnostics 1
grep -Fqx 'CONFIG_PATH: Unavailable' "$stdout_file" ||
    fail "unsafe config path was exposed"
grep -Fqx 'CONFIG_STATUS: invalid-path' "$stdout_file" ||
    fail "invalid config path status mismatch"

grep -Fq "source \"\$SCRIPT_DIR/diagnostics.sh\"" src/main.sh ||
    fail "main.sh does not load the diagnostics boundary"
grep -Fq 'declare -F termux_neo_diagnose' src/cli.sh ||
    fail "CLI does not use the stable diagnostics hook"
grep -Fq 'NETWORK_SOURCE' docs/cli.md ||
    fail "diagnostics source fields are undocumented"

printf 'PASS: built-in diagnostics\n'
