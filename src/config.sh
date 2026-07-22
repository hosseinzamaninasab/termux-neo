#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - Versioned Settings Boundary
# ==========================================================

TERMUX_NEO_SETTINGS_SCHEMA_CURRENT="1"
TERMUX_NEO_DISPLAY_USER_MAX_LENGTH="28"

TERMUX_NEO_DEFAULT_DISPLAY_USER=""
TERMUX_NEO_DEFAULT_THEME="neo"
TERMUX_NEO_DEFAULT_COLOR_MODE="auto"
TERMUX_NEO_DEFAULT_STARTUP_INTEGRATION="false"

TERMUX_NEO_CONFIG_SCHEMA_VERSION="$TERMUX_NEO_SETTINGS_SCHEMA_CURRENT"
TERMUX_NEO_CONFIG_DISPLAY_USER="$TERMUX_NEO_DEFAULT_DISPLAY_USER"
TERMUX_NEO_CONFIG_THEME="$TERMUX_NEO_DEFAULT_THEME"
TERMUX_NEO_CONFIG_COLOR_MODE="$TERMUX_NEO_DEFAULT_COLOR_MODE"
TERMUX_NEO_CONFIG_STARTUP_INTEGRATION="$TERMUX_NEO_DEFAULT_STARTUP_INTEGRATION"

termux_neo_config_reset() {
    TERMUX_NEO_CONFIG_SCHEMA_VERSION="$TERMUX_NEO_SETTINGS_SCHEMA_CURRENT"
    TERMUX_NEO_CONFIG_DISPLAY_USER="$TERMUX_NEO_DEFAULT_DISPLAY_USER"
    TERMUX_NEO_CONFIG_THEME="$TERMUX_NEO_DEFAULT_THEME"
    TERMUX_NEO_CONFIG_COLOR_MODE="$TERMUX_NEO_DEFAULT_COLOR_MODE"
    TERMUX_NEO_CONFIG_STARTUP_INTEGRATION="$TERMUX_NEO_DEFAULT_STARTUP_INTEGRATION"
}

termux_neo_config_trim() {
    local value="${1-}"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    printf '%s' "$value"
}

termux_neo_config_validate_display_user() {
    local value="${1-}"

    [[ -n "$value" ]] || return 1
    (( ${#value} <= TERMUX_NEO_DISPLAY_USER_MAX_LENGTH )) || return 1
    [[ "$value" =~ ^[[:alnum:]_.-]+$ ]] || return 1

    [[ "$value" != *$'\n'* ]] || return 1
    [[ "$value" != *$'\r'* ]] || return 1
    [[ "$value" != *$'\t'* ]] || return 1
    [[ "$value" != *$'\e'* ]] || return 1
    [[ "$value" != *"•"* ]] || return 1
}

termux_neo_config_validate_schema_version() {
    local value="${1-}"

    [[ "$value" == "$TERMUX_NEO_SETTINGS_SCHEMA_CURRENT" ]]
}

termux_neo_config_validate_theme() {
    local value="${1-}"

    [[ "$value" == "neo" || "$value" == "matrix" ]]
}

termux_neo_config_validate_color_mode() {
    local value="${1-}"

    [[ "$value" == "auto" ||
       "$value" == "always" ||
       "$value" == "never" ]]
}

termux_neo_config_validate_startup_integration() {
    local value="${1-}"

    [[ "$value" == "true" || "$value" == "false" ]]
}

termux_neo_config_migrate_schema() {
    local source_version="${1-}"

    case "$source_version" in
        0|1)
            printf '%s' "$TERMUX_NEO_SETTINGS_SCHEMA_CURRENT"
            ;;
        *)
            return 1
            ;;
    esac
}

termux_neo_config_resolve_display_user() {
    local override_value="${1-}"
    local system_value="${2-}"
    local value=""

    # This boundary owns the full precedence policy. Collectors only provide
    # raw candidates; renderers only consume the single resolved value.
    for value in \
        "$override_value" \
        "$TERMUX_NEO_CONFIG_DISPLAY_USER" \
        "$system_value"
    do
        if termux_neo_config_validate_display_user "$value"; then
            printf '%s' "$value"
            return 0
        fi
    done

    printf 'User'
}

termux_neo_config_apply_runtime_overrides() {
    local theme_override="${1-}"
    local color_mode_override="${2-}"
    local effective_theme="$TERMUX_NEO_CONFIG_THEME"
    local effective_color_mode="$TERMUX_NEO_CONFIG_COLOR_MODE"

    if [[ -n "$theme_override" ]]; then
        termux_neo_config_validate_theme "$theme_override" || return 1
        effective_theme="$theme_override"
    fi

    if [[ -n "$color_mode_override" ]]; then
        termux_neo_config_validate_color_mode "$color_mode_override" || return 1
        effective_color_mode="$color_mode_override"
    fi

    TERMUX_NEO_CONFIG_THEME="$effective_theme"
    TERMUX_NEO_CONFIG_COLOR_MODE="$effective_color_mode"
}

termux_neo_config_load() {
    local config_file="${1-}"
    local raw_line=""
    local line=""
    local key=""
    local value=""
    local parsed_display_user="$TERMUX_NEO_DEFAULT_DISPLAY_USER"
    local parsed_theme="$TERMUX_NEO_DEFAULT_THEME"
    local parsed_color_mode="$TERMUX_NEO_DEFAULT_COLOR_MODE"
    local parsed_startup_integration="$TERMUX_NEO_DEFAULT_STARTUP_INTEGRATION"
    local source_schema_version="0"
    local migrated_schema_version=""
    local schema_version_seen=0
    local display_user_seen=0
    local theme_seen=0
    local color_mode_seen=0
    local startup_integration_seen=0
    local versioned_key_seen=0

    termux_neo_config_reset

    [[ -n "$config_file" ]] || return 1
    [[ -e "$config_file" ]] || return 0
    [[ -f "$config_file" ]] || return 1
    [[ -r "$config_file" ]] || return 1

    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        [[ "$raw_line" != *$'\r'* ]] || return 1
        [[ "$raw_line" != *$'\t'* ]] || return 1
        [[ "$raw_line" != *$'\e'* ]] || return 1

        line="$(termux_neo_config_trim "$raw_line")"

        [[ -n "$line" ]] || continue
        [[ "${line:0:1}" != "#" ]] || continue
        [[ "$line" == *"="* ]] || return 1

        key="$(termux_neo_config_trim "${line%%=*}")"
        value="$(termux_neo_config_trim "${line#*=}")"

        case "$key" in
            schema_version)
                (( schema_version_seen == 0 )) || return 1
                termux_neo_config_validate_schema_version "$value" || return 1
                source_schema_version="$value"
                schema_version_seen=1
                ;;
            display_user)
                (( display_user_seen == 0 )) || return 1
                termux_neo_config_validate_display_user "$value" || return 1
                parsed_display_user="$value"
                display_user_seen=1
                ;;
            theme)
                (( theme_seen == 0 )) || return 1
                termux_neo_config_validate_theme "$value" || return 1
                parsed_theme="$value"
                theme_seen=1
                versioned_key_seen=1
                ;;
            color_mode)
                (( color_mode_seen == 0 )) || return 1
                termux_neo_config_validate_color_mode "$value" || return 1
                parsed_color_mode="$value"
                color_mode_seen=1
                versioned_key_seen=1
                ;;
            startup_integration)
                (( startup_integration_seen == 0 )) || return 1
                termux_neo_config_validate_startup_integration "$value" || return 1
                parsed_startup_integration="$value"
                startup_integration_seen=1
                versioned_key_seen=1
                ;;
            *)
                return 1
                ;;
        esac
    done < "$config_file"

    # A Task 14 file without schema_version is legacy schema 0. It may contain
    # only display_user; all v1-only keys require an explicit schema version.
    if (( schema_version_seen == 0 && versioned_key_seen != 0 )); then
        return 1
    fi

    migrated_schema_version="$(
        termux_neo_config_migrate_schema "$source_schema_version"
    )" || return 1

    # Commit parsed values only after the whole file and migration path pass.
    # Invalid files therefore leave the safe defaults installed by reset.
    TERMUX_NEO_CONFIG_SCHEMA_VERSION="$migrated_schema_version"
    TERMUX_NEO_CONFIG_DISPLAY_USER="$parsed_display_user"
    TERMUX_NEO_CONFIG_THEME="$parsed_theme"
    TERMUX_NEO_CONFIG_COLOR_MODE="$parsed_color_mode"
    TERMUX_NEO_CONFIG_STARTUP_INTEGRATION="$parsed_startup_integration"
}
