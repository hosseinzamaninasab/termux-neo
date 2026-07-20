#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - Dashboard Renderer
# ==========================================================


# ----------------------------------------------------------
# Render Left Margin
# ----------------------------------------------------------

ui_render_margin() {
    printf "%*s" "$UI_MARGIN_LEFT" ""
}


# ----------------------------------------------------------
# Render Dashboard
# ----------------------------------------------------------

ui_render_top() {
    ui_render_margin
    echo "╔$(printf '═%.0s' $(seq 1 "$UI_WIDTH"))╗"
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

    printf "║%*s%s%*s║\n" \
        "$left_padding" "" \
        "$UI_TITLE" \
        "$right_padding" ""
}


ui_render_separator() {
    ui_render_margin
    echo "║$(printf '─%.0s' $(seq 1 "$UI_WIDTH"))║"
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

        printf "║%*s%-*s%s%-*s║\n" \
            "$UI_PADDING_LEFT" "" \
            "$UI_KEY_WIDTH" "$key" \
            "$UI_FIELD_GAP" \
            "$UI_VALUE_WIDTH" "$display_value"
    done
}


ui_render_bottom() {
    ui_render_margin
    echo "╚$(printf '═%.0s' $(seq 1 "$UI_WIDTH"))╝"
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
