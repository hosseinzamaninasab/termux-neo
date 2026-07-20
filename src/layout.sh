#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - Layout Engine
# ==========================================================

# ----------------------------------------------------------
# Validate Layout Metrics
# ----------------------------------------------------------

ui_validate_layout() {
    local field_gap_width
    local row_width

    field_gap_width="${#UI_FIELD_GAP}"

    (( UI_WIDTH > 0 )) || return 1
    (( UI_PADDING_LEFT >= 0 )) || return 1
    (( UI_KEY_WIDTH > 0 )) || return 1
    (( field_gap_width > 0 )) || return 1
    (( UI_VALUE_WIDTH > 0 )) || return 1

    row_width=$((
        UI_PADDING_LEFT
        + UI_KEY_WIDTH
        + field_gap_width
        + UI_VALUE_WIDTH
    ))

    (( row_width == UI_WIDTH ))
}

# ----------------------------------------------------------
# Calculate Dashboard Width
# ----------------------------------------------------------

ui_calculate_width() {
    local available_width
    local field_gap_width

    # Prevent stale layout values after a failed calculation.
    UI_WIDTH=0
    UI_VALUE_WIDTH=0

    (( TERM_WIDTH > 0 )) || return 1
    (( UI_BORDER_TOTAL_WIDTH > 0 )) || return 1
    (( UI_MIN_WIDTH > 0 )) || return 1
    (( UI_DEFAULT_WIDTH >= UI_MIN_WIDTH )) || return 1

    available_width=$((TERM_WIDTH - UI_BORDER_TOTAL_WIDTH))

    (( available_width >= UI_MIN_WIDTH )) || return 1

    if (( available_width < UI_DEFAULT_WIDTH )); then
        UI_WIDTH="$available_width"
    else
        UI_WIDTH="$UI_DEFAULT_WIDTH"
    fi

    field_gap_width="${#UI_FIELD_GAP}"

    UI_VALUE_WIDTH=$((
        UI_WIDTH
        - UI_PADDING_LEFT
        - UI_KEY_WIDTH
        - field_gap_width
    ))

    ui_validate_layout
}
