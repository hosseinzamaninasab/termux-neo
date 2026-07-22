#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - Theme and Color Boundary
# ==========================================================

COLOR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERMUX_NEO_THEME_DIR="$COLOR_SCRIPT_DIR/themes"

TERMUX_NEO_COLOR_ENABLED=0
TERMUX_NEO_COLOR_ACTIVE_THEME=""
TERMUX_NEO_COLOR_RESET=$'\e[0m'

TERMUX_NEO_COLOR_BORDER=""
TERMUX_NEO_COLOR_TITLE=""
TERMUX_NEO_COLOR_LABEL=""
TERMUX_NEO_COLOR_VALUE=""
TERMUX_NEO_COLOR_STATUS=""
TERMUX_NEO_COLOR_PROMPT=""

termux_neo_color_reset() {
    TERMUX_NEO_COLOR_ENABLED=0
    TERMUX_NEO_COLOR_ACTIVE_THEME=""

    TERMUX_NEO_COLOR_BORDER=""
    TERMUX_NEO_COLOR_TITLE=""
    TERMUX_NEO_COLOR_LABEL=""
    TERMUX_NEO_COLOR_VALUE=""
    TERMUX_NEO_COLOR_STATUS=""
    TERMUX_NEO_COLOR_PROMPT=""
}

termux_neo_color_validate_sgr() {
    local value="${1-}"

    [[ "$value" =~ ^[0-9]+(\;[0-9]+)*$ ]]
}

termux_neo_color_theme_file() {
    local theme="${1-}"

    case "$theme" in
        neo)
            printf '%s/neo.theme' "$TERMUX_NEO_THEME_DIR"
            ;;
        matrix)
            printf '%s/matrix.theme' "$TERMUX_NEO_THEME_DIR"
            ;;
        *)
            return 1
            ;;
    esac
}

termux_neo_color_load_theme() {
    local theme="${1-}"
    local theme_file=""
    local TERMUX_NEO_THEME_NAME=""
    local TERMUX_NEO_THEME_BORDER=""
    local TERMUX_NEO_THEME_TITLE=""
    local TERMUX_NEO_THEME_LABEL=""
    local TERMUX_NEO_THEME_VALUE=""
    local TERMUX_NEO_THEME_STATUS=""
    local TERMUX_NEO_THEME_PROMPT=""
    local value=""

    theme_file="$(termux_neo_color_theme_file "$theme")" || return 1

    [[ -f "$theme_file" && -r "$theme_file" ]] || return 1
    source "$theme_file" || return 1

    [[ "$TERMUX_NEO_THEME_NAME" == "$theme" ]] || return 1

    for value in \
        "$TERMUX_NEO_THEME_BORDER" \
        "$TERMUX_NEO_THEME_TITLE" \
        "$TERMUX_NEO_THEME_LABEL" \
        "$TERMUX_NEO_THEME_VALUE" \
        "$TERMUX_NEO_THEME_STATUS" \
        "$TERMUX_NEO_THEME_PROMPT"
    do
        termux_neo_color_validate_sgr "$value" || return 1
    done

    TERMUX_NEO_COLOR_ACTIVE_THEME="$TERMUX_NEO_THEME_NAME"
    TERMUX_NEO_COLOR_BORDER="$TERMUX_NEO_THEME_BORDER"
    TERMUX_NEO_COLOR_TITLE="$TERMUX_NEO_THEME_TITLE"
    TERMUX_NEO_COLOR_LABEL="$TERMUX_NEO_THEME_LABEL"
    TERMUX_NEO_COLOR_VALUE="$TERMUX_NEO_THEME_VALUE"
    TERMUX_NEO_COLOR_STATUS="$TERMUX_NEO_THEME_STATUS"
    TERMUX_NEO_COLOR_PROMPT="$TERMUX_NEO_THEME_PROMPT"
}

termux_neo_color_terminal_supported() {
    local color_count=""

    [[ -t 1 ]] || return 1
    [[ -n "${TERM-}" && "${TERM-}" != "dumb" ]] || return 1
    command -v tput >/dev/null 2>&1 || return 1

    color_count="$(tput colors 2>/dev/null || printf '0')"
    [[ "$color_count" =~ ^[0-9]+$ ]] || return 1
    (( color_count >= 8 ))
}

termux_neo_color_configure() {
    local theme="${1-}"
    local color_mode="${2-}"

    termux_neo_color_reset
    termux_neo_color_load_theme "$theme" || {
        termux_neo_color_reset
        return 1
    }

    case "$color_mode" in
        never)
            TERMUX_NEO_COLOR_ENABLED=0
            ;;
        always)
            # An explicit application setting overrides the ambient NO_COLOR
            # default, as recommended by the convention.
            TERMUX_NEO_COLOR_ENABLED=1
            ;;
        auto)
            if [[ -n "${NO_COLOR-}" ]]; then
                TERMUX_NEO_COLOR_ENABLED=0
            elif termux_neo_color_terminal_supported; then
                TERMUX_NEO_COLOR_ENABLED=1
            else
                TERMUX_NEO_COLOR_ENABLED=0
            fi
            ;;
        *)
            termux_neo_color_reset
            return 1
            ;;
    esac
}

termux_neo_color_code_for_role() {
    local role="${1-}"

    case "$role" in
        border) printf '%s' "$TERMUX_NEO_COLOR_BORDER" ;;
        title) printf '%s' "$TERMUX_NEO_COLOR_TITLE" ;;
        label) printf '%s' "$TERMUX_NEO_COLOR_LABEL" ;;
        value) printf '%s' "$TERMUX_NEO_COLOR_VALUE" ;;
        status) printf '%s' "$TERMUX_NEO_COLOR_STATUS" ;;
        prompt) printf '%s' "$TERMUX_NEO_COLOR_PROMPT" ;;
        *) return 1 ;;
    esac
}

termux_neo_color_print() {
    local role="${1-}"
    local value="${2-}"
    local code=""

    code="$(termux_neo_color_code_for_role "$role")" || return 1

    if (( TERMUX_NEO_COLOR_ENABLED == 1 )); then
        printf '\e[%sm%s%s' "$code" "$value" "$TERMUX_NEO_COLOR_RESET"
    else
        printf '%s' "$value"
    fi
}
