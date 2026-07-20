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

    TERM_WIDTH="$term_width"

    if ! ui_calculate_width; then
        fail "TERM_WIDTH=$term_width was rejected"
    fi

    if (( UI_WIDTH != expected_ui_width )); then
        fail "TERM_WIDTH=$term_width produced UI_WIDTH=$UI_WIDTH"
    fi

    if (( UI_VALUE_WIDTH != expected_value_width )); then
        fail "TERM_WIDTH=$term_width produced UI_VALUE_WIDTH=$UI_VALUE_WIDTH"
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
}

ui_init

# Unsupported terminal.
assert_rejected 33

# Small responsive terminals.
assert_layout 34 32 20
assert_layout 35 33 21
assert_layout 40 38 26

# Default-width and large terminals.
assert_layout 44 42 30
assert_layout 56 42 30
assert_layout 94 42 30

# Verify that odd dashboard widths still render equal-length lines.
TERM_WIDTH=35

ui_calculate_width || fail "odd-width layout calculation failed"

ui_title "TERMUX NEO"
ui_add_row "USER" "Zoro"

render_output=$(ui_render) || fail "valid odd-width layout was not rendered"

expected_total_width=$((UI_WIDTH + UI_BORDER_TOTAL_WIDTH))
line_number=0

while IFS= read -r line
do
    ((line_number += 1))

    if (( ${#line} != expected_total_width )); then
        fail "rendered line $line_number has width ${#line}, expected $expected_total_width"
    fi
done <<< "$render_output"

# Invalid layout must fail before producing output.
TERM_WIDTH=33

if ui_calculate_width; then
    fail "unsupported terminal width was accepted"
fi

render_output=""

if render_output=$(ui_render); then
    fail "invalid layout was rendered"
fi

if [[ -n "$render_output" ]]; then
    fail "invalid layout produced terminal output"
fi

printf 'PASS: dynamic layout width\n'
