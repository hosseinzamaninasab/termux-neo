#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - Stable Command Interface
# ==========================================================

TERMUX_NEO_CLI_USAGE_STATUS=2
TERMUX_NEO_CLI_UNAVAILABLE_STATUS=3

TERMUX_NEO_CLI_THEME_OVERRIDE=""
TERMUX_NEO_CLI_COLOR_MODE_OVERRIDE=""

termux_neo_cli_error() {
    local message="${1-unknown error}"

    printf 'termux-neo: %s\n' "$message" >&2
}

termux_neo_cli_help() {
    printf '%s\n' \
        'Usage: termux-neo [OPTION]' \
        '' \
        'Render the Termux Neo dashboard once, then exit.' \
        '' \
        'Options:' \
        '  --help          Show this help and exit' \
        '  --version       Show the application version and exit' \
        '  --diagnose      Run built-in diagnostics and exit' \
        '  --config        Print the active configuration path and exit' \
        '  --startup       Sync the Bash startup hook to saved settings' \
        '  --theme NAME    Render once with theme neo or matrix' \
        '  --no-color      Render once without ANSI color' \
        '' \
        'Runtime options do not rewrite the configuration file.'
}

termux_neo_cli_version() {
    local version_file="$PROJECT_ROOT/VERSION"
    local version=""

    if [[ ! -f "$version_file" || -L "$version_file" ||
          ! -r "$version_file" ]]; then
        termux_neo_cli_error "version file is unavailable"
        return 1
    fi

    IFS= read -r version < "$version_file" || {
        termux_neo_cli_error "version file could not be read"
        return 1
    }

    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
        termux_neo_cli_error "version file is invalid"
        return 1
    fi

    printf 'termux-neo %s\n' "$version"
}

termux_neo_cli_config_path() {
    local config_path="${TERMUX_NEO_CONFIG_PATH-}"

    if [[ -z "$config_path" ||
          "$config_path" =~ [[:cntrl:]] ]]
    then
        termux_neo_cli_error "configuration path is invalid"
        return 1
    fi

    printf '%s\n' "$config_path"
}

termux_neo_cli_diagnose() {
    if declare -F termux_neo_diagnose >/dev/null 2>&1; then
        termux_neo_diagnose
        return
    fi

    termux_neo_cli_error "diagnostics are unavailable until the next release step"
    return "$TERMUX_NEO_CLI_UNAVAILABLE_STATUS"
}

termux_neo_cli_dispatch() {
    local option="${1-}"

    TERMUX_NEO_CLI_THEME_OVERRIDE=""
    TERMUX_NEO_CLI_COLOR_MODE_OVERRIDE=""

    if (( $# == 0 )); then
        termux_neo_render_once
        return
    fi

    case "$option" in
        --help)
            if (( $# != 1 )); then
                termux_neo_cli_error "--help does not accept additional arguments"
                return "$TERMUX_NEO_CLI_USAGE_STATUS"
            fi
            termux_neo_cli_help
            ;;
        --version)
            if (( $# != 1 )); then
                termux_neo_cli_error "--version does not accept additional arguments"
                return "$TERMUX_NEO_CLI_USAGE_STATUS"
            fi
            termux_neo_cli_version
            ;;
        --diagnose)
            if (( $# != 1 )); then
                termux_neo_cli_error "--diagnose does not accept additional arguments"
                return "$TERMUX_NEO_CLI_USAGE_STATUS"
            fi
            termux_neo_cli_diagnose
            ;;
        --config)
            if (( $# != 1 )); then
                termux_neo_cli_error "--config does not accept additional arguments"
                return "$TERMUX_NEO_CLI_USAGE_STATUS"
            fi
            termux_neo_cli_config_path
            ;;
        --startup)
            if (( $# != 1 )); then
                termux_neo_cli_error "--startup does not accept additional arguments"
                return "$TERMUX_NEO_CLI_USAGE_STATUS"
            fi
            termux_neo_startup_sync
            ;;
        --theme)
            if (( $# != 2 )); then
                termux_neo_cli_error "--theme requires one value: neo or matrix"
                return "$TERMUX_NEO_CLI_USAGE_STATUS"
            fi
            if ! termux_neo_config_validate_theme "$2"; then
                termux_neo_cli_error "invalid theme; expected neo or matrix"
                return "$TERMUX_NEO_CLI_USAGE_STATUS"
            fi
            TERMUX_NEO_CLI_THEME_OVERRIDE="$2"
            termux_neo_render_once
            ;;
        --no-color)
            if (( $# != 1 )); then
                termux_neo_cli_error "--no-color does not accept additional arguments"
                return "$TERMUX_NEO_CLI_USAGE_STATUS"
            fi
            TERMUX_NEO_CLI_COLOR_MODE_OVERRIDE="never"
            termux_neo_render_once
            ;;
        *)
            termux_neo_cli_error "unknown argument; use --help"
            return "$TERMUX_NEO_CLI_USAGE_STATUS"
            ;;
    esac
}
