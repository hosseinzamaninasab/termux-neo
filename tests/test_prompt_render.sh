#!/data/data/com.termux/files/usr/bin/bash
set -e

source src/utils.sh
source src/layout.sh
source src/render.sh
source src/prompt.sh

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

# ----------------------------------------------------------
# Empty state produces no output
# ----------------------------------------------------------

ui_init
TERM_WIDTH=56

output="$(ui_render_prompt)" ||
    fail "empty Prompt renderer returned failure"

[[ -z "$output" ]] ||
    fail "empty Prompt state produced output"

# ----------------------------------------------------------
# Default two-line Prompt
# ----------------------------------------------------------

ui_init
TERM_WIDTH=56
ui_set_prompt "Zoro" "~"

output="$(ui_render_prompt)" ||
    fail "default Prompt renderer failed"

mapfile -t lines <<< "$output"

(( ${#lines[@]} == 2 )) ||
    fail "default Prompt did not render exactly two lines"

[[ "${lines[0]}" == "      ╭─ Zoro • ~" ]] ||
    fail "default Prompt top line mismatch"

[[ "${lines[1]}" == "      ╰─❯" ]] ||
    fail "default Prompt bottom line mismatch"

# ----------------------------------------------------------
# Narrow Prompt has no terminal margin
# ----------------------------------------------------------

ui_init
TERM_WIDTH=34
ui_set_prompt "Zoro" "~/Projects/termux-neo/src/modules"

output="$(ui_render_prompt)" ||
    fail "narrow Prompt renderer failed"

mapfile -t lines <<< "$output"

(( ${#lines[@]} == 2 )) ||
    fail "narrow Prompt did not render exactly two lines"

[[ "${lines[0]}" == "╭─ Zoro • …/termux-neo/src/modules" ]] ||
    fail "narrow Prompt top line mismatch"

[[ "${lines[1]}" == "╰─❯" ]] ||
    fail "narrow Prompt bottom line mismatch"

(( ${#lines[0]} == 34 )) ||
    fail "narrow Prompt top line width mismatch"

# ----------------------------------------------------------
# Wide terminal uses common centered margin
# ----------------------------------------------------------

ui_init
TERM_WIDTH=94
ui_set_prompt "Zoro" "~/Projects/termux-neo"

output="$(ui_render_prompt)" ||
    fail "wide Prompt renderer failed"

mapfile -t lines <<< "$output"

[[ "${lines[0]}" == "                         ╭─ Zoro • ~/Projects/termux-neo" ]] ||
    fail "wide Prompt top margin mismatch"

[[ "${lines[1]}" == "                         ╰─❯" ]] ||
    fail "wide Prompt bottom margin mismatch"

# ----------------------------------------------------------
# Invalid data produces no partial output
# ----------------------------------------------------------

ui_init
TERM_WIDTH=56
ui_set_prompt "Zoro" $'~/bad\npath'

capture_file="$HOME/.cache/termux-neo/test-prompt-invalid-output"
rm -f "$capture_file"

if ui_render_prompt > "$capture_file"; then
    rm -f "$capture_file"
    fail "invalid Prompt content was accepted"
fi

[[ ! -s "$capture_file" ]] || {
    rm -f "$capture_file"
    fail "invalid Prompt produced partial output"
}

rm -f "$capture_file"

# ----------------------------------------------------------
# Oversized username produces no partial output
# ----------------------------------------------------------

ui_init
TERM_WIDTH=34
ui_set_prompt "ThisUsernameIsFarTooLongToFitInsideThePromptWidth" "~"

capture_file="$HOME/.cache/termux-neo/test-prompt-long-user-output"
rm -f "$capture_file"

if ui_render_prompt > "$capture_file"; then
    rm -f "$capture_file"
    fail "oversized Prompt username was accepted"
fi

[[ ! -s "$capture_file" ]] || {
    rm -f "$capture_file"
    fail "oversized Prompt username produced partial output"
}

rm -f "$capture_file"

printf 'PASS: responsive prompt renderer\n'
