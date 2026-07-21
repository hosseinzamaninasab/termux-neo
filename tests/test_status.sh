#!/data/data/com.termux/files/usr/bin/bash
set -e

source src/utils.sh
source src/layout.sh

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

prepare_layout() {
    local terminal_width="$1"

    ui_init
    TERM_WIDTH="$terminal_width"

    ui_calculate_width ||
        fail "width calculation failed"

    ui_calculate_margin ||
        fail "margin calculation failed"
}

add_default_status() {
    ui_add_status "NET" "UP"
    ui_add_status "VPN" "ON"
    ui_add_status "BAT" "82+"
    ui_add_status "TIME" "21:35"
}

# ----------------------------------------------------------
# Empty Status
# ----------------------------------------------------------

prepare_layout 56

ui_calculate_status_layout ||
    fail "empty Status layout failed"

(( UI_STATUS_WIDTH == 44 )) ||
    fail "empty Status width mismatch"

[[ -z "$UI_STATUS_TEXT" ]] ||
    fail "empty Status produced text"

[[ -z "$UI_STATUS_RULE" ]] ||
    fail "empty Status produced a rule"

# ----------------------------------------------------------
# Default 56-column portrait layout
# ----------------------------------------------------------

prepare_layout 56
add_default_status

ui_calculate_status_layout ||
    fail "default Status layout failed"

expected_text="NET:UP · VPN:ON · BAT:82+ · TIME:21:35"
expected_rule="════ ════ ════ ════ ════ ════ ════ ════ ════"

[[ "$UI_STATUS_TEXT" == "$expected_text" ]] ||
    fail "default Status text mismatch"

[[ "$UI_STATUS_RULE" == "$expected_rule" ]] ||
    fail "default Status rule mismatch"

(( UI_STATUS_WIDTH == UI_WIDTH + UI_BORDER_TOTAL_WIDTH )) ||
    fail "Status and Dashboard widths differ"

(( UI_STATUS_WIDTH == 44 )) ||
    fail "default Status width is not 44"

(( ${#UI_STATUS_TEXT} == 38 )) ||
    fail "default Status text width is not 38"

(( ${#UI_STATUS_RULE} == 44 )) ||
    fail "default Status rule width is not 44"

(( UI_STATUS_PADDING_LEFT == 3 )) ||
    fail "default left padding is not 3"

(( UI_STATUS_PADDING_RIGHT == 3 )) ||
    fail "default right padding is not 3"

[[ "$UI_STATUS_RULE" != *" " ]] ||
    fail "Status rule has trailing whitespace"

# ----------------------------------------------------------
# Narrow 34-column layout
# ----------------------------------------------------------

prepare_layout 34
add_default_status

ui_calculate_status_layout ||
    fail "narrow Status layout failed"

expected_narrow="NET:UP · VPN:ON · BAT:82+ · …"

[[ "$UI_STATUS_TEXT" == "$expected_narrow" ]] ||
    fail "narrow overflow policy mismatch"

(( UI_STATUS_WIDTH == 34 )) ||
    fail "narrow Status width mismatch"

(( ${#UI_STATUS_RULE} == 34 )) ||
    fail "narrow Status rule width mismatch"

[[ "$UI_STATUS_RULE" != *" " ]] ||
    fail "narrow Status rule has trailing whitespace"

# ----------------------------------------------------------
# Landscape remains capped and centered
# ----------------------------------------------------------

prepare_layout 94
add_default_status

ui_calculate_status_layout ||
    fail "landscape Status layout failed"

(( UI_STATUS_WIDTH == 44 )) ||
    fail "landscape Status width should remain capped"

(( UI_MARGIN_LEFT == 25 )) ||
    fail "landscape Status margin mismatch"

# ----------------------------------------------------------
# Battery contract
# ----------------------------------------------------------

prepare_layout 56

ui_add_status "BAT" "82"

ui_calculate_status_layout ||
    fail "non-charging battery layout failed"

[[ "$UI_STATUS_TEXT" == "BAT:82" ]] ||
    fail "non-charging battery format mismatch"

[[ "$UI_STATUS_TEXT" != *"%"* ]] ||
    fail "battery unexpectedly contains percent sign"

prepare_layout 56

ui_add_status "BAT" "82+"

ui_calculate_status_layout ||
    fail "charging battery layout failed"

[[ "$UI_STATUS_TEXT" == "BAT:82+" ]] ||
    fail "charging battery format mismatch"

# ----------------------------------------------------------
# Invalid Status content
# ----------------------------------------------------------

prepare_layout 56
ui_add_status "net" "UP"

if ui_calculate_status_layout; then
    fail "lowercase label was accepted"
fi

prepare_layout 56
ui_add_status "NET" $'UP\nDOWN'

if ui_calculate_status_layout; then
    fail "newline was accepted"
fi

prepare_layout 56
ui_add_status "NET" "UP|DOWN"

if ui_calculate_status_layout; then
    fail "delimiter injection was accepted"
fi

prepare_layout 56
ui_add_status "NET" $'\e[31mUP'

if ui_calculate_status_layout; then
    fail "ANSI escape was accepted"
fi

prepare_layout 34
ui_add_status "STATUS" "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"

if ui_calculate_status_layout; then
    fail "oversized first token was accepted"
fi

printf 'PASS: responsive status layout\n'
