#!/data/data/com.termux/files/usr/bin/bash
set -e

source src/modules/common.sh
source src/modules/device.sh
source src/modules/network.sh
source src/modules/vpn.sh
source src/modules/battery.sh
source src/modules/datetime.sh

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_safe_output() {
    local name="$1"
    local value="$2"

    [[ -n "$value" ]] ||
        fail "$name returned empty output"

    [[ "$value" != *$'\n'* ]] ||
        fail "$name returned a newline"

    [[ "$value" != *$'\r'* ]] ||
        fail "$name returned a carriage return"

    [[ "$value" != *$'\t'* ]] ||
        fail "$name returned a tab"

    [[ "$value" != *$'\e'* ]] ||
        fail "$name returned an escape character"

    [[ "$value" != *"|"* ]] ||
        fail "$name returned the state delimiter"
}

run_silent() {
    local function_name="$1"
    local output_file
    local error_file
    local value

    output_file="$HOME/.cache/termux-neo/test-module-output"
    error_file="$HOME/.cache/termux-neo/test-module-error"

    rm -f "$output_file" "$error_file"

    "$function_name" > "$output_file" 2> "$error_file" ||
        fail "$function_name returned failure"

    [[ ! -s "$error_file" ]] ||
        fail "$function_name produced stderr output"

    value="$(cat "$output_file")"

    rm -f "$output_file" "$error_file"

    assert_safe_output "$function_name" "$value"
    printf '%s' "$value"
}

user_value="$(run_silent module_device_user)"
device_value="$(run_silent module_device_name)"
system_value="$(run_silent module_system_name)"
network_state="$(run_silent module_network_state)"
network_type="$(run_silent module_network_type)"
local_ip="$(run_silent module_network_local_ip)"
vpn_state="$(run_silent module_vpn_state)"
battery_value="$(run_silent module_battery_value)"
time_value="$(run_silent module_time_value)"

[[ "$network_state" == "UP" || "$network_state" == "DOWN" ]] ||
    fail "invalid network state: $network_state"

[[ "$vpn_state" == "ON" || "$vpn_state" == "OFF" ]] ||
    fail "invalid VPN state: $vpn_state"

[[ "$battery_value" == "--" || "$battery_value" =~ ^[0-9]{1,3}\+?$ ]] ||
    fail "invalid battery value: $battery_value"

if [[ "$battery_value" != "--" ]]; then
    battery_number="${battery_value%+}"
    (( battery_number >= 0 && battery_number <= 100 )) ||
        fail "battery value outside valid range"
fi

[[ "$time_value" == "--:--" || "$time_value" =~ ^[0-9]{2}:[0-9]{2}$ ]] ||
    fail "invalid time value: $time_value"

[[ "$local_ip" == "Unavailable" || "$local_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] ||
    fail "invalid local IP value: $local_ip"

cleaned="$(module_clean_value $'  A|B\nC\tD  ' "Fallback")"

[[ "$cleaned" == "AB C D" ]] ||
    fail "module_clean_value mismatch: $cleaned"

printf 'USER=%s\n' "$user_value"
printf 'DEVICE=%s\n' "$device_value"
printf 'SYSTEM=%s\n' "$system_value"
printf 'NETWORK=%s (%s)\n' "$network_type" "$network_state"
printf 'LOCAL_IP=%s\n' "$local_ip"
printf 'VPN=%s\n' "$vpn_state"
printf 'BATTERY=%s\n' "$battery_value"
printf 'TIME=%s\n' "$time_value"
printf 'PASS: safe data modules\n'
