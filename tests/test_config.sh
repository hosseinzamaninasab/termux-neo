#!/data/data/com.termux/files/usr/bin/bash
set -e

CACHE_DIR="$HOME/.cache/termux-neo"
fixture="$CACHE_DIR/test-config-$$"
mkdir -p "$fixture"
trap 'rm -rf "$fixture"' EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

source src/config.sh

termux_neo_config_load "$fixture/missing.conf" || fail "missing config rejected"
[[ -z "$TERMUX_NEO_CONFIG_DISPLAY_USER" ]] || fail "missing config retained state"

cat > "$fixture/valid.conf" <<'CONFIG'
# comment
display_user = Zoro
CONFIG

termux_neo_config_load "$fixture/valid.conf" || fail "valid config rejected"
[[ "$TERMUX_NEO_CONFIG_DISPLAY_USER" == "Zoro" ]] || fail "configured user mismatch"

resolved="$(termux_neo_config_resolve_display_user "Neo" "u0_a191")"
[[ "$resolved" == "Neo" ]] || fail "valid override did not win"

resolved="$(termux_neo_config_resolve_display_user "Bad User" "u0_a191")"
[[ "$resolved" == "Zoro" ]] || fail "invalid override bypassed config"

printf 'display_user=\n' > "$fixture/empty.conf"
printf 'display_user=Bad User\n' > "$fixture/space.conf"
printf 'display_user=Bad•User\n' > "$fixture/bullet.conf"
printf 'theme=neo\n' > "$fixture/unknown.conf"
printf 'display_user=Zoro\ndisplay_user=Neo\n' > "$fixture/duplicate.conf"
printf 'display_user=Zoro\nunexpected=Root\n' > "$fixture/multiline.conf"
printf 'display_user=\tZoro\n' > "$fixture/tab.conf"
printf 'display_user=Zoro\r\n' > "$fixture/cr.conf"
printf 'display_user=\e[31mZoro\n' > "$fixture/escape.conf"

for name in empty space bullet unknown duplicate multiline tab cr escape; do
    if termux_neo_config_load "$fixture/$name.conf"; then
        fail "invalid config accepted: $name"
    fi
done

termux_neo_config_load "$fixture/missing.conf" || fail "missing config rejected"
resolved="$(termux_neo_config_resolve_display_user "" "u0_a191")"
[[ "$resolved" == "u0_a191" ]] || fail "system user fallback mismatch"

resolved="$(termux_neo_config_resolve_display_user "" "Bad User")"
[[ "$resolved" == "User" ]] || fail "hard fallback mismatch"

marker="$fixture/executed"
cat > "$fixture/command.conf" <<CONFIG
display_user=\$(touch "$marker")
CONFIG

if termux_neo_config_load "$fixture/command.conf"; then
    fail "command-like config accepted"
fi
[[ ! -e "$marker" ]] || fail "config content executed"

source src/main.sh

TEST_TERM_WIDTH=56
tput() {
    [[ "${1-}" == "cols" ]] || return 1
    printf '%s' "$TEST_TERM_WIDTH"
}

module_device_user() { printf 'u0_a191'; }
module_device_name() { printf 'Samsung Note5'; }
module_system_name() { printf 'Android 11'; }
module_network_type() { printf 'Wi-Fi'; }
module_network_local_ip() { printf '192.168.0.135'; }
module_network_state() { printf 'UP'; }
module_vpn_state() { printf 'OFF'; }
module_battery_value() { printf '54'; }
module_time_value() { printf '07:03'; }

TERMUX_NEO_CONFIG_PATH="$fixture/valid.conf"
TERMUX_NEO_USER=""
termux_neo_prepare_state || fail "configured state failed"
[[ "${UI_ROWS[0]}" == "USER|Zoro" ]] || fail "Dashboard config mismatch"
[[ "$UI_PROMPT_USER" == "Zoro" ]] || fail "Prompt config mismatch"

TERMUX_NEO_USER="Neo"
termux_neo_prepare_state || fail "environment override failed"
[[ "${UI_ROWS[0]}" == "USER|Neo" ]] || fail "Dashboard override mismatch"
[[ "$UI_PROMPT_USER" == "Neo" ]] || fail "Prompt override mismatch"

TERMUX_NEO_USER="Bad User"
termux_neo_prepare_state || fail "invalid override fallback failed"
[[ "${UI_ROWS[0]}" == "USER|Zoro" ]] || fail "invalid override bypassed config"
[[ "$UI_PROMPT_USER" == "Zoro" ]] || fail "Prompt invalid override mismatch"

TERMUX_NEO_CONFIG_PATH="$fixture/missing.conf"
TERMUX_NEO_USER=""
termux_neo_prepare_state || fail "system fallback failed"
[[ "${UI_ROWS[0]}" == "USER|u0_a191" ]] || fail "system Dashboard fallback mismatch"
[[ "$UI_PROMPT_USER" == "u0_a191" ]] || fail "system Prompt fallback mismatch"

TERMUX_NEO_CONFIG_PATH="$fixture/space.conf"
if termux_neo_render_once >"$fixture/out" 2>"$fixture/err"; then
    fail "invalid config rendered"
fi
[[ ! -s "$fixture/out" ]] || fail "invalid config produced partial output"
[[ ! -s "$fixture/err" ]] || fail "invalid config produced stderr"

printf 'PASS: safe display user configuration\n'
printf 'PASS: display user precedence\n'
printf 'PASS: shared Dashboard and Prompt user\n'
