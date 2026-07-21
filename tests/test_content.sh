#!/data/data/com.termux/files/usr/bin/bash

set -e

source src/utils.sh
source src/layout.sh
source src/render.sh
source src/dashboard.sh


fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}


assert_equal() {
    local actual="$1"
    local expected="$2"
    local message="$3"

    if [[ "$actual" != "$expected" ]]; then
        fail "$message"
    fi
}


ui_init

# Use the smallest supported terminal to test overflow behavior.
TERM_WIDTH=34

ui_calculate_width ||
    fail "width calculation failed"

ui_calculate_margin ||
    fail "margin calculation failed"


# A short value must remain unchanged.
short_value="Android 11"

formatted_value=$(ui_ellipsize_value "$short_value") ||
    fail "short value formatting failed"

assert_equal \
    "$formatted_value" \
    "$short_value" \
    "short value was modified"


# A value exactly equal to UI_VALUE_WIDTH must remain unchanged.
printf -v exact_value '%*s' "$UI_VALUE_WIDTH" ""
exact_value="${exact_value// /A}"

formatted_value=$(ui_ellipsize_value "$exact_value") ||
    fail "exact-width value formatting failed"

assert_equal \
    "$formatted_value" \
    "$exact_value" \
    "exact-width value was modified"


# A long value must be shortened and end with the ellipsis marker.
long_value="${exact_value}XYZ"
ellipsis_width="${#UI_ELLIPSIS}"
visible_width=$((UI_VALUE_WIDTH - ellipsis_width))

expected_value="${long_value:0:visible_width}${UI_ELLIPSIS}"

formatted_value=$(ui_ellipsize_value "$long_value") ||
    fail "long value formatting failed"

assert_equal \
    "$formatted_value" \
    "$expected_value" \
    "long value was not ellipsized correctly"

if (( ${#formatted_value} != UI_VALUE_WIDTH )); then
    fail "ellipsized value has width ${#formatted_value}, expected $UI_VALUE_WIDTH"
fi


# The rendered row must keep the dashboard width unchanged.
ui_title "TERMUX NEO"
ui_add_row "DEVICE" "$long_value"

render_output=$(ui_render) ||
    fail "valid content was not rendered"

row_line=$(printf '%s\n' "$render_output" | sed -n '4p')

expected_line_width=$((
    UI_MARGIN_LEFT
    + UI_WIDTH
    + UI_BORDER_TOTAL_WIDTH
))

if (( ${#row_line} != expected_line_width )); then
    fail "rendered row has width ${#row_line}, expected $expected_line_width"
fi

if [[ "$row_line" != *"$expected_value"* ]]; then
    fail "rendered row does not contain the ellipsized value"
fi


# A title wider than the dashboard must fail before rendering.
UI_ROWS=()

printf -v long_title '%*s' "$((UI_WIDTH + 1))" ""
long_title="${long_title// /T}"

ui_title "$long_title"

render_output=""

if render_output=$(ui_render); then
    fail "oversized title was rendered"
fi

if [[ -n "$render_output" ]]; then
    fail "oversized title produced terminal output"
fi


# A key wider than UI_KEY_WIDTH must fail before rendering.
UI_ROWS=()
ui_title "TERMUX NEO"

printf -v long_key '%*s' "$((UI_KEY_WIDTH + 1))" ""
long_key="${long_key// /K}"

ui_add_row "$long_key" "value"

render_output=""

if render_output=$(ui_render); then
    fail "oversized key was rendered"
fi

if [[ -n "$render_output" ]]; then
    fail "oversized key produced terminal output"
fi


# Multiline values must not break the single-line dashboard.
UI_ROWS=()
ui_add_row "USER" $'Zoro\nRoot'

render_output=""

if render_output=$(ui_render); then
    fail "multiline value was rendered"
fi

if [[ -n "$render_output" ]]; then
    fail "multiline value produced terminal output"
fi


printf 'PASS: single-line overflow safety\n'
