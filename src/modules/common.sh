#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - Module Safety Helpers
# ==========================================================

module_command_exists() {
    command -v "$1" >/dev/null 2>&1
}

module_clean_value() {
    local value="${1-}"
    local fallback="${2-Unavailable}"

    value="${value//$'\n'/ }"
    value="${value//$'\r'/ }"
    value="${value//$'\t'/ }"
    value="${value//$'\e'/}"
    value="${value//|/}"

    while [[ "$value" == " "* ]]; do
        value="${value# }"
    done

    while [[ "$value" == *" " ]]; do
        value="${value% }"
    done

    while [[ "$value" == *"  "* ]]; do
        value="${value//  / }"
    done

    [[ -n "$value" ]] || value="$fallback"

    printf '%s' "$value"
}

module_read_getprop() {
    local property="${1-}"
    local value=""

    [[ -n "$property" ]] || return 1

    if module_command_exists getprop; then
        value="$(getprop "$property" 2>/dev/null || true)"
    fi

    value="$(module_clean_value "$value" "")"
    [[ -n "$value" ]] || return 1

    printf '%s' "$value"
}

module_interface_names() {
    local path
    local name

    for path in /sys/class/net/*
    do
        [[ -e "$path" ]] || continue
        name="${path##*/}"
        [[ "$name" != "lo" ]] || continue
        printf '%s\n' "$name"
    done
}
