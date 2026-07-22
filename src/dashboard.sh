#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - Dashboard Renderer
# ==========================================================


# ----------------------------------------------------------


# ----------------------------------------------------------
# Render Dashboard
# ----------------------------------------------------------

ui_render_top() {
    local line

    line="╔$(printf '═%.0s' $(seq 1 "$UI_WIDTH"))╗"

    ui_render_margin
    ui_render_styled border "$line"
    printf '\n'
}


ui_render_title() {
    local title_width
    local total_padding
    local left_padding
    local right_padding

    title_width="${#UI_TITLE}"
    total_padding=$((UI_WIDTH - title_width))

    left_padding=$((total_padding / 2))
    right_padding=$((total_padding - left_padding))

    ui_render_margin

    ui_render_styled border "║"
    printf '%*s' "$left_padding" ""
    ui_render_styled title "$UI_TITLE"
    printf '%*s' "$right_padding" ""
    ui_render_styled border "║"
    printf '\n'
}


ui_render_separator() {
    local line

    line="║$(printf '─%.0s' $(seq 1 "$UI_WIDTH"))║"

    ui_render_margin
    ui_render_styled border "$line"
    printf '\n'
}


ui_render_rows() {
    local row
    local key
    local value
    local display_value

    for row in "${UI_ROWS[@]}"
    do
        IFS="|" read -r key value <<< "$row"

        display_value=$(ui_ellipsize_value "$value") ||
            return 1

        ui_render_margin

        ui_render_styled border "║"
        printf '%*s' "$UI_PADDING_LEFT" ""
        ui_render_styled label "$key"
        printf '%*s' "$((UI_KEY_WIDTH - ${#key}))" ""
        printf '%s' "$UI_FIELD_GAP"
        ui_render_styled value "$display_value"
        printf '%*s' "$((UI_VALUE_WIDTH - ${#display_value}))" ""
        ui_render_styled border "║"
        printf '\n'
    done
}


ui_render_bottom() {
    local line

    line="╚$(printf '═%.0s' $(seq 1 "$UI_WIDTH"))╝"

    ui_render_margin
    ui_render_styled border "$line"
    printf '\n'
}


ui_render() {
    ui_validate_layout || return 1
    ui_validate_content || return 1

    ui_render_top
    ui_render_title
    ui_render_separator
    ui_render_rows
    ui_render_bottom
}
