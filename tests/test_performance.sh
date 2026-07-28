#!/data/data/com.termux/files/usr/bin/bash

set -e

CACHE_DIR="$HOME/.cache/termux-neo"
fixture="$CACHE_DIR/test-performance-$$"
network_log="$fixture/network.log"
battery_log="$fixture/battery.log"
timeout_log="$fixture/timeout.log"
missing_command_log="$fixture/missing-command.log"
missing_power_supply_root="$fixture/missing-power-supply"
self_test_stdout="$fixture/self-test.stdout"
self_test_stderr="$fixture/self-test.stderr"

mkdir -p "$fixture/tmp" "$missing_power_supply_root"
trap 'rm -rf "$fixture"' EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

bash -n scripts/performance-check.sh tests/test_performance.sh ||
    fail "performance scripts failed syntax validation"

TMPDIR="$fixture/tmp" \
    bash scripts/performance-check.sh --self-test \
        > "$self_test_stdout" 2> "$self_test_stderr" ||
    fail "portable performance self-test failed"
[[ ! -s "$self_test_stderr" ]] ||
    fail "portable performance self-test produced stderr"
grep -Fqx \
    'PASS: deterministic repeated-render stability, jobs, children, and file descriptors' \
    "$self_test_stdout" ||
    fail "portable performance self-test result is missing"

set +e
TMPDIR="$fixture/tmp" \
    bash scripts/performance-check.sh --unknown \
        > "$fixture/invalid.stdout" 2> "$fixture/invalid.stderr"
invalid_status=$?
set -e
[[ "$invalid_status" == "2" ]] ||
    fail "invalid performance option did not return status 2"
[[ ! -s "$fixture/invalid.stdout" ]] ||
    fail "invalid performance option produced stdout"
grep -Fq 'usage: bash scripts/performance-check.sh' \
    "$fixture/invalid.stderr" ||
    fail "invalid performance usage message is missing"

source src/modules/common.sh
source src/modules/network.sh
source src/modules/battery.sh

module_network_primary_interface_uncached() {
    printf 'probe\n' >> "$network_log"
    printf 'wlan0'
}

module_network_prepare_render_cache
for expected_interface in wlan0 wlan0 wlan0; do
    actual_interface="$(module_network_primary_interface)" ||
        fail "prepared network cache became unavailable"
    [[ "$actual_interface" == "$expected_interface" ]] ||
        fail "prepared network cache changed value"
done
[[ "$(wc -l < "$network_log")" == "1" ]] ||
    fail "network interface was probed more than once in one cycle"

module_network_clear_render_cache
[[ "$(module_network_primary_interface)" == "wlan0" ]] ||
    fail "network interface did not refresh after cache clear"
[[ "$(wc -l < "$network_log")" == "2" ]] ||
    fail "network cache persisted across cycles"

module_battery_selected_record_uncached() {
    printf 'probe\n' >> "$battery_log"
    printf 'sysfs|82|Charging'
}

module_battery_prepare_render_cache
[[ "$(module_battery_value)" == "82+" ]] ||
    fail "prepared battery cache produced the wrong value"
[[ "$(module_battery_source)" == "sysfs" ]] ||
    fail "prepared battery cache produced the wrong source"
[[ "$(wc -l < "$battery_log")" == "1" ]] ||
    fail "battery source was probed more than once in one cycle"

module_battery_clear_render_cache
[[ "$(module_battery_value)" == "82+" ]] ||
    fail "battery source did not refresh after cache clear"
[[ "$(wc -l < "$battery_log")" == "2" ]] ||
    fail "battery cache persisted across cycles"

source src/modules/battery.sh

module_command_exists() {
    case "${1-}" in
        timeout|termux-battery-status|dumpsys) return 0 ;;
        *) return 1 ;;
    esac
}

timeout() {
    printf '%s\n' "$*" >> "$timeout_log"
    return 124
}

termux-battery-status() {
    fail "bounded Termux:API command escaped the timeout wrapper"
}

dumpsys() {
    fail "bounded dumpsys command escaped the timeout wrapper"
}

if module_battery_from_termux_api; then
    fail "timed-out Termux:API probe was accepted"
fi
if module_battery_from_dumpsys; then
    fail "timed-out dumpsys probe was accepted"
fi

[[ "$(wc -l < "$timeout_log")" == "2" ]] ||
    fail "both IPC probes did not cross the timeout boundary"
grep -Fq \
    -- \
    '--signal=TERM --kill-after=1s 2s termux-battery-status' \
    "$timeout_log" ||
    fail "Termux:API timeout contract is incomplete"
grep -Fq \
    -- \
    '--signal=TERM --kill-after=1s 2s dumpsys battery' \
    "$timeout_log" ||
    fail "dumpsys timeout contract is incomplete"

module_command_exists() {
    return 1
}
termux-battery-status() {
    printf 'termux-battery-status\n' >> "$missing_command_log"
}
dumpsys() {
    printf 'dumpsys\n' >> "$missing_command_log"
}

TERMUX_NEO_POWER_SUPPLY_ROOT="$missing_power_supply_root"
export TERMUX_NEO_POWER_SUPPLY_ROOT

for _ in 1 2 3 4 5; do
    [[ "$(module_battery_selected_record_uncached)" == "unavailable|" ]] ||
        fail "missing battery sources did not use the immediate fallback"
done
[[ ! -e "$missing_command_log" ]] ||
    fail "a missing optional command was invoked"

grep -Fq 'No fixed millisecond target was chosen' \
    docs/performance-baseline.md ||
    fail "measurement-derived budget statement is missing"
grep -Fq 'Task 27 median <= Task 26 p95: PASS' \
    docs/performance-baseline.md ||
    fail "reference median gate is missing"
grep -Fq 'Task 27 p95 <= measured budget: PASS' \
    docs/performance-baseline.md ||
    fail "reference p95 gate is missing"
grep -Fq 'Persistent child processes after render: 0' \
    docs/performance-baseline.md ||
    fail "reference child-process result is missing"
grep -Fq 'Background jobs after render: 0' \
    docs/performance-baseline.md ||
    fail "reference job result is missing"

if grep -En \
    '(^|[[:space:]])(nohup|coproc)([[:space:]]|$)|while[[:space:]]+true' \
    src/main.sh src/diagnostics.sh src/modules/*.sh
then
    fail "runtime contains a persistent-work construct"
fi

printf 'PASS: measured performance and repeated-execution stability\n'
