#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - UI Engine
# ==========================================================

declare -a UI_ROWS
declare -a UI_STATUS

UI_TITLE=""
TERM_WIDTH=0
UI_WIDTH=0
UI_MARGIN_LEFT=0

UI_DEFAULT_WIDTH=42
UI_MIN_WIDTH=32
UI_BORDER_TOTAL_WIDTH=2

UI_PADDING_LEFT=2
UI_KEY_WIDTH=9
UI_FIELD_GAP=" "
UI_VALUE_WIDTH=0

UI_ELLIPSIS="…"

# ----------------------------------------------------------
# Shared Inline Configuration
# ----------------------------------------------------------

UI_INLINE_SEPARATOR=" • "

# ----------------------------------------------------------
# Status Configuration
# ----------------------------------------------------------

UI_STATUS_FIELD_SEPARATOR=":"
UI_STATUS_ITEM_SEPARATOR="$UI_INLINE_SEPARATOR"

UI_STATUS_RULE_CHAR="═"
UI_STATUS_RULE_SEGMENT_WIDTH=4
UI_STATUS_RULE_GAP=" "

# ----------------------------------------------------------
# Status Layout State
# ----------------------------------------------------------

UI_STATUS_WIDTH=0
UI_STATUS_TEXT=""
UI_STATUS_RULE=""

UI_STATUS_PADDING_LEFT=0
UI_STATUS_PADDING_RIGHT=0

# ----------------------------------------------------------
# Prompt Configuration
# ----------------------------------------------------------

UI_PROMPT_TOP_LEFT="╭"
UI_PROMPT_BOTTOM_LEFT="╰"
UI_PROMPT_HORIZONTAL="─"
UI_PROMPT_SYMBOL="❯"
UI_PROMPT_ITEM_SEPARATOR="$UI_INLINE_SEPARATOR"

# ----------------------------------------------------------
# Prompt State
# ----------------------------------------------------------

UI_PROMPT_USER=""
UI_PROMPT_PATH=""

UI_PROMPT_WIDTH=0
UI_PROMPT_LINE_TOP=""
UI_PROMPT_LINE_BOTTOM=""

# ----------------------------------------------------------
# UI State
# ----------------------------------------------------------

ui_init() {
    UI_ROWS=()
    UI_STATUS=()

    UI_TITLE=""

    UI_WIDTH=0
    UI_VALUE_WIDTH=0
    UI_MARGIN_LEFT=0

    UI_STATUS_WIDTH=0
    UI_STATUS_TEXT=""
    UI_STATUS_RULE=""

    UI_STATUS_PADDING_LEFT=0
    UI_STATUS_PADDING_RIGHT=0

    UI_PROMPT_USER=""
    UI_PROMPT_PATH=""

    UI_PROMPT_WIDTH=0
    UI_PROMPT_LINE_TOP=""
    UI_PROMPT_LINE_BOTTOM=""

    TERM_WIDTH=$(tput cols 2>/dev/null || printf '0')
}

ui_title() {
    UI_TITLE="$1"
}

ui_add_row() {
    UI_ROWS+=("$1|$2")
}

ui_add_status() {
    local label="${1-}"
    local value="${2-}"

    UI_STATUS+=("${label}|${value}")
}

ui_set_prompt() {
    UI_PROMPT_USER="${1-}"
    UI_PROMPT_PATH="${2-}"
}

# ----------------------------------------------------------
# Dashboard Characters
# ----------------------------------------------------------

UI_BORDER_HORIZONTAL="═"
UI_BORDER_VERTICAL="║"

UI_BORDER_TOP_LEFT="╔"
UI_BORDER_TOP_RIGHT="╗"

UI_BORDER_BOTTOM_LEFT="╚"
UI_BORDER_BOTTOM_RIGHT="╝"

UI_SEPARATOR="─"
