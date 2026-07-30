#!/data/data/com.termux/files/usr/bin/bash
set -e

CACHE_DIR="$HOME/.cache/termux-neo"
fixture="$CACHE_DIR/test-cli-$$"
stdout_file="$fixture/stdout"
stderr_file="$fixture/stderr"
probe_file="$fixture/probes"

mkdir -p "$fixture"
trap 'rm -rf "$fixture"' EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

run_cli() {
    local expected_status="$1"
    local actual_status=0
    shift

    : > "$stdout_file"
    : > "$stderr_file"

    set +e
    termux_neo_cli_dispatch "$@" > "$stdout_file" 2> "$stderr_file"
    actual_status=$?
    set -e

    [[ "$actual_status" == "$expected_status" ]] ||
        fail "unexpected status $actual_status for: $*"
}

source_output="$(bash -c 'source src/main.sh')" ||
    fail "main.sh could not be sourced"
[[ -z "$source_output" ]] || fail "sourcing main.sh produced output"

source src/main.sh

module_device_user() { printf 'device\n' >> "$probe_file"; }
module_device_name() { printf 'device\n' >> "$probe_file"; }
module_system_name() { printf 'device\n' >> "$probe_file"; }
module_network_type() { printf 'device\n' >> "$probe_file"; }
module_network_local_ip() { printf 'device\n' >> "$probe_file"; }
module_network_state() { printf 'device\n' >> "$probe_file"; }
module_vpn_state() { printf 'device\n' >> "$probe_file"; }
module_battery_value() { printf 'device\n' >> "$probe_file"; }
module_time_value() { printf 'device\n' >> "$probe_file"; }

render_count=0
termux_neo_render_once() {
    (( render_count += 1 ))
    printf 'render:%s:%s\n' \
        "${TERMUX_NEO_CLI_THEME_OVERRIDE-}" \
        "${TERMUX_NEO_CLI_COLOR_MODE_OVERRIDE-}"
}

: > "$probe_file"

run_cli 0 --help
grep -Fq 'Usage: termux-neo [OPTION]' "$stdout_file" ||
    fail "help usage is missing"
grep -Fq -- '--theme NAME' "$stdout_file" ||
    fail "help theme command is missing"
grep -Fq -- '--startup' "$stdout_file" ||
    fail "help startup command is missing"
[[ ! -s "$stderr_file" ]] || fail "help produced stderr"

run_cli 0 --version
[[ "$(cat "$stdout_file")" == "termux-neo 1.0.0" ]] ||
    fail "version output mismatch"
[[ ! -s "$stderr_file" ]] || fail "version produced stderr"

TERMUX_NEO_CONFIG_PATH="$fixture/settings.conf"
run_cli 0 --config
[[ "$(cat "$stdout_file")" == "$TERMUX_NEO_CONFIG_PATH" ]] ||
    fail "config path output mismatch"
[[ ! -s "$stderr_file" ]] || fail "config path produced stderr"

TERMUX_NEO_CONFIG_PATH=$'bad\npath'
run_cli 1 --config
[[ ! -s "$stdout_file" ]] || fail "invalid config path produced stdout"
[[ "$(cat "$stderr_file")" == \
   "termux-neo: configuration path is invalid" ]] ||
    fail "invalid config path error mismatch"

[[ ! -s "$probe_file" ]] ||
    fail "help, version, or config command probed device data"
(( render_count == 0 )) ||
    fail "help, version, or config command invoked the renderer"

startup_count=0
termux_neo_startup_sync() {
    (( startup_count += 1 ))
    printf 'startup\n'
}

run_cli 0 --startup
[[ "$(cat "$stdout_file")" == "startup" ]] ||
    fail "startup command did not enter the stable hook"
[[ ! -s "$stderr_file" ]] || fail "startup command produced stderr"
(( startup_count == 1 )) || fail "startup hook count mismatch"
(( render_count == 0 )) || fail "startup command invoked the renderer"

diagnostic_count=0
termux_neo_diagnose() {
    (( diagnostic_count += 1 ))
    printf 'diagnostics\n'
}

run_cli 0 --diagnose
[[ "$(cat "$stdout_file")" == "diagnostics" ]] ||
    fail "diagnostics command did not enter the stable hook"
[[ ! -s "$stderr_file" ]] || fail "diagnostics command produced stderr"
(( diagnostic_count == 1 )) || fail "diagnostics hook count mismatch"
(( render_count == 0 )) || fail "diagnostics command invoked the renderer"

run_cli 0
[[ "$(cat "$stdout_file")" == "render::" ]] ||
    fail "default command did not render once without overrides"

run_cli 0 --theme matrix
[[ "$(cat "$stdout_file")" == "render:matrix:" ]] ||
    fail "theme command did not install a runtime override"

run_cli 0 --no-color
[[ "$(cat "$stdout_file")" == "render::never" ]] ||
    fail "no-color command did not install a runtime override"

(( render_count == 3 )) || fail "rendering command count mismatch"

for invalid_case in \
    "--unknown" \
    "--help extra" \
    "--version extra" \
    "--diagnose extra" \
    "--config extra" \
    "--startup extra" \
    "--theme" \
    "--theme cyber" \
    "--theme neo extra" \
    "--no-color extra"
do
    read -r -a invalid_args <<< "$invalid_case"
    run_cli 2 "${invalid_args[@]}"
    [[ ! -s "$stdout_file" ]] ||
        fail "invalid command produced stdout: $invalid_case"
    [[ "$(cat "$stderr_file")" == termux-neo:* ]] ||
        fail "invalid command did not produce a concise stderr error"
done

(( render_count == 3 )) || fail "invalid command invoked the renderer"
(( startup_count == 1 )) || fail "invalid command invoked the startup hook"
[[ ! -s "$probe_file" ]] || fail "CLI unit paths probed device data"

grep -Fqx 'exec "$PROJECT_ROOT/src/main.sh" "$@"' bin/termux-neo ||
    fail "entry point does not forward command arguments"

termux_neo_config_reset
TERMUX_NEO_CONFIG_THEME="neo"
TERMUX_NEO_CONFIG_COLOR_MODE="auto"
termux_neo_config_apply_runtime_overrides "matrix" "never" ||
    fail "valid runtime overrides were rejected"
[[ "$TERMUX_NEO_CONFIG_THEME" == "matrix" ]] ||
    fail "theme runtime override was not committed"
[[ "$TERMUX_NEO_CONFIG_COLOR_MODE" == "never" ]] ||
    fail "color runtime override was not committed"

if termux_neo_config_apply_runtime_overrides "cyber" "always"; then
    fail "invalid theme runtime override was accepted"
fi
[[ "$TERMUX_NEO_CONFIG_THEME" == "matrix" &&
   "$TERMUX_NEO_CONFIG_COLOR_MODE" == "never" ]] ||
    fail "invalid runtime overrides partially changed config state"

if termux_neo_config_apply_runtime_overrides "neo" "sometimes"; then
    fail "invalid color runtime override was accepted"
fi
[[ "$TERMUX_NEO_CONFIG_THEME" == "matrix" &&
   "$TERMUX_NEO_CONFIG_COLOR_MODE" == "never" ]] ||
    fail "invalid color override partially changed config state"

# Verify that the CLI overrides reach the real render path without changing
# the saved settings file.
cat > "$fixture/runtime.conf" <<'CONFIG'
schema_version=1
display_user=Zoro
theme=neo
color_mode=always
startup_integration=false
CONFIG

source src/main.sh

tput() {
    case "${1-}" in
        cols) printf '56' ;;
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

TERMUX_NEO_CONFIG_PATH="$fixture/runtime.conf"
run_cli 0 --theme matrix
grep -q $'\e\\[32m' "$stdout_file" ||
    fail "theme CLI override did not reach the real renderer"
[[ ! -s "$stderr_file" ]] || fail "theme CLI render produced stderr"

run_cli 0 --no-color
if grep -q $'\e\\[' "$stdout_file"; then
    fail "no-color CLI override leaked ANSI escapes"
fi
[[ ! -s "$stderr_file" ]] || fail "no-color CLI render produced stderr"
mapfile -t rendered_lines < "$stdout_file"
(( ${#rendered_lines[@]} == 16 )) ||
    fail "no-color CLI render is incomplete"

grep -Fqx 'theme=neo' "$fixture/runtime.conf" ||
    fail "theme CLI override rewrote saved settings"
grep -Fqx 'color_mode=always' "$fixture/runtime.conf" ||
    fail "no-color CLI override rewrote saved settings"

printf 'PASS: stable command interface\n'
