#!/data/data/com.termux/files/usr/bin/bash
set -e

source src/utils.sh
source src/layout.sh

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_prompt_failure() {
    ui_init
    TERM_WIDTH=56
    ui_set_prompt "$1" "$2"

    if ui_calculate_prompt_layout; then
        fail "invalid Prompt content was accepted"
    fi

    [[ -z "$UI_PROMPT_LINE_TOP" ]] || fail "failed layout retained top line"
    [[ -z "$UI_PROMPT_LINE_BOTTOM" ]] || fail "failed layout retained bottom line"
    (( UI_PROMPT_WIDTH == 0 )) || fail "failed layout retained width"
}

ui_init
[[ "$UI_INLINE_SEPARATOR" == " • " ]] || fail "invalid shared separator"
[[ "$UI_STATUS_ITEM_SEPARATOR" == "$UI_INLINE_SEPARATOR" ]] || fail "Status separator mismatch"
[[ "$UI_PROMPT_ITEM_SEPARATOR" == "$UI_INLINE_SEPARATOR" ]] || fail "Prompt separator mismatch"
[[ "$UI_PROMPT_TOP_LEFT" == "╭" ]] || fail "invalid top-left character"
[[ "$UI_PROMPT_BOTTOM_LEFT" == "╰" ]] || fail "invalid bottom-left character"
[[ "$UI_PROMPT_HORIZONTAL" == "─" ]] || fail "invalid horizontal character"
[[ "$UI_PROMPT_SYMBOL" == "❯" ]] || fail "invalid Prompt symbol"

ui_set_prompt "Zoro" "~"
[[ "$UI_PROMPT_USER" == "Zoro" ]] || fail "Prompt user state mismatch"
[[ "$UI_PROMPT_PATH" == "~" ]] || fail "Prompt path state mismatch"

ui_init
TERM_WIDTH=56
ui_set_prompt "Zoro" "~"
ui_calculate_prompt_layout || fail "default layout failed"
(( UI_PROMPT_WIDTH == 44 )) || fail "default width mismatch"
(( UI_MARGIN_LEFT == 6 )) || fail "default margin mismatch"
[[ "$UI_PROMPT_LINE_TOP" == "╭─ Zoro • ~" ]] || fail "default top line mismatch"
[[ "$UI_PROMPT_LINE_BOTTOM" == "╰─❯" ]] || fail "default bottom line mismatch"

ui_init
TERM_WIDTH=56
ui_set_prompt "Zoro" "~/Projects/termux-neo"
ui_calculate_prompt_layout || fail "home path layout failed"
[[ "$UI_PROMPT_LINE_TOP" == "╭─ Zoro • ~/Projects/termux-neo" ]] || fail "home path mismatch"

ui_init
TERM_WIDTH=34
ui_set_prompt "Zoro" "~/Projects/termux-neo/src/modules"
ui_calculate_prompt_layout || fail "narrow layout failed"
(( UI_PROMPT_WIDTH == 34 )) || fail "narrow width mismatch"
(( UI_MARGIN_LEFT == 0 )) || fail "narrow margin mismatch"
[[ "$UI_PROMPT_LINE_TOP" == "╭─ Zoro • …/termux-neo/src/modules" ]] || fail "narrow path mismatch"
(( ${#UI_PROMPT_LINE_TOP} == 34 )) || fail "narrow line width mismatch"

ui_init
TERM_WIDTH=34
ui_set_prompt "Zoro" "/data/data/com.termux/files/home/Projects/termux-neo"
ui_calculate_prompt_layout || fail "absolute path layout failed"
[[ "$UI_PROMPT_LINE_TOP" == "╭─ Zoro • …/Projects/termux-neo" ]] || fail "absolute path mismatch"

ui_init
TERM_WIDTH=34
ui_set_prompt "Zoro" "~/this-component-name-is-far-too-long-for-the-prompt"
ui_calculate_prompt_layout || fail "long component fitting failed"
[[ "$UI_PROMPT_LINE_TOP" == "╭─ Zoro • …too-long-for-the-prompt" ]] || fail "long component fallback mismatch"
(( ${#UI_PROMPT_LINE_TOP} == 34 )) || fail "fallback width mismatch"

ui_init
TERM_WIDTH=94
ui_set_prompt "Zoro" "~/Projects/termux-neo"
ui_calculate_prompt_layout || fail "wide layout failed"
(( UI_PROMPT_WIDTH == 44 )) || fail "wide width mismatch"
(( UI_MARGIN_LEFT == 25 )) || fail "wide margin mismatch"

assert_prompt_failure "ThisUsernameIsFarTooLongToFitInsideThePromptWidth" "~"
assert_prompt_failure "" "~"
assert_prompt_failure "Zoro" ""
assert_prompt_failure "Zo ro" "~"
assert_prompt_failure "Zoro" $'~/bad\npath'
assert_prompt_failure "Zoro" $'~/bad\rpath'
assert_prompt_failure "Zoro" $'~/bad\tpath'
assert_prompt_failure "Zoro" $'~/bad\e[31mpath'
assert_prompt_failure "Zoro" "~/bad•path"

printf 'PASS: structured prompt state\n'
printf 'PASS: responsive prompt layout\n'
