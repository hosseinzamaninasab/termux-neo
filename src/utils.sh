#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - UI Engine
# ==========================================================

# Dashboard rows
declare -a UI_ROWS

# Status bar items
declare -a UI_STATUS

# Dashboard title
UI_TITLE=""
UI_WIDTH=0
TERM_WIDTH=0


# ------------------------------------------------------
# Layout Metrics
# ------------------------------------------------------


UI_PADDING_LEFT=2
UI_KEY_WIDTH=9
UI_FIELD_GAP=" "
UI_VALUE_WIDTH=30


# ----------------------------------------------------------
# Initialize UI Engine
# ----------------------------------------------------------

ui_init() {
    UI_ROWS=()
    UI_STATUS=()
    UI_TITLE=""

    TERM_WIDTH=$(tput cols)
    UI_WIDTH=42
}

# ----------------------------------------------------------
# Set Dashboard Title
# ----------------------------------------------------------

ui_title() {
    UI_TITLE="$1"
}

# ----------------------------------------------------------
# Add Dashboard Row
# ----------------------------------------------------------

ui_add_row() {
    UI_ROWS+=("$1|$2")
}

# ----------------------------------------------------------
# Add Status Item
# ----------------------------------------------------------

ui_add_status() {
    UI_STATUS+=("$1")
}


# ----------------------------------------------------------
# UI Borders
# ----------------------------------------------------------

UI_BORDER_HORIZONTAL="═"
UI_BORDER_VERTICAL="║"

UI_BORDER_TOP_LEFT="╔"
UI_BORDER_TOP_RIGHT="╗"

UI_BORDER_BOTTOM_LEFT="╚"
UI_BORDER_BOTTOM_RIGHT="╝"

UI_SEPARATOR="─"
