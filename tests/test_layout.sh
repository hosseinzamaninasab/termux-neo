#!/data/data/com.termux/files/usr/bin/bash

set -e

source src/utils.sh
source src/layout.sh
source src/dashboard.sh


fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}


assert_layout() {
    local term_width="$1"
    local expected_ui_width="$2"
    local expected_value_width="$3"
    local expected_margin_left="$4"

    TERM_WIDTH="$term_width"

    if ! ui_calculate_width; then
        fail "TERM_WIDTH=$term_width was rejected during width calculation"
    fi

    if ! ui_calculate_margin; then
        fail "TERM_WIDTH=$term_width was rejected during margin calculation"
    fi

    if (( UI_WIDTH != expected_ui_width )); then
        fail "TERM_WIDTH=$term_width produced UI_WIDTH=$UI_WIDTH"
    fi

    if (( UI_VALUE_WIDTH != expected_value_width )); then
        fail "TERM_WIDTH=$term_width produced UI_VALUE_WIDTH=$UI_VALUE_WIDTH"
    fi

    if (( UI_MARGIN_LEFT != expected_margin_left )); then
        fail "TERM_WIDTH=$term_width produced UI_MARGIN_LEFT=$UI_MARGIN_LEFT"
    fi

    if ! ui_validate_layout; then
        fail "TERM_WIDTH=$term_width produced an invalid layout"
    fi
}


assert_rejected() {
    local term_width="$1"

    TERM_WIDTH="$term_width"

    if ui_calculate_width; then
        fail "unsupported TERM_WIDTH=$term_width was accepted"
    fi

    if (( UI_WIDTH != 0 )); then
        fail "failed calculation preserved stale UI_WIDTH"
    fi

    if (( UI_VALUE_WIDTH != 0 )); then
        fail "failed calculation preserved stale UI_VALUE_WIDTH"
    fi

    if (( UI_MARGIN_LEFT != 0 )); then
        fail "failed calculation preserved stale UI_MARGIN_LEFT"
    fi

    if ui_calculate_margin; then
        fail "margin was calculated without a valid dashboard width"
    fi
}


ui_init

# Unsupported terminal.
assert_rejected 33

# Small responsive terminals fill the available width.
assert_layout 34 32 20 0
assert_layout 35 33 21 0
assert_layout 40 38 26 0

# Default-width dashboard.
assert_layout 44 42 30 0
assert_layout 45 42 30 0
assert_layout 46 42 30 1

# Reference device widths.
assert_layout 56 42 30 6
assert_layout 94 42 30 25


# Verify rendered lines contain the calculated left margin.
TERM_WIDTH=56

ui_calculate_width ||
    fail "render width calculation failed"

ui_calculate_margin ||
    fail "render margin calculation failed"

ui_title "TERMUX NEO"
ui_add_row "USER" "Zoro"

render_output=$(ui_render) ||
    fail "valid centered layout was not rendered"

expected_margin=$(printf "%*s" "$UI_MARGIN_LEFT" "")
expected_dashboard_width=$((
    UI_WIDTH
    + UI_BORDER_TOTAL_WIDTH
))

line_number=0

while IFS= read -r line
do
    ((line_number += 1))

    actual_margin="${line:0:UI_MARGIN_LEFT}"
    dashboard_line="${line:UI_MARGIN_LEFT}"

    if [[ "$actual_margin" != "$expected_margin" ]]; then
        fail "rendered line $line_number has an invalid left margin"
    fi

    if (( ${#dashboard_line} != expected_dashboard_width )); then
        fail "rendered line $line_number has dashboard width ${#dashboard_line}, expected $expected_dashboard_width"
    fi
done <<< "$render_output"


# A wrong margin must fail before producing output.
UI_MARGIN_LEFT=$((UI_MARGIN_LEFT + 1))

if ui_validate_layout; then
    fail "invalid margin was accepted"
fi

render_output=""

if render_output=$(ui_render); then
    fail "invalid centered layout was rendered"
fi

if [[ -n "$render_output" ]]; then
    fail "invalid centered layout produced terminal output"
fi

printf 'PASS: dynamic center alignment\n'
