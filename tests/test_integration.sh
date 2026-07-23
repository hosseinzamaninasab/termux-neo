#!/data/data/com.termux/files/usr/bin/bash
set -e

CACHE_DIR="$HOME/.cache/termux-neo"
mkdir -p "$CACHE_DIR"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

capture_file="$CACHE_DIR/test-integration-output-$$"
error_file="$CACHE_DIR/test-integration-error-$$"
fake_bin="$CACHE_DIR/test-integration-bin-$$"
entry_root="$CACHE_DIR/test-integration-entry-$$"
test_config_path="$CACHE_DIR/test-integration-missing-config-$$"
export TERMUX_NEO_CONFIG_PATH="$test_config_path"
rm -f "$test_config_path"

cleanup() {
    rm -f "$capture_file" "$error_file"
    rm -rf "$fake_bin" "$entry_root"
    rm -f "$test_config_path"
}

trap cleanup EXIT

# ----------------------------------------------------------
# Sourcing main.sh must have no side effects
# ----------------------------------------------------------

source_output="$(bash -c 'source src/main.sh')" ||
    fail "main.sh could not be sourced"

[[ -z "$source_output" ]] ||
    fail "sourcing main.sh produced terminal output"

source src/main.sh

TEST_TERM_WIDTH=56

tput() {
    [[ "${1-}" == "cols" ]] || return 1
    printf '%s' "$TEST_TERM_WIDTH"
}

# ----------------------------------------------------------
# Deterministic production data
# ----------------------------------------------------------

module_device_user() {
    printf 'Zoro'
}

module_device_name() {
    printf 'Samsung Note5'
}

module_system_name() {
    printf 'Android 11'
}

module_network_type() {
    printf 'Wi-Fi'
}

module_network_local_ip() {
    printf '192.168.0.135'
}

module_network_state() {
    printf 'UP'
}

module_vpn_state() {
    printf 'ON'
}

module_battery_value() {
    printf '82+'
}

module_time_value() {
    printf '21:35'
}

original_pwd="$PWD"
cd "$HOME"

rm -f "$capture_file" "$error_file"

termux_neo_render_once > "$capture_file" 2> "$error_file" ||
    fail "deterministic render-once flow failed"

cd "$original_pwd"

[[ ! -s "$error_file" ]] ||
    fail "deterministic flow produced stderr"

mapfile -t lines < "$capture_file"

(( ${#lines[@]} == 16 )) ||
    fail "integrated output line count mismatch"

[[ "${lines[0]}" == \
   "      ╔══════════════════════════════════════════╗" ]] ||
    fail "Dashboard top line mismatch"

[[ "${lines[1]}" == \
   "      ║                TERMUX NEO                ║" ]] ||
    fail "Dashboard title line mismatch"

[[ "${lines[3]}" == *"USER"*"Zoro"* ]] ||
    fail "USER row ordering mismatch"

[[ "${lines[4]}" == *"DEVICE"*"Samsung Note5"* ]] ||
    fail "DEVICE row ordering mismatch"

[[ "${lines[5]}" == *"SYSTEM"*"Android 11"* ]] ||
    fail "SYSTEM row ordering mismatch"

[[ "${lines[6]}" == *"NETWORK"*"Wi-Fi"* ]] ||
    fail "NETWORK row ordering mismatch"

[[ "${lines[7]}" == *"LOCAL IP"*"192.168.0.135"* ]] ||
    fail "LOCAL IP row ordering mismatch"

[[ "${lines[8]}" == \
   "      ╚══════════════════════════════════════════╝" ]] ||
    fail "Dashboard bottom line mismatch"

[[ -z "${lines[9]}" ]] ||
    fail "Dashboard and Status are not separated by one blank line"

[[ "${lines[10]}" == "${lines[12]}" ]] ||
    fail "Status rules do not match"

[[ "${lines[11]}" == \
   *"NET:UP • VPN:ON • BAT:82+ • TIME:21:35"* ]] ||
    fail "Status ordering mismatch"

[[ -z "${lines[13]}" ]] ||
    fail "Status and Prompt are not separated by one blank line"

[[ "${lines[14]}" == "      ╭─ Zoro • ~" ]] ||
    fail "Prompt top line mismatch"

[[ "${lines[15]}" == "      ╰─❯" ]] ||
    fail "Prompt bottom line mismatch"

# ----------------------------------------------------------
# Landscape: capped 44-column UI with shared 25-space margin
# ----------------------------------------------------------

TEST_TERM_WIDTH=94

cd "$HOME"
rm -f "$capture_file" "$error_file"

termux_neo_render_once > "$capture_file" 2> "$error_file" ||
    fail "landscape render-once flow failed"

cd "$original_pwd"

[[ ! -s "$error_file" ]] ||
    fail "landscape flow produced stderr"

mapfile -t lines < "$capture_file"

margin_25="$(printf '%25s' '')"

for index in 0 1 2 3 4 5 6 7 8 10 11 12 14 15
do
    [[ "${lines[index]:0:25}" == "$margin_25" ]] ||
        fail "landscape line $index does not use shared margin"
done

(( ${#lines[0]} == 69 )) ||
    fail "landscape Dashboard outer width is not capped at 44"

(( ${#lines[10]} == 69 )) ||
    fail "landscape Status outer width is not capped at 44"

# ----------------------------------------------------------
# Module failures use safe fallbacks and remain silent
# ----------------------------------------------------------

TEST_TERM_WIDTH=56

module_device_user() {
    printf 'Bad User'
}

module_device_name() {
    return 1
}

module_system_name() {
    printf ''
}

module_network_type() {
    return 1
}

module_network_local_ip() {
    printf ''
}

module_network_state() {
    printf 'UNKNOWN'
}

module_vpn_state() {
    printf 'UNKNOWN'
}

module_battery_value() {
    printf 'invalid'
}

module_time_value() {
    printf 'invalid'
}

cd "$HOME"
rm -f "$capture_file" "$error_file"

termux_neo_render_once > "$capture_file" 2> "$error_file" ||
    fail "fallback render-once flow failed"

cd "$original_pwd"

[[ ! -s "$error_file" ]] ||
    fail "fallback flow produced stderr"

output="$(cat "$capture_file")"

[[ "$output" == *"USER      User"* ]] ||
    fail "Shared user fallback scenario mismatch"

[[ "$output" == *"DEVICE    Android Device"* ]] ||
    fail "Device fallback missing"

[[ "$output" == *"SYSTEM    Android"* ]] ||
    fail "System fallback missing"

[[ "$output" == *"NETWORK   Offline"* ]] ||
    fail "Network-type fallback missing"

[[ "$output" == *"LOCAL IP  Unavailable"* ]] ||
    fail "Local-IP fallback missing"

[[ "$output" == *"NET:DOWN • VPN:OFF • BAT:-- • TIME:--:--"* ]] ||
    fail "Status fallbacks missing"

[[ "$output" == *"╭─ User • ~"* ]] ||
    fail "Prompt user fallback missing"

# ----------------------------------------------------------
# Unsupported width produces no partial output
# ----------------------------------------------------------

TEST_TERM_WIDTH=33
rm -f "$capture_file" "$error_file"

if termux_neo_render_once > "$capture_file" 2> "$error_file"; then
    fail "unsupported terminal width was accepted"
fi

[[ ! -s "$capture_file" ]] ||
    fail "unsupported width produced partial terminal output"

[[ ! -s "$error_file" ]] ||
    fail "unsupported width produced raw stderr"

# ----------------------------------------------------------
# Real entry point invokes the production flow
# ----------------------------------------------------------

mkdir -p "$fake_bin"
mkdir -p "$entry_root"
cp -pR bin src "$entry_root/"

# The product shebang intentionally names Termux Bash. Adapt only the copied
# entry target so the same launcher path can be exercised on a portable host.
{
    printf '#!%s\n' "$(command -v bash)"
    tail -n +2 src/main.sh
} > "$entry_root/src/main.sh"
chmod 755 "$entry_root/src/main.sh"

printf '#!%s\n' "$(command -v bash)" > "$fake_bin/tput"
cat >> "$fake_bin/tput" <<'MOCK'
if [[ "${1-}" == "cols" ]]; then
    printf '56'
    exit 0
fi
exit 1
MOCK

chmod 755 "$fake_bin/tput"

rm -f "$capture_file" "$error_file"

PATH="$fake_bin:$PATH" \
    bash "$entry_root/bin/termux-neo" > "$capture_file" 2> "$error_file" ||
    fail "bin/termux-neo did not invoke the production flow"

[[ ! -s "$error_file" ]] ||
    fail "entry point produced stderr"

mapfile -t lines < "$capture_file"

(( ${#lines[@]} == 16 )) ||
    fail "entry point output line count mismatch"

[[ "${lines[0]}" == \
   "      ╔══════════════════════════════════════════╗" ]] ||
    fail "entry point did not render Dashboard first"

[[ -z "${lines[9]}" && -z "${lines[13]}" ]] ||
    fail "entry point blank-line ordering mismatch"

[[ "${lines[14]}" == *"╭─ "*" • "* ]] ||
    fail "entry point did not render Prompt after Status"

printf 'PASS: render-once production integration\n'
