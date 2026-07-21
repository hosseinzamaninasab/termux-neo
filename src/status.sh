#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - Status Renderer
# ==========================================================

ui_render_status_rule() {
    ui_render_margin
    printf '%s\n' "$UI_STATUS_RULE"
}

ui_render_status_content() {
    ui_render_margin

    printf '%*s%s%*s\n' \
        "$UI_STATUS_PADDING_LEFT" "" \
        "$UI_STATUS_TEXT" \
        "$UI_STATUS_PADDING_RIGHT" ""
}

ui_render_status() {
    # Empty Status state intentionally produces no output.
    (( ${#UI_STATUS[@]} > 0 )) || return 0

    # Complete all validation and layout work before printing.
    ui_calculate_status_layout || return 1

    ui_render_status_rule
    ui_render_status_content
    ui_render_status_rule
}
