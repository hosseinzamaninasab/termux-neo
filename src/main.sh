#!/data/data/com.termux/files/usr/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# UI state, layout, and independent renderers.
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/layout.sh"
source "$SCRIPT_DIR/render.sh"
source "$SCRIPT_DIR/dashboard.sh"
source "$SCRIPT_DIR/status.sh"
source "$SCRIPT_DIR/prompt.sh"

# Safe production data modules.
source "$SCRIPT_DIR/modules/common.sh"
source "$SCRIPT_DIR/modules/device.sh"
source "$SCRIPT_DIR/modules/network.sh"
source "$SCRIPT_DIR/modules/vpn.sh"
source "$SCRIPT_DIR/modules/battery.sh"
source "$SCRIPT_DIR/modules/datetime.sh"

termux_neo_collect_value() {
    local function_name="${1-}"
    local fallback="${2-Unavailable}"
    local value=""

    if [[ -n "$function_name" ]] &&
       declare -F "$function_name" >/dev/null 2>&1
    then
        value="$("$function_name" 2>/dev/null || true)"
    fi

    module_clean_value "$value" "$fallback"
}

termux_neo_prompt_user() {
    local value=""

    value="$(termux_neo_collect_value module_device_user "User")"

    if [[ "$value" =~ ^[[:alnum:]_.-]+$ ]]; then
        printf '%s' "$value"
    else
        printf 'User'
    fi
}

termux_neo_prompt_path() {
    local path="${PWD:-}"
    local home_path="${HOME:-}"

    [[ -n "$path" ]] || path="$home_path"
    [[ -n "$path" ]] || path="~"

    if [[ -n "$home_path" && "$path" == "$home_path" ]]; then
        path="~"
    elif [[ -n "$home_path" && "$path" == "$home_path/"* ]]; then
        path="~${path#"$home_path"}"
    fi

    path="${path//$'\n'/}"
    path="${path//$'\r'/}"
    path="${path//$'\t'/}"
    path="${path//$'\e'/}"

    if [[ -z "$path" || "$path" == *"•"* ]]; then
        path="~"
    fi

    printf '%s' "$path"
}

termux_neo_prepare_state() {
    local dashboard_user=""
    local prompt_user=""
    local device=""
    local system=""
    local network_type=""
    local local_ip=""
    local network_state=""
    local vpn_state=""
    local battery=""
    local time_value=""
    local prompt_path=""

    ui_init

    dashboard_user="$(
        termux_neo_collect_value module_device_user "User"
    )"
    prompt_user="$(termux_neo_prompt_user)"
    device="$(
        termux_neo_collect_value module_device_name "Android Device"
    )"
    system="$(
        termux_neo_collect_value module_system_name "Android"
    )"
    network_type="$(
        termux_neo_collect_value module_network_type "Offline"
    )"
    local_ip="$(
        termux_neo_collect_value module_network_local_ip "Unavailable"
    )"
    network_state="$(
        termux_neo_collect_value module_network_state "DOWN"
    )"
    vpn_state="$(
        termux_neo_collect_value module_vpn_state "OFF"
    )"
    battery="$(
        termux_neo_collect_value module_battery_value "--"
    )"
    time_value="$(
        termux_neo_collect_value module_time_value "--:--"
    )"
    prompt_path="$(termux_neo_prompt_path)"

    case "$network_state" in
        UP|DOWN) ;;
        *) network_state="DOWN" ;;
    esac

    case "$vpn_state" in
        ON|OFF) ;;
        *) vpn_state="OFF" ;;
    esac

    if [[ "$battery" != "--" &&
          ! "$battery" =~ ^[0-9]{1,3}\+?$ ]]
    then
        battery="--"
    fi

    if [[ "$time_value" != "--:--" &&
          ! "$time_value" =~ ^[0-9]{2}:[0-9]{2}$ ]]
    then
        time_value="--:--"
    fi

    ui_title "TERMUX NEO"

    ui_add_row "USER" "$dashboard_user"
    ui_add_row "DEVICE" "$device"
    ui_add_row "SYSTEM" "$system"
    ui_add_row "NETWORK" "$network_type"
    ui_add_row "LOCAL IP" "$local_ip"

    ui_add_status "NET" "$network_state"
    ui_add_status "VPN" "$vpn_state"
    ui_add_status "BAT" "$battery"
    ui_add_status "TIME" "$time_value"

    ui_set_prompt "$prompt_user" "$prompt_path"
}

termux_neo_render_once() {
    local output=""

    termux_neo_prepare_state || return 1

    # Dashboard layout must be established before Dashboard and Status.
    ui_calculate_width || return 1
    ui_calculate_margin || return 1

    # Render all blocks in a subshell first. Nothing reaches the terminal
    # unless Dashboard, Status, and Prompt all finish successfully.
    output="$(
        ui_render || exit 1
        printf '\n'

        ui_render_status || exit 1
        printf '\n'

        ui_render_prompt || exit 1
    )" || return 1

    printf '%s\n' "$output"
}

# Sourcing main.sh defines the production API without terminal output.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    termux_neo_render_once
fi
