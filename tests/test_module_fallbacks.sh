#!/data/data/com.termux/files/usr/bin/bash
set -e

source src/modules/common.sh
source src/modules/network.sh
source src/modules/battery.sh

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

sample_ifconfig=$'lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536\n        inet 127.0.0.1  netmask 255.0.0.0\n\nwlan0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500\n        inet 192.168.0.135  netmask 255.255.255.0  broadcast 192.168.0.255'

parsed="$(module_network_parse_ifconfig_ipv4 wlan0 "$sample_ifconfig")" || fail "ifconfig parser rejected sample"
[[ "$parsed" == "192.168.0.135" ]] || fail "ifconfig parser mismatch: $parsed"

module_network_primary_interface() { printf 'wlan0'; }
module_command_exists() { [[ "${1-}" == "ifconfig" ]]; }
ifconfig() { printf '%s\n' "$sample_ifconfig"; }

network_record="$(module_network_local_ip_record)" ||
    fail "network source record rejected ifconfig fixture"
[[ "$network_record" == "ifconfig|192.168.0.135" ]] ||
    fail "network source record mismatch: $network_record"

# Restore the shared command lookup before the battery fixture.
source src/modules/common.sh

fixture="$HOME/.cache/termux-neo/test-power-supply-$$"
rm -rf "$fixture"
mkdir -p "$fixture/battery"
printf 'Battery\n' > "$fixture/battery/type"
printf '78\n' > "$fixture/battery/capacity"
printf 'Charging\n' > "$fixture/battery/status"

record="$(TERMUX_NEO_POWER_SUPPLY_ROOT="$fixture" module_battery_from_sysfs)" || {
    rm -rf "$fixture"
    fail "sysfs battery reader rejected fixture"
}

[[ "$record" == "78|Charging" ]] || {
    rm -rf "$fixture"
    fail "sysfs battery record mismatch: $record"
}

formatted="$(module_battery_format_record "$record")" || {
    rm -rf "$fixture"
    fail "battery formatter rejected fixture"
}

module_battery_from_termux_api() { return 1; }
module_battery_from_dumpsys() { return 1; }

battery_source="$(TERMUX_NEO_POWER_SUPPLY_ROOT="$fixture" module_battery_source)" || {
    rm -rf "$fixture"
    fail "battery source selection rejected sysfs fixture"
}

[[ "$battery_source" == "sysfs" ]] || {
    rm -rf "$fixture"
    fail "battery source mismatch: $battery_source"
}

rm -rf "$fixture"
[[ "$formatted" == "78+" ]] || fail "battery formatter mismatch: $formatted"

printf 'PASS: battery and ifconfig fallbacks\n'
