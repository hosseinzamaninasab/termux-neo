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
    local control_character=""

    value="${value//$'\n'/ }"
    value="${value//$'\r'/ }"
    value="${value//$'\t'/ }"

    while [[ "$value" =~ [[:cntrl:]] ]]; do
        control_character="${BASH_REMATCH[0]}"
        value="${value//"$control_character"/}"
    done

    value="${value//|/}"
    value="${value//•/}"

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

module_data_root_is_safe() {
    local root="${1-}"

    [[ "$root" == /* ]] || return 1
    [[ "$root" != "/" ]] || return 1
    [[ "$root" != *"//"* ]] || return 1
    [[ "$root" != *"/./"* && "$root" != */. ]] || return 1
    [[ "$root" != *"/../"* && "$root" != */.. ]] || return 1
    [[ ! "$root" =~ [[:cntrl:]] ]] || return 1
    [[ -d "$root" && ! -L "$root" ]]
}

module_interface_name_is_safe() {
    local interface="${1-}"

    [[ -n "$interface" ]] || return 1
    (( ${#interface} <= 64 )) || return 1
    [[ "$interface" != -* ]] || return 1
    [[ "$interface" =~ ^[[:alnum:]_.:-]+$ ]]
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

    module_data_root_is_safe "$root" || return 1

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
        module_interface_name_is_safe "$name" || continue
        printf '%s\n' "$name"
    done
}
