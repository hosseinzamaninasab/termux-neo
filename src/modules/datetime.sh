#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - Date and Time Data Module
# ==========================================================

module_time_value() {
    local value=""

    if module_command_exists date; then
        value="$(date '+%H:%M' 2>/dev/null || true)"
    fi

    if [[ "$value" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
        printf '%s' "$value"
    else
        printf '%s' '--:--'
    fi
}
