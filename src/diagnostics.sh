#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - Built-In Diagnostics
# ==========================================================

termux_neo_diagnostic_clean() {
    local value="${1-}"
    local fallback="${2-Unavailable}"

    module_clean_value "$value" "$fallback"
}

termux_neo_diagnostic_command_status() {
    local command_name="${1-}"

    [[ -n "$command_name" ]] || {
        printf 'unavailable'
        return 0
    }

    if module_command_exists "$command_name"; then
        printf 'available'
    else
        printf 'unavailable'
    fi
}

termux_neo_diagnostic_terminal_width() {
    local width=""

    if module_command_exists tput; then
        width="$(tput cols 2>/dev/null || true)"
    fi

    if [[ "$width" =~ ^[0-9]+$ ]] && (( width > 0 )); then
        printf '%s' "$width"
    else
        printf 'Unavailable'
    fi
}

termux_neo_diagnose() {
    local result_status=0
    local version_line=""
    local version="Unavailable"
    local installation_path="Unavailable"
    local config_path="Unavailable"
    local config_status="invalid-path"
    local schema_status="invalid"
    local terminal_width="Unavailable"
    local system_user="User"
    local display_user="User"
    local device="Android Device"
    local system="Android"
    local network_type="Offline"
    local network_state="DOWN"
    local local_ip="Unavailable"
    local network_source="unavailable"
    local vpn_state="OFF"
    local battery="--"
    local battery_source="unavailable"
    local time_value="--:--"
    local optional_ip="unavailable"
    local optional_ifconfig="unavailable"
    local optional_termux_battery="unavailable"
    local optional_dumpsys="unavailable"
    local optional_getprop="unavailable"
    local output=""

    version_line="$(termux_neo_cli_version 2>/dev/null || true)"
    if [[ "$version_line" == "termux-neo "* ]]; then
        version="${version_line#termux-neo }"
    else
        result_status=1
    fi

    installation_path="$(
        termux_neo_diagnostic_clean "${PROJECT_ROOT-}" "Unavailable"
    )"

    if config_path="$(termux_neo_cli_config_path 2>/dev/null)"; then
        if [[ -e "$config_path" ]]; then
            if termux_neo_config_load "$config_path"; then
                config_status="valid"
                schema_status="v${TERMUX_NEO_CONFIG_SCHEMA_VERSION}"
            else
                config_status="invalid"
                schema_status="invalid"
                result_status=1
            fi
        else
            termux_neo_config_load "$config_path" || result_status=1
            config_status="missing (defaults)"
            schema_status="v${TERMUX_NEO_CONFIG_SCHEMA_VERSION} (defaults)"
        fi
    else
        config_path="Unavailable"
        termux_neo_config_reset
        result_status=1
    fi

    terminal_width="$(termux_neo_diagnostic_terminal_width)"

    optional_ip="$(termux_neo_diagnostic_command_status ip)"
    optional_ifconfig="$(termux_neo_diagnostic_command_status ifconfig)"
    optional_termux_battery="$(
        termux_neo_diagnostic_command_status termux-battery-status
    )"
    optional_dumpsys="$(termux_neo_diagnostic_command_status dumpsys)"
    optional_getprop="$(termux_neo_diagnostic_command_status getprop)"

    system_user="$(termux_neo_collect_value module_device_user "User")"
    display_user="$(
        termux_neo_config_resolve_display_user \
            "${TERMUX_NEO_USER-}" \
            "$system_user"
    )"
    device="$(termux_neo_collect_value module_device_name "Android Device")"
    system="$(termux_neo_collect_value module_system_name "Android")"
    network_type="$(termux_neo_collect_value module_network_type "Offline")"
    network_state="$(termux_neo_collect_value module_network_state "DOWN")"
    local_ip="$(termux_neo_collect_value module_network_local_ip "Unavailable")"
    network_source="$(
        termux_neo_collect_value module_network_local_ip_source "unavailable"
    )"
    vpn_state="$(termux_neo_collect_value module_vpn_state "OFF")"
    battery="$(termux_neo_collect_value module_battery_value "--")"
    battery_source="$(
        termux_neo_collect_value module_battery_source "unavailable"
    )"
    time_value="$(termux_neo_collect_value module_time_value "--:--")"

    case "$network_state" in
        UP|DOWN) ;;
        *) network_state="DOWN" ;;
    esac

    case "$network_source" in
        ip|ifconfig|getprop|unavailable) ;;
        *) network_source="unavailable" ;;
    esac

    case "$vpn_state" in
        ON|OFF) ;;
        *) vpn_state="OFF" ;;
    esac

    case "$battery_source" in
        termux-battery-status|sysfs|dumpsys|unavailable) ;;
        *) battery_source="unavailable" ;;
    esac

    if [[ "$battery" != "--" && ! "$battery" =~ ^[0-9]{1,3}\+?$ ]]; then
        battery="--"
    fi

    if [[ "$time_value" != "--:--" &&
          ! "$time_value" =~ ^[0-9]{2}:[0-9]{2}$ ]]
    then
        time_value="--:--"
    fi

    output="$(
        printf '%s\n' \
            'TERMUX NEO DIAGNOSTICS' \
            "VERSION: $version" \
            "INSTALLATION_PATH: $installation_path" \
            "CONFIG_PATH: $config_path" \
            "CONFIG_STATUS: $config_status" \
            "SCHEMA_STATUS: $schema_status" \
            "TERMINAL_WIDTH: $terminal_width" \
            "THEME: $TERMUX_NEO_CONFIG_THEME" \
            "COLOR_MODE: $TERMUX_NEO_CONFIG_COLOR_MODE" \
            "OPTIONAL_COMMAND ip: $optional_ip" \
            "OPTIONAL_COMMAND ifconfig: $optional_ifconfig" \
            "OPTIONAL_COMMAND termux-battery-status: $optional_termux_battery" \
            "OPTIONAL_COMMAND dumpsys: $optional_dumpsys" \
            "OPTIONAL_COMMAND getprop: $optional_getprop" \
            "NETWORK_SOURCE: $network_source" \
            "BATTERY_SOURCE: $battery_source" \
            "DISPLAY_USER: $display_user" \
            "SYSTEM_USER: $system_user" \
            "DEVICE: $device" \
            "SYSTEM: $system" \
            "NETWORK_TYPE: $network_type" \
            "NETWORK_STATE: $network_state" \
            "LOCAL_IP: $local_ip" \
            "VPN_STATE: $vpn_state" \
            "BATTERY: $battery" \
            "TIME: $time_value"
    )" || return 1

    printf '%s\n' "$output"
    return "$result_status"
}
