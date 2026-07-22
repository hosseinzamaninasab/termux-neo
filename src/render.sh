#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - Shared Rendering Primitives
# ==========================================================

# ----------------------------------------------------------
# Render Left Margin
# ----------------------------------------------------------

ui_render_margin() {
    printf "%*s" "$UI_MARGIN_LEFT" ""
}

ui_render_styled() {
    local role="${1-}"
    local value="${2-}"

    if declare -F termux_neo_color_print >/dev/null 2>&1; then
        termux_neo_color_print "$role" "$value"
    else
        printf '%s' "$value"
    fi
}
