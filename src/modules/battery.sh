#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - Battery Data Module
# ==========================================================

MODULE_BATTERY_SELECTED_CACHE_READY=0
MODULE_BATTERY_SELECTED_CACHE=""

module_battery_from_termux_api() {
    local raw="" percentage="" status=""
    module_command_exists termux-battery-status || return 1

    raw="$(
        module_run_bounded_ipc_probe termux-battery-status \
            2>/dev/null || true
    )"
    [[ -n "$raw" ]] || return 1

    percentage="$(printf '%s\n' "$raw" | sed -n 's/.*"percentage"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -n 1)"
    status="$(printf '%s\n' "$raw" | sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"

    [[ "$percentage" =~ ^[0-9]{1,3}$ ]] || return 1
    (( percentage >= 0 && percentage <= 100 )) || return 1
    printf '%s|%s' "$percentage" "$status"
}

module_battery_charger_online() {
    local root="${TERMUX_NEO_POWER_SUPPLY_ROOT:-/sys/class/power_supply}"
    local supply type online

    module_data_root_is_safe "$root" || return 1

    for supply in "$root"/*
    do
        [[ -d "$supply" && -r "$supply/online" ]] || continue
        type="$(cat "$supply/type" 2>/dev/null || true)"
        [[ "${type,,}" != "battery" ]] || continue
        online="$(cat "$supply/online" 2>/dev/null || true)"
        [[ "$online" == "1" ]] && return 0
    done

    return 1
}

module_battery_from_sysfs() {
    local root="${TERMUX_NEO_POWER_SUPPLY_ROOT:-/sys/class/power_supply}"
    local supply="" type="" percentage="" status=""

    module_data_root_is_safe "$root" || return 1

    if [[ -d "$root/battery" ]]; then
        supply="$root/battery"
    else
        for supply in "$root"/*
        do
            [[ -d "$supply" && -r "$supply/type" ]] || continue
            type="$(cat "$supply/type" 2>/dev/null || true)"
            if [[ "${type,,}" == "battery" ]]; then
                break
            fi
            supply=""
        done
    fi

    [[ -n "$supply" && -r "$supply/capacity" ]] || return 1

    percentage="$(cat "$supply/capacity" 2>/dev/null || true)"
    percentage="${percentage//[!0-9]/}"
    [[ "$percentage" =~ ^[0-9]{1,3}$ ]] || return 1
    (( percentage >= 0 && percentage <= 100 )) || return 1

    if [[ -r "$supply/status" ]]; then
        status="$(cat "$supply/status" 2>/dev/null || true)"
    fi

    status="$(module_clean_value "$status" "")"
    if [[ -z "$status" ]] && module_battery_charger_online; then
        status="Charging"
    fi

    printf '%s|%s' "$percentage" "$status"
}

module_battery_from_dumpsys() {
    local raw="" percentage="" status_code="" powered="" status=""
    module_command_exists dumpsys || return 1

    raw="$(
        module_run_bounded_ipc_probe dumpsys battery \
            2>/dev/null || true
    )"
    [[ -n "$raw" ]] || return 1

    percentage="$(printf '%s\n' "$raw" | sed -n 's/^[[:space:]]*level:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -n 1)"
    status_code="$(printf '%s\n' "$raw" | sed -n 's/^[[:space:]]*status:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -n 1)"
    powered="$(printf '%s\n' "$raw" | sed -n 's/^[[:space:]]*\(AC powered\|USB powered\|Wireless powered\):[[:space:]]*\(true\|false\).*/\2/p' | grep -m 1 '^true$' || true)"

    [[ "$percentage" =~ ^[0-9]{1,3}$ ]] || return 1
    (( percentage >= 0 && percentage <= 100 )) || return 1

    case "$status_code" in
        2|5) status="CHARGING" ;;
        *) [[ "$powered" == "true" ]] && status="CHARGING" || status="DISCHARGING" ;;
    esac

    printf '%s|%s' "$percentage" "$status"
}

module_battery_format_record() {
    local record="${1-}" percentage="" status="" suffix=""
    [[ "$record" == *"|"* ]] || return 1

    percentage="${record%%|*}"
    status="${record#*|}"

    [[ "$percentage" =~ ^[0-9]{1,3}$ ]] || return 1
    (( percentage >= 0 && percentage <= 100 )) || return 1

    case "${status,,}" in
        charging|full) suffix="+" ;;
    esac

    printf '%s%s' "$percentage" "$suffix"
}

module_battery_selected_record_uncached() {
    local record=""

    record="$(module_battery_from_termux_api 2>/dev/null || true)"
    if [[ -n "$record" ]]; then
        printf 'termux-battery-status|%s' "$record"
        return 0
    fi

    record="$(module_battery_from_sysfs 2>/dev/null || true)"
    if [[ -n "$record" ]]; then
        printf 'sysfs|%s' "$record"
        return 0
    fi

    record="$(module_battery_from_dumpsys 2>/dev/null || true)"
    if [[ -n "$record" ]]; then
        printf 'dumpsys|%s' "$record"
        return 0
    fi

    printf 'unavailable|'
}

module_battery_selected_record() {
    if (( MODULE_BATTERY_SELECTED_CACHE_READY == 1 )); then
        printf '%s' "$MODULE_BATTERY_SELECTED_CACHE"
        return 0
    fi

    module_battery_selected_record_uncached
}

module_battery_prepare_render_cache() {
    local selected=""

    selected="$(
        module_battery_selected_record_uncached 2>/dev/null || true
    )"
    [[ "$selected" == *"|"* ]] || selected="unavailable|"

    MODULE_BATTERY_SELECTED_CACHE="$selected"
    MODULE_BATTERY_SELECTED_CACHE_READY=1
}

module_battery_clear_render_cache() {
    MODULE_BATTERY_SELECTED_CACHE=""
    MODULE_BATTERY_SELECTED_CACHE_READY=0
}

module_battery_source() {
    local selected=""
    local source=""

    selected="$(module_battery_selected_record 2>/dev/null || true)"
    [[ "$selected" == *"|"* ]] || {
        printf 'unavailable'
        return 0
    }

    source="${selected%%|*}"
    case "$source" in
        termux-battery-status|sysfs|dumpsys|unavailable)
            printf '%s' "$source"
            ;;
        *)
            printf 'unavailable'
            ;;
    esac
}

module_battery_value() {
    local selected="" record="" value=""

    selected="$(module_battery_selected_record 2>/dev/null || true)"
    if [[ "$selected" == *"|"* ]]; then
        record="${selected#*|}"
    fi

    if [[ -n "$record" ]]; then
        value="$(module_battery_format_record "$record" 2>/dev/null || true)"
    fi

    [[ -n "$value" ]] && printf '%s' "$value" || printf '%s' '--'
}
