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

module_network_class_root() {
    local root="${TERMUX_NEO_NET_CLASS_ROOT:-/sys/class/net}"

    [[ -n "$root" ]] || return 1
    [[ "$root" != *$'\n'* ]] || return 1
    [[ "$root" != *$'\r'* ]] || return 1
    [[ "$root" != *$'\t'* ]] || return 1
    [[ "$root" != *$'\e'* ]] || return 1

    printf '%s' "$root"
}

module_interface_names() {
    local root=""
    local path
    local name

    root="$(module_network_class_root)" || return 1

    for path in "$root"/*
    do
        [[ -e "$path" ]] || continue
        name="${path##*/}"
        [[ "$name" != "lo" ]] || continue
        printf '%s\n' "$name"
    done
}
