#!/data/data/com.termux/files/usr/bin/bash
set -e

CACHE_DIR="$HOME/.cache/termux-neo"
fixture="$CACHE_DIR/test-compatibility-$$"
network_root="$fixture/net"
power_root="$fixture/power"
fake_bin="$fixture/bin"
test_home="$fixture/home"
original_home="$HOME"
original_pwd="$PWD"

mkdir -p "$network_root" "$power_root" "$fake_bin" "$test_home/Projects/demo"

cleanup() {
    cd "$original_pwd" >/dev/null 2>&1 || true
    HOME="$original_home"
    export HOME
    rm -rf "$fixture"
}

trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

source src/main.sh

export TERMUX_NEO_NET_CLASS_ROOT="$network_root"
export TERMUX_NEO_POWER_SUPPLY_ROOT="$power_root"

reset_network_fixture() {
    rm -rf "$network_root"
    mkdir -p "$network_root"
}

add_interface() {
    local name="$1"
    local state="$2"

    mkdir -p "$network_root/$name"
    printf '%s\n' "$state" > "$network_root/$name/operstate"
}

disable_optional_commands() {
    module_command_exists() {
        return 1
    }
}

assert_network_case() {
    local expected_type="$1"
    local expected_state="$2"
    local expected_vpn="$3"
    local actual_type=""
    local actual_state=""
    local actual_vpn=""

    actual_type="$(module_network_type)"
    actual_state="$(module_network_state)"
    actual_vpn="$(module_vpn_state)"

    [[ "$actual_type" == "$expected_type" ]] ||
        fail "network type mismatch: expected $expected_type, got $actual_type"
    [[ "$actual_state" == "$expected_state" ]] ||
        fail "network state mismatch: expected $expected_state, got $actual_state"
    [[ "$actual_vpn" == "$expected_vpn" ]] ||
        fail "VPN state mismatch: expected $expected_vpn, got $actual_vpn"
}

# Wi-Fi, mobile, offline, and VPN interface fixtures.
disable_optional_commands

reset_network_fixture
add_interface wlan0 up
assert_network_case "Wi-Fi" "UP" "OFF"

reset_network_fixture
add_interface rmnet_data0 unknown
assert_network_case "Mobile" "UP" "OFF"

reset_network_fixture
add_interface wlan0 down
assert_network_case "Offline" "DOWN" "OFF"

reset_network_fixture
add_interface tun0 up
assert_network_case "VPN" "UP" "ON"

# Missing optional commands remain silent and use safe fallbacks.
reset_network_fixture
rm -rf "$power_root"
mkdir -p "$power_root"

stderr_file="$fixture/missing.stderr"
{
    [[ "$(module_network_type)" == "Offline" ]] ||
        fail "missing commands did not produce Offline"
    [[ "$(module_network_local_ip)" == "Unavailable" ]] ||
        fail "missing commands did not hide the local IP"
    [[ "$(module_network_local_ip_source)" == "unavailable" ]] ||
        fail "missing commands did not report unavailable network source"
    [[ "$(module_battery_value)" == "--" ]] ||
        fail "missing commands did not produce unavailable battery"
    [[ "$(module_battery_source)" == "unavailable" ]] ||
        fail "missing commands did not report unavailable battery source"
} 2> "$stderr_file"

[[ ! -s "$stderr_file" ]] ||
    fail "missing optional commands produced stderr"

# Permission-denied command sources are suppressed at the module boundary.
for command_name in ip ifconfig getprop termux-battery-status dumpsys
do
    {
        printf '%s\n' '#!/data/data/com.termux/files/usr/bin/bash'
        printf '%s\n' 'printf "Permission denied\n" >&2'
        printf '%s\n' 'exit 126'
    } > "$fake_bin/$command_name"
    chmod 755 "$fake_bin/$command_name"
done

source src/modules/common.sh
PATH="$fake_bin:$PATH"
export PATH

permission_stderr="$fixture/permission.stderr"
{
    [[ "$(module_network_type)" == "Offline" ]] ||
        fail "permission failure did not produce Offline"
    [[ "$(module_network_local_ip)" == "Unavailable" ]] ||
        fail "permission failure leaked a local IP"
    [[ "$(module_network_local_ip_source)" == "unavailable" ]] ||
        fail "permission failure did not report unavailable network source"
    [[ "$(module_battery_value)" == "--" ]] ||
        fail "permission failure did not produce unavailable battery"
    [[ "$(module_battery_source)" == "unavailable" ]] ||
        fail "permission failure did not report unavailable battery source"
} 2> "$permission_stderr"

[[ ! -s "$permission_stderr" ]] ||
    fail "permission-denied sources produced raw stderr"

# Charging, discharging, full, and unavailable battery fixtures.
disable_optional_commands

assert_battery_case() {
    local percentage="$1"
    local status="$2"
    local expected="$3"
    local record=""
    local value=""

    rm -rf "$power_root"
    mkdir -p "$power_root/battery"
    printf '%s\n' "Battery" > "$power_root/battery/type"
    printf '%s\n' "$percentage" > "$power_root/battery/capacity"
    printf '%s\n' "$status" > "$power_root/battery/status"

    record="$(module_battery_from_sysfs)" ||
        fail "battery fixture was rejected: $status"
    value="$(module_battery_format_record "$record")" ||
        fail "battery fixture could not be formatted: $status"

    [[ "$value" == "$expected" ]] ||
        fail "battery $status mismatch: expected $expected, got $value"
}

assert_battery_case 61 Charging "61+"
assert_battery_case 60 Discharging "60"
assert_battery_case 100 Full "100+"

rm -rf "$power_root"
mkdir -p "$power_root"
[[ "$(module_battery_value)" == "--" ]] ||
    fail "unavailable battery did not produce --"
[[ "$(module_battery_source)" == "unavailable" ]] ||
    fail "unavailable battery source mismatch"

# Reference device values remain sanitized and fixture-testable.
module_command_exists() {
    [[ "${1-}" == "getprop" ]]
}

getprop() {
    case "${1-}" in
        ro.product.manufacturer) printf 'samsung' ;;
        ro.product.model) printf 'SM-N920C' ;;
        ro.build.version.release) printf '11' ;;
        *) return 1 ;;
    esac
}

[[ "$(module_device_name)" == "samsung SM-N920C" ]] ||
    fail "reference device fixture mismatch"
[[ "$(module_system_name)" == "Android 11" ]] ||
    fail "reference Android fixture mismatch"

# Width and working-directory matrix through the complete render-once flow.
TEST_TERM_WIDTH=56
tput() {
    [[ "${1-}" == "cols" ]] || return 1
    printf '%s' "$TEST_TERM_WIDTH"
}

module_device_user() { printf 'Zoro'; }
module_device_name() { printf 'Samsung Note5'; }
module_system_name() { printf 'Android 11'; }
module_network_type() { printf 'Wi-Fi'; }
module_network_local_ip() { printf '192.168.0.135'; }
module_network_state() { printf 'UP'; }
module_vpn_state() { printf 'ON'; }
module_battery_value() { printf '82+'; }
module_time_value() { printf '21:35'; }

HOME="$test_home"
export HOME
TERMUX_NEO_CONFIG_PATH="$fixture/missing-settings.conf"
export TERMUX_NEO_CONFIG_PATH

assert_render_case() {
    local width="$1"
    local directory="$2"
    local expected_prompt="$3"
    local expected_margin="$4"
    local output=""
    local line=""
    local margin=""
    local line_count=0

    TEST_TERM_WIDTH="$width"
    cd "$directory"

    output="$(termux_neo_render_once)" ||
        fail "render failed for width $width and $directory"

    printf -v margin '%*s' "$expected_margin" ""

    while IFS= read -r line
    do
        (( line_count += 1 ))
        (( ${#line} <= width )) ||
            fail "width $width produced an overlong line"
    done <<< "$output"

    (( line_count == 16 )) ||
        fail "width $width produced $line_count lines"
    [[ "${output:0:expected_margin}" == "$margin" ]] ||
        fail "width $width produced the wrong common margin"
    [[ "$output" == *"╭─ Zoro • $expected_prompt"* ]] ||
        fail "working-directory prompt mismatch at width $width"
}

assert_render_case 34 "$HOME" "~" 0
assert_render_case 56 "$HOME" "~" 6
assert_render_case 94 "$HOME/Projects/demo" "~/Projects/demo" 25

# Bash is the verified CLI and interactive-startup shell boundary.
cd "$original_pwd"
[[ -n "${BASH_VERSION-}" ]] || fail "compatibility test is not running in Bash"
[[ "$(bash src/main.sh --version)" == "termux-neo 1.0.0" ]] ||
    fail "Bash CLI invocation failed"
grep -Fq 'Only `~/.bashrc` integration is supported' docs/compatibility.md ||
    fail "Bash-only startup support is undocumented"
grep -Fq 'No distribution-specific claim' docs/compatibility.md ||
    fail "Termux distribution boundary is undocumented"

printf 'PASS: documented compatibility matrix\n'
