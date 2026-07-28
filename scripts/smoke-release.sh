#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(dirname "$SCRIPT_DIR")"
TEMP_PARENT="${TMPDIR:-/tmp}"
TEMP_PARENT="${TEMP_PARENT%/}"
TEMP_DIR=""

smoke_error() {
    printf 'termux-neo release smoke: %s\n' \
        "${1-release smoke verification failed}" >&2
}

smoke_fail() {
    smoke_error "${1-release smoke verification failed}"
    exit 1
}

smoke_path_is_safe() {
    local value="${1-}"

    [[ "$value" == /* ]] || return 1
    [[ "$value" != "/" ]] || return 1
    [[ "$value" != *"//"* ]] || return 1
    [[ "$value" != *"/./"* && "$value" != */. ]] || return 1
    [[ "$value" != *"/../"* && "$value" != */.. ]] || return 1
    [[ ! "$value" =~ [[:cntrl:]] ]]
}

smoke_cleanup() {
    local exit_code=$?

    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" &&
          "$TEMP_DIR" == "$TEMP_PARENT"/termux-neo-smoke.* ]]
    then
        rm -rf -- "$TEMP_DIR" || true
    fi
    return "$exit_code"
}

trap smoke_cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

for required_command in bash chmod find mktemp rm wc
do
    command -v "$required_command" >/dev/null 2>&1 ||
        smoke_fail "required command is unavailable: $required_command"
done

[[ -d "$PACKAGE_ROOT" && ! -L "$PACKAGE_ROOT" ]] ||
    smoke_fail "package root is not a regular directory"
[[ -f "$PACKAGE_ROOT/VERSION" &&
   ! -L "$PACKAGE_ROOT/VERSION" &&
   -f "$PACKAGE_ROOT/src/main.sh" &&
   ! -L "$PACKAGE_ROOT/src/main.sh" &&
   -f "$PACKAGE_ROOT/config/settings.example.conf" ]] ||
    smoke_fail "package smoke inputs are incomplete"
[[ ! -L "$PACKAGE_ROOT/config/settings.example.conf" ]] ||
    smoke_fail "package smoke inputs contain a symbolic link"

smoke_path_is_safe "$TEMP_PARENT" ||
    smoke_fail "temporary directory parent is unsafe"
[[ -d "$TEMP_PARENT" && ! -L "$TEMP_PARENT" && -w "$TEMP_PARENT" ]] ||
    smoke_fail "temporary directory parent is unavailable"

unexpected_link="$(find "$PACKAGE_ROOT" -type l -print -quit)" ||
    smoke_fail "package tree could not be inspected"
[[ -z "$unexpected_link" ]] ||
    smoke_fail "package tree contains a symbolic link"

IFS= read -r version < "$PACKAGE_ROOT/VERSION" ||
    smoke_fail "VERSION could not be read"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] ||
    smoke_fail "VERSION is invalid"

while IFS= read -r -d '' shell_file; do
    bash -n "$shell_file" ||
        smoke_fail "shell syntax failed: ${shell_file#"$PACKAGE_ROOT/"}"
done < <(
    find \
        "$PACKAGE_ROOT/install.sh" \
        "$PACKAGE_ROOT/update.sh" \
        "$PACKAGE_ROOT/uninstall.sh" \
        "$PACKAGE_ROOT/bin" \
        "$PACKAGE_ROOT/scripts" \
        "$PACKAGE_ROOT/src" \
        -type f \
        \( -name '*.sh' -o -name '*.theme' -o -name 'termux-neo' \) \
        -print0
)

TEMP_DIR="$(mktemp -d "$TEMP_PARENT/termux-neo-smoke.XXXXXX")" ||
    smoke_fail "temporary directory could not be created"
chmod 700 "$TEMP_DIR"

version_output="$(
    HOME="$TEMP_DIR" \
    TERMUX_NEO_CONFIG_PATH="$PACKAGE_ROOT/config/settings.example.conf" \
        bash "$PACKAGE_ROOT/src/main.sh" --version
)" || smoke_fail "packaged version command failed"
[[ "$version_output" == "termux-neo $version" ]] ||
    smoke_fail "packaged version output is inconsistent"

help_output="$(
    HOME="$TEMP_DIR" \
    TERMUX_NEO_CONFIG_PATH="$PACKAGE_ROOT/config/settings.example.conf" \
        bash "$PACKAGE_ROOT/src/main.sh" --help
)" || smoke_fail "packaged help command failed"
[[ "$help_output" == *"Usage: termux-neo [OPTION]"* ]] ||
    smoke_fail "packaged help output is incomplete"

render_output="$(
    bash -s -- "$PACKAGE_ROOT" "$TEMP_DIR" <<'SMOKE'
set -Eeuo pipefail

package_root="$1"
smoke_home="$2"
cd "$package_root"

export HOME="$smoke_home"
export TERMUX_NEO_CONFIG_PATH="$package_root/config/settings.example.conf"
export NO_COLOR=1

source src/main.sh

tput() {
    case "${1-}" in
        cols) printf '56' ;;
        colors) printf '0' ;;
        *) return 1 ;;
    esac
}

module_device_user() { printf 'u0_smoke'; }
module_device_name() { printf 'Smoke Device'; }
module_system_name() { printf 'Android Smoke'; }
module_network_prepare_render_cache() { :; }
module_battery_prepare_render_cache() { :; }
module_network_type() { printf 'Wi-Fi'; }
module_network_local_ip() { printf '192.0.2.1'; }
module_network_state() { printf 'UP'; }
module_vpn_state() { printf 'OFF'; }
module_battery_value() { printf '50'; }
module_time_value() { printf '12:34'; }

termux_neo_render_once
SMOKE
)" || smoke_fail "packaged render-once command failed"

[[ "$(printf '%s\n' "$render_output" | wc -l)" == "16" ]] ||
    smoke_fail "packaged render line count is inconsistent"
[[ "$render_output" == *"TERMUX NEO"* &&
   "$render_output" == *"Smoke Device"* &&
   "$render_output" == *"NET:UP"* ]] ||
    smoke_fail "packaged render output is incomplete"
[[ "$render_output" != *$'\e'* ]] ||
    smoke_fail "packaged no-color render contains ANSI"

printf 'PASS: packaged release smoke verification\n'
