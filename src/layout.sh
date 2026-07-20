#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - Layout Engine
# ==========================================================

# ----------------------------------------------------------
# Validate Layout
# ----------------------------------------------------------

ui_validate_layout() {
    local field_gap_width
    local row_width
    local dashboard_total_width
    local expected_margin_left

    field_gap_width="${#UI_FIELD_GAP}"

    (( TERM_WIDTH > 0 )) || return 1
    (( UI_WIDTH > 0 )) || return 1
    (( UI_BORDER_TOTAL_WIDTH > 0 )) || return 1

    (( UI_PADDING_LEFT >= 0 )) || return 1
    (( UI_KEY_WIDTH > 0 )) || return 1
    (( field_gap_width > 0 )) || return 1
    (( UI_VALUE_WIDTH > 0 )) || return 1
    (( UI_MARGIN_LEFT >= 0 )) || return 1

    row_width=$((
        UI_PADDING_LEFT
        + UI_KEY_WIDTH
        + field_gap_width
        + UI_VALUE_WIDTH
    ))

    (( row_width == UI_WIDTH )) || return 1

    dashboard_total_width=$((
        UI_WIDTH
        + UI_BORDER_TOTAL_WIDTH
    ))

    (( dashboard_total_width <= TERM_WIDTH )) || return 1

    expected_margin_left=$((
        (TERM_WIDTH - dashboard_total_width) / 2
    ))

    (( UI_MARGIN_LEFT == expected_margin_left ))
}


# ----------------------------------------------------------
# Calculate Dashboard Width
# ----------------------------------------------------------

ui_calculate_width() {
    local available_width
    local field_gap_width
    local calculated_ui_width
    local calculated_value_width

    # Prevent stale layout values after a failed calculation.
    UI_WIDTH=0
    UI_VALUE_WIDTH=0
    UI_MARGIN_LEFT=0

    (( TERM_WIDTH > 0 )) || return 1
    (( UI_BORDER_TOTAL_WIDTH > 0 )) || return 1
    (( UI_MIN_WIDTH > 0 )) || return 1
    (( UI_DEFAULT_WIDTH >= UI_MIN_WIDTH )) || return 1
    (( UI_PADDING_LEFT >= 0 )) || return 1
    (( UI_KEY_WIDTH > 0 )) || return 1

    field_gap_width="${#UI_FIELD_GAP}"

    (( field_gap_width > 0 )) || return 1

    available_width=$((TERM_WIDTH - UI_BORDER_TOTAL_WIDTH))

    (( available_width >= UI_MIN_WIDTH )) || return 1

    if (( available_width < UI_DEFAULT_WIDTH )); then
        calculated_ui_width="$available_width"
    else
        calculated_ui_width="$UI_DEFAULT_WIDTH"
    fi

    calculated_value_width=$((
        calculated_ui_width
        - UI_PADDING_LEFT
        - UI_KEY_WIDTH
        - field_gap_width
    ))

    (( calculated_value_width > 0 )) || return 1

    UI_WIDTH="$calculated_ui_width"
    UI_VALUE_WIDTH="$calculated_value_width"
}


# ----------------------------------------------------------
# Calculate Dashboard Margin
# ----------------------------------------------------------

ui_calculate_margin() {
    local dashboard_total_width
    local available_space

    # Prevent a previous margin from surviving a failed calculation.
    UI_MARGIN_LEFT=0

    (( TERM_WIDTH > 0 )) || return 1
    (( UI_WIDTH > 0 )) || return 1
    (( UI_BORDER_TOTAL_WIDTH > 0 )) || return 1

    dashboard_total_width=$((
        UI_WIDTH
        + UI_BORDER_TOTAL_WIDTH
    ))

    (( dashboard_total_width <= TERM_WIDTH )) || return 1

    available_space=$((
        TERM_WIDTH
        - dashboard_total_width
    ))

    UI_MARGIN_LEFT=$((available_space / 2))

    ui_validate_layout
}

# ----------------------------------------------------------
# Format Row Value
# ----------------------------------------------------------

ui_ellipsize_value() {
    local value="$1"
    local ellipsis_width
    local visible_width

    (( UI_VALUE_WIDTH > 0 )) || return 1

    ellipsis_width="${#UI_ELLIPSIS}"

    (( ellipsis_width > 0 )) || return 1
    (( ellipsis_width <= UI_VALUE_WIDTH )) || return 1

    if (( ${#value} <= UI_VALUE_WIDTH )); then
        printf '%s' "$value"
        return 0
    fi

    visible_width=$((UI_VALUE_WIDTH - ellipsis_width))

    printf '%s%s' \
        "${value:0:visible_width}" \
        "$UI_ELLIPSIS"
}


# ----------------------------------------------------------
# Validate Render Content
# ----------------------------------------------------------

ui_validate_content() {
    local row
    local key
    local value
    local ellipsis_width

    ellipsis_width="${#UI_ELLIPSIS}"

    (( ellipsis_width > 0 )) || return 1
    (( ellipsis_width <= UI_VALUE_WIDTH )) || return 1

    (( ${#UI_TITLE} <= UI_WIDTH )) || return 1

    [[ "$UI_TITLE" != *$'\n'* ]] || return 1
    [[ "$UI_TITLE" != *$'\r'* ]] || return 1
    [[ "$UI_TITLE" != *$'\t'* ]] || return 1

    [[ "$UI_ELLIPSIS" != *$'\n'* ]] || return 1
    [[ "$UI_ELLIPSIS" != *$'\r'* ]] || return 1
    [[ "$UI_ELLIPSIS" != *$'\t'* ]] || return 1

    for row in "${UI_ROWS[@]}"
    do
        [[ "$row" != *$'\n'* ]] || return 1
        [[ "$row" != *$'\r'* ]] || return 1
        [[ "$row" != *$'\t'* ]] || return 1

        IFS="|" read -r key value <<< "$row"

        (( ${#key} <= UI_KEY_WIDTH )) || return 1
    done
}
