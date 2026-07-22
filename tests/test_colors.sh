#!/data/data/com.termux/files/usr/bin/bash
set -e

CACHE_DIR="$HOME/.cache/termux-neo"
fixture="$CACHE_DIR/test-colors-$$"
mkdir -p "$fixture"
trap 'rm -rf "$fixture"' EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

strip_ansi() {
    sed $'s/\033\\[[0-9;]*m//g'
}

source_output="$(bash -c 'source src/colors.sh')" ||
    fail "colors.sh could not be sourced"
[[ -z "$source_output" ]] || fail "sourcing colors.sh produced output"

source src/colors.sh

termux_neo_color_validate_sgr "1;36" || fail "valid SGR rejected"
if termux_neo_color_validate_sgr $'36\e[0m'; then
    fail "escape-bearing theme value accepted"
fi

NO_COLOR=1
termux_neo_color_configure neo always || fail "neo always mode rejected"
[[ "$TERMUX_NEO_COLOR_ENABLED" == "1" ]] ||
    fail "always mode did not override NO_COLOR"
[[ "$TERMUX_NEO_COLOR_ACTIVE_THEME" == "neo" ]] ||
    fail "neo theme was not activated"

colored="$(termux_neo_color_print title "TERMUX NEO")"
[[ "$colored" == *$'\e['* ]] || fail "always mode emitted no ANSI color"
[[ "$(printf '%s' "$colored" | strip_ansi)" == "TERMUX NEO" ]] ||
    fail "color changed rendered text"

termux_neo_color_configure matrix never || fail "matrix never mode rejected"
[[ "$TERMUX_NEO_COLOR_ENABLED" == "0" ]] || fail "never mode enabled color"
[[ "$TERMUX_NEO_COLOR_ACTIVE_THEME" == "matrix" ]] ||
    fail "matrix theme was not selected"
plain="$(termux_neo_color_print prompt "╰─❯")"
[[ "$plain" == "╰─❯" ]] || fail "never mode changed plain output"
[[ "$plain" != *$'\e['* ]] || fail "never mode leaked ANSI color"

(
    termux_neo_color_terminal_supported() { return 0; }
    NO_COLOR=1
    termux_neo_color_configure neo auto || exit 1
    [[ "$TERMUX_NEO_COLOR_ENABLED" == "0" ]]
) || fail "auto mode ignored NO_COLOR"

(
    termux_neo_color_terminal_supported() { return 0; }
    NO_COLOR=""
    termux_neo_color_configure neo auto || exit 1
    [[ "$TERMUX_NEO_COLOR_ENABLED" == "1" ]]
) || fail "auto mode rejected supported terminal"

(
    termux_neo_color_terminal_supported() { return 1; }
    NO_COLOR=""
    termux_neo_color_configure neo auto || exit 1
    [[ "$TERMUX_NEO_COLOR_ENABLED" == "0" ]]
) || fail "auto mode enabled unsupported terminal"

if termux_neo_color_configure cyber always; then
    fail "unknown theme accepted"
fi
if termux_neo_color_configure neo sometimes; then
    fail "unknown color mode accepted"
fi

cat > "$fixture/always.conf" <<'CONFIG'
schema_version=1
display_user=Zoro
theme=matrix
color_mode=always
startup_integration=false
CONFIG

cat > "$fixture/never.conf" <<'CONFIG'
schema_version=1
display_user=Zoro
theme=matrix
color_mode=never
startup_integration=false
CONFIG

source src/main.sh

TEST_TERM_WIDTH=56
tput() {
    case "${1-}" in
        cols) printf '%s' "$TEST_TERM_WIDTH" ;;
        colors) printf '256' ;;
        *) return 1 ;;
    esac
}

module_device_user() { printf 'u0_a191'; }
module_device_name() { printf 'Samsung Note5'; }
module_system_name() { printf 'Android 11'; }
module_network_type() { printf 'Wi-Fi'; }
module_network_local_ip() { printf '192.168.0.135'; }
module_network_state() { printf 'UP'; }
module_vpn_state() { printf 'ON'; }
module_battery_value() { printf '82+'; }
module_time_value() { printf '21:35'; }

TERMUX_NEO_CONFIG_PATH="$fixture/always.conf"
NO_COLOR=1
original_pwd="$PWD"
cd "$HOME"
termux_neo_render_once > "$fixture/colored.out" 2> "$fixture/colored.err" ||
    fail "always-mode production render failed"
cd "$original_pwd"
[[ ! -s "$fixture/colored.err" ]] || fail "always mode produced stderr"
grep -q $'\e\\[' "$fixture/colored.out" || fail "rendered UI has no color"

for entry in "${UI_ROWS[@]}" "${UI_STATUS[@]}" \
    "$UI_PROMPT_USER" "$UI_PROMPT_PATH" "$UI_STATUS_TEXT" \
    "$UI_PROMPT_LINE_TOP" "$UI_PROMPT_LINE_BOTTOM"
do
    [[ "$entry" != *$'\e'* ]] || fail "ANSI escape leaked into UI state"
done

TERMUX_NEO_CONFIG_PATH="$fixture/never.conf"
cd "$HOME"
termux_neo_render_once > "$fixture/plain.out" 2> "$fixture/plain.err" ||
    fail "never-mode production render failed"
cd "$original_pwd"
[[ ! -s "$fixture/plain.err" ]] || fail "never mode produced stderr"
if grep -q $'\e\\[' "$fixture/plain.out"; then
    fail "never-mode UI contains ANSI escapes"
fi

strip_ansi < "$fixture/colored.out" > "$fixture/stripped.out"
cmp -s "$fixture/stripped.out" "$fixture/plain.out" ||
    fail "color changed UI text or geometry"

mapfile -t lines < "$fixture/plain.out"
(( ${#lines[@]} == 16 )) || fail "no-color output is incomplete"
(( ${#lines[0]} == 50 )) || fail "no-color Dashboard geometry changed"
[[ "${lines[14]}" == "      ╭─ Zoro • ~" ]] ||
    fail "no-color Prompt geometry changed"

printf 'PASS: theme selection and color modes\n'
printf 'PASS: NO_COLOR and terminal capability behavior\n'
printf 'PASS: color-safe state and unchanged visible geometry\n'
