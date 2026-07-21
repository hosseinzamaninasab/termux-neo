#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - Device Data Module
# ==========================================================

module_device_user() {
    local value="${TERMUX_NEO_USER:-${USER:-}}"

    if [[ -z "$value" ]] && module_command_exists id; then
        value="$(id -un 2>/dev/null || true)"
    fi

    module_clean_value "$value" "User"
}

module_device_name() {
    local manufacturer=""
    local model=""
    local value=""

    manufacturer="$(module_read_getprop ro.product.manufacturer 2>/dev/null || true)"
    model="$(module_read_getprop ro.product.model 2>/dev/null || true)"

    if [[ -n "$manufacturer" && -n "$model" ]]; then
        case "${model,,}" in
            "${manufacturer,,}"*)
                value="$model"
                ;;
            *)
                value="$manufacturer $model"
                ;;
        esac
    elif [[ -n "$model" ]]; then
        value="$model"
    elif [[ -n "$manufacturer" ]]; then
        value="$manufacturer Device"
    else
        value="Android Device"
    fi

    module_clean_value "$value" "Android Device"
}

module_system_name() {
    local release=""
    local value=""

    release="$(module_read_getprop ro.build.version.release 2>/dev/null || true)"

    if [[ -n "$release" ]]; then
        value="Android $release"
    else
        value="Android"
    fi

    module_clean_value "$value" "Android"
}
