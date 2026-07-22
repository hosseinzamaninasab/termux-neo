#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - Safe Configuration Foundation
# ==========================================================

TERMUX_NEO_CONFIG_DISPLAY_USER=""

termux_neo_config_reset() {
    TERMUX_NEO_CONFIG_DISPLAY_USER=""
}

termux_neo_config_trim() {
    local value="${1-}"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    printf '%s' "$value"
}

termux_neo_config_validate_display_user() {
    local value="${1-}"

    [[ -n "$value" ]] || return 1
    [[ "$value" =~ ^[[:alnum:]_.-]+$ ]] || return 1

    [[ "$value" != *$'\n'* ]] || return 1
    [[ "$value" != *$'\r'* ]] || return 1
    [[ "$value" != *$'\t'* ]] || return 1
    [[ "$value" != *$'\e'* ]] || return 1
    [[ "$value" != *"•"* ]] || return 1
}

termux_neo_config_load() {
    local config_file="${1-}"
    local raw_line=""
    local line=""
    local key=""
    local value=""
    local display_user_seen=0

    termux_neo_config_reset

    [[ -n "$config_file" ]] || return 1
    [[ -e "$config_file" ]] || return 0
    [[ -f "$config_file" ]] || return 1
    [[ -r "$config_file" ]] || return 1

    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        [[ "$raw_line" != *$'\r'* ]] || return 1
        [[ "$raw_line" != *$'\t'* ]] || return 1
        [[ "$raw_line" != *$'\e'* ]] || return 1

        line="$(termux_neo_config_trim "$raw_line")"

        [[ -n "$line" ]] || continue
        [[ "${line:0:1}" != "#" ]] || continue
        [[ "$line" == *"="* ]] || return 1

        key="$(termux_neo_config_trim "${line%%=*}")"
        value="$(termux_neo_config_trim "${line#*=}")"

        case "$key" in
            display_user)
                (( display_user_seen == 0 )) || return 1
                termux_neo_config_validate_display_user "$value" || return 1
                TERMUX_NEO_CONFIG_DISPLAY_USER="$value"
                display_user_seen=1
                ;;
            *)
                return 1
                ;;
        esac
    done < "$config_file"
}
