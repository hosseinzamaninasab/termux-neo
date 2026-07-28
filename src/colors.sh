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
    local raw_line=""
    local key=""
    local value=""
    local parsed_name=""
    local parsed_border=""
    local parsed_title=""
    local parsed_label=""
    local parsed_value=""
    local parsed_status=""
    local parsed_prompt=""
    local name_seen=0
    local border_seen=0
    local title_seen=0
    local label_seen=0
    local value_seen=0
    local status_seen=0
    local prompt_seen=0

    theme_file="$(termux_neo_color_theme_file "$theme")" || return 1

    [[ -f "$theme_file" && ! -L "$theme_file" && -r "$theme_file" ]] ||
        return 1

    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        [[ "$raw_line" != *$'\r'* ]] || return 1
        [[ "$raw_line" != *$'\t'* ]] || return 1
        [[ ! "$raw_line" =~ [[:cntrl:]] ]] || return 1
        [[ -n "$raw_line" ]] || continue
        [[ "${raw_line:0:1}" != "#" ]] || continue
        [[ "$raw_line" == *=* ]] || return 1

        key="${raw_line%%=*}"
        value="${raw_line#*=}"
        (( ${#value} >= 2 )) || return 1
        [[ "${value:0:1}" == '"' && "${value: -1}" == '"' ]] ||
            return 1
        value="${value:1:${#value}-2}"
        [[ "$value" != *'"'* ]] || return 1

        case "$key" in
            TERMUX_NEO_THEME_NAME)
                (( name_seen == 0 )) || return 1
                parsed_name="$value"
                name_seen=1
                ;;
            TERMUX_NEO_THEME_BORDER)
                (( border_seen == 0 )) || return 1
                parsed_border="$value"
                border_seen=1
                ;;
            TERMUX_NEO_THEME_TITLE)
                (( title_seen == 0 )) || return 1
                parsed_title="$value"
                title_seen=1
                ;;
            TERMUX_NEO_THEME_LABEL)
                (( label_seen == 0 )) || return 1
                parsed_label="$value"
                label_seen=1
                ;;
            TERMUX_NEO_THEME_VALUE)
                (( value_seen == 0 )) || return 1
                parsed_value="$value"
                value_seen=1
                ;;
            TERMUX_NEO_THEME_STATUS)
                (( status_seen == 0 )) || return 1
                parsed_status="$value"
                status_seen=1
                ;;
            TERMUX_NEO_THEME_PROMPT)
                (( prompt_seen == 0 )) || return 1
                parsed_prompt="$value"
                prompt_seen=1
                ;;
            *)
                return 1
                ;;
        esac
    done < "$theme_file"

    (( name_seen == 1 && border_seen == 1 && title_seen == 1 &&
       label_seen == 1 && value_seen == 1 && status_seen == 1 &&
       prompt_seen == 1 )) || return 1
    [[ "$parsed_name" == "$theme" ]] || return 1

    for value in \
        "$parsed_border" \
        "$parsed_title" \
        "$parsed_label" \
        "$parsed_value" \
        "$parsed_status" \
        "$parsed_prompt"
    do
        termux_neo_color_validate_sgr "$value" || return 1
    done

    TERMUX_NEO_COLOR_ACTIVE_THEME="$parsed_name"
    TERMUX_NEO_COLOR_BORDER="$parsed_border"
    TERMUX_NEO_COLOR_TITLE="$parsed_title"
    TERMUX_NEO_COLOR_LABEL="$parsed_label"
    TERMUX_NEO_COLOR_VALUE="$parsed_value"
    TERMUX_NEO_COLOR_STATUS="$parsed_status"
    TERMUX_NEO_COLOR_PROMPT="$parsed_prompt"
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
