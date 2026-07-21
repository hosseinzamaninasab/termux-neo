#!/data/data/com.termux/files/usr/bin/bash
set -e

source src/utils.sh
source src/layout.sh
source src/render.sh
source src/status.sh

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
# Empty Status produces no output
# ----------------------------------------------------------

prepare_layout 56

output=$(ui_render_status)

[[ -z "$output" ]] ||
    fail "empty Status produced output"

# ----------------------------------------------------------
# Default rendering
# ----------------------------------------------------------

prepare_layout 56
add_default_status

ui_calculate_status_layout ||
    fail "default Status layout failed"

output=$(ui_render_status) ||
    fail "default Status rendering failed"

mapfile -t lines <<< "$output"

(( ${#lines[@]} == 3 )) ||
    fail "Status renderer did not produce exactly three lines"

printf -v margin '%*s' "$UI_MARGIN_LEFT" ""
printf -v left_padding '%*s' "$UI_STATUS_PADDING_LEFT" ""
printf -v right_padding '%*s' "$UI_STATUS_PADDING_RIGHT" ""

expected_rule_line="${margin}${UI_STATUS_RULE}"
expected_content_line="${margin}${left_padding}${UI_STATUS_TEXT}${right_padding}"

[[ "${lines[0]}" == "$expected_rule_line" ]] ||
    fail "top Status rule mismatch"

[[ "${lines[1]}" == "$expected_content_line" ]] ||
    fail "Status content line mismatch"

[[ "${lines[2]}" == "$expected_rule_line" ]] ||
    fail "bottom Status rule mismatch"

(( ${#lines[0]} == TERM_WIDTH - UI_MARGIN_LEFT )) ||
    fail "top rule terminal alignment mismatch"

(( ${#UI_STATUS_RULE} == 44 )) ||
    fail "default Status rule is not 44 columns"

[[ "${lines[1]}" == *"NET:UP · VPN:ON · BAT:82+ · TIME:21:35"* ]] ||
    fail "default Status text missing"

[[ "$output" != *"%"* ]] ||
    fail "Status output contains a percent sign"

# ----------------------------------------------------------
# Narrow rendering
# ----------------------------------------------------------

prepare_layout 34
add_default_status

output=$(ui_render_status) ||
    fail "narrow Status rendering failed"

mapfile -t lines <<< "$output"

(( ${#lines[@]} == 3 )) ||
    fail "narrow Status renderer line count mismatch"

(( ${#lines[0]} == 34 )) ||
    fail "narrow top rule width mismatch"

(( ${#lines[1]} == 34 )) ||
    fail "narrow content width mismatch"

(( ${#lines[2]} == 34 )) ||
    fail "narrow bottom rule width mismatch"

[[ "${lines[1]}" == *"NET:UP · VPN:ON · BAT:82+ · …"* ]] ||
    fail "narrow overflow output mismatch"

# ----------------------------------------------------------
# Invalid data produces no partial output
# ----------------------------------------------------------

prepare_layout 56
ui_add_status "NET" $'UP\nDOWN'

output_file="$HOME/.cache/termux-neo/status-invalid-output"
: > "$output_file"

if ui_render_status > "$output_file"; then
    fail "invalid Status content was rendered"
fi

[[ ! -s "$output_file" ]] ||
    fail "invalid Status produced partial output"

rm -f "$output_file"

printf 'PASS: responsive status renderer\n'
