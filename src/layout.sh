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
