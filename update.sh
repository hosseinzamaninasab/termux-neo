#!/data/data/com.termux/files/usr/bin/bash

set -Eeu -o pipefail

# ==========================================================
# Termux Neo - Safe Update and Configuration Migration
# ==========================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$SCRIPT_DIR"

UPDATE_HOME="${HOME-}"
UPDATE_PREFIX="${PREFIX-}"
LIB_PARENT="${UPDATE_PREFIX}/lib"
BIN_PARENT="${UPDATE_PREFIX}/bin"
RUNTIME_ROOT="${LIB_PARENT}/termux-neo"
COMMAND_PATH="${BIN_PARENT}/termux-neo"
CONFIG_DIR="${UPDATE_HOME}/.config/termux-neo"
CONFIG_PATH="${CONFIG_DIR}/settings.conf"
REPORT_CACHE_DIR="${UPDATE_HOME}/.cache"
REPORT_PRODUCT_DIR="${REPORT_CACHE_DIR}/termux-neo"
REPORT_DIR="${REPORT_PRODUCT_DIR}/update-reports"
UPDATE_REPORT_PATH="${REPORT_DIR}/update-report.txt"

FORCE_DOWNGRADE=0
REPLACE_RUNTIME=0
CONFIG_MIGRATION=0
UPDATE_COMMITTED=0
ROLLBACK_ARMED=0
ROLLBACK_FAILED=0
REPORT_READY=0
REPORT_TEE_PID=""
REPORT_ORIGINAL_STDOUT_FD=""
REPORT_ORIGINAL_STDERR_FD=""

OLD_RUNTIME_MOVED=0
NEW_RUNTIME_INSTALLED=0
OLD_COMMAND_MOVED=0
NEW_COMMAND_INSTALLED=0
OLD_CONFIG_MOVED=0
NEW_CONFIG_INSTALLED=0

CURRENT_VERSION=""
TARGET_VERSION=""
VERSION_RELATION=""
CONFIG_SOURCE_SCHEMA=""

STAGE_CONTAINER=""
STAGE_RUNTIME=""
STAGE_LAUNCHER=""
STAGE_CONFIG=""
RUNTIME_BACKUP=""
COMMAND_BACKUP=""
CONFIG_BACKUP=""

termux_neo_update_error() {
    printf 'termux-neo updater: %s\n' "${1-update failed}" >&2
}

termux_neo_update_fail() {
    termux_neo_update_error "${1-update failed}"
    exit 1
}

termux_neo_update_path_is_safe() {
    local value="${1-}"

    [[ "$value" == /* ]] || return 1
    [[ "$value" != "/" ]] || return 1
    [[ "$value" != *"//"* ]] || return 1
    [[ "$value" != *"/./"* && "$value" != */. ]] || return 1
    [[ "$value" != *"/../"* && "$value" != */.. ]] || return 1
    [[ ! "$value" =~ [[:cntrl:]] ]]
}

termux_neo_update_require_tools() {
    local command_name=""

    for command_name in \
        bash chmod cp dirname find mkdir mktemp mv rm rmdir stat tee
    do
        command -v "$command_name" >/dev/null 2>&1 || {
            termux_neo_update_error \
                "required command is unavailable: $command_name"
            return 1
        }
    done
}

termux_neo_update_parse_arguments() {
    if (( $# == 0 )); then
        return 0
    fi

    if (( $# == 1 )) && [[ "$1" == "--force-downgrade" ]]; then
        FORCE_DOWNGRADE=1
        return 0
    fi

    termux_neo_update_error \
        "usage: bash update.sh [--force-downgrade]"
    return 1
}

termux_neo_update_validate_environment() {
    local expected_prefix=""

    termux_neo_update_path_is_safe "$UPDATE_HOME" || {
        termux_neo_update_error "HOME is not a safe absolute Termux path"
        return 1
    }
    termux_neo_update_path_is_safe "$UPDATE_PREFIX" || {
        termux_neo_update_error "PREFIX is not a safe absolute Termux path"
        return 1
    }

    expected_prefix="$(dirname "$UPDATE_HOME")/usr" || return 1
    [[ "$UPDATE_PREFIX" == "$expected_prefix" ]] || {
        termux_neo_update_error \
            "PREFIX is not the Termux-owned sibling of HOME"
        return 1
    }

    [[ -d "$UPDATE_HOME" && ! -L "$UPDATE_HOME" ]] || {
        termux_neo_update_error "HOME is not a regular Termux directory"
        return 1
    }
    [[ -d "$UPDATE_PREFIX" && ! -L "$UPDATE_PREFIX" ]] || {
        termux_neo_update_error "PREFIX is not a regular Termux directory"
        return 1
    }
    [[ -x "$UPDATE_PREFIX/bin/bash" ]] || {
        termux_neo_update_error \
            "Termux Bash is unavailable at PREFIX/bin/bash"
        return 1
    }
    [[ "$SOURCE_ROOT" != "$RUNTIME_ROOT" &&
       "$SOURCE_ROOT" != "$RUNTIME_ROOT/"* ]] || {
        termux_neo_update_error \
            "run the updater from a separate target source tree"
        return 1
    }
}

termux_neo_update_ensure_directory() {
    local directory="${1-}"
    local parent=""

    if [[ -e "$directory" || -L "$directory" ]]; then
        [[ -d "$directory" && ! -L "$directory" ]] || {
            termux_neo_update_error \
                "report parent is not a regular directory: $directory"
            return 1
        }
        return 0
    fi

    parent="$(dirname "$directory")" || return 1
    [[ -d "$parent" && ! -L "$parent" ]] || {
        termux_neo_update_error \
            "report parent is unavailable: $parent"
        return 1
    }
    mkdir "$directory"
}

termux_neo_update_open_report() {
    local previous_umask=""

    termux_neo_update_ensure_directory "$REPORT_CACHE_DIR" || return 1
    termux_neo_update_ensure_directory "$REPORT_PRODUCT_DIR" || return 1
    termux_neo_update_ensure_directory "$REPORT_DIR" || return 1

    previous_umask="$(umask)"
    umask 077

    if [[ -e "$UPDATE_REPORT_PATH" || -L "$UPDATE_REPORT_PATH" ]]; then
        [[ -f "$UPDATE_REPORT_PATH" && ! -L "$UPDATE_REPORT_PATH" ]] || {
            umask "$previous_umask"
            termux_neo_update_error \
                "update report path is not a regular file"
            return 1
        }
        chmod 600 -- "$UPDATE_REPORT_PATH" || {
            umask "$previous_umask"
            return 1
        }
    fi

    : > "$UPDATE_REPORT_PATH" || {
        umask "$previous_umask"
        return 1
    }
    chmod 600 -- "$UPDATE_REPORT_PATH" || {
        umask "$previous_umask"
        return 1
    }
    umask "$previous_umask"

    exec {REPORT_ORIGINAL_STDOUT_FD}>&1
    exec {REPORT_ORIGINAL_STDERR_FD}>&2
    exec > >(tee -- "$UPDATE_REPORT_PATH" >&"$REPORT_ORIGINAL_STDOUT_FD") 2>&1
    REPORT_TEE_PID=$!
    REPORT_READY=1

    printf '%s\n' \
        '===== Termux Neo safe update =====' \
        "target source: $SOURCE_ROOT"
}

termux_neo_update_close_report() {
    local tee_status=0

    (( REPORT_READY == 1 )) || return 0

    exec 1>&"$REPORT_ORIGINAL_STDOUT_FD" 2>&"$REPORT_ORIGINAL_STDERR_FD"
    wait "$REPORT_TEE_PID" || tee_status=$?
    exec {REPORT_ORIGINAL_STDOUT_FD}>&-
    exec {REPORT_ORIGINAL_STDERR_FD}>&-
    REPORT_READY=0

    (( tee_status == 0 ))
}

termux_neo_update_numeric_identifier_is_valid() {
    local value="${1-}"

    [[ "$value" =~ ^[0-9]+$ ]] || return 1
    [[ "$value" == "0" || "${value:0:1}" != "0" ]]
}

termux_neo_update_version_split() {
    local version="${1-}"
    local prefix="${2-}"
    local major=""
    local minor=""
    local patch=""
    local prerelease=""
    local identifier=""
    local identifiers=()

    [[ "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-([0-9A-Za-z.-]+))?$ ]] ||
        return 1

    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    patch="${BASH_REMATCH[3]}"
    prerelease="${BASH_REMATCH[5]-}"

    termux_neo_update_numeric_identifier_is_valid "$major" || return 1
    termux_neo_update_numeric_identifier_is_valid "$minor" || return 1
    termux_neo_update_numeric_identifier_is_valid "$patch" || return 1

    if [[ -n "$prerelease" ]]; then
        IFS='.' read -r -a identifiers <<< "$prerelease"
        (( ${#identifiers[@]} > 0 )) || return 1
        for identifier in "${identifiers[@]}"; do
            [[ -n "$identifier" &&
               "$identifier" =~ ^[0-9A-Za-z-]+$ ]] || return 1
            if [[ "$identifier" =~ ^[0-9]+$ ]]; then
                termux_neo_update_numeric_identifier_is_valid \
                    "$identifier" || return 1
            fi
        done
    fi

    printf -v "${prefix}_major" '%s' "$major"
    printf -v "${prefix}_minor" '%s' "$minor"
    printf -v "${prefix}_patch" '%s' "$patch"
    printf -v "${prefix}_prerelease" '%s' "$prerelease"
}

termux_neo_update_compare_numeric_text() {
    local left="${1-}"
    local right="${2-}"

    if (( ${#left} < ${#right} )); then
        printf '%s' '-1'
    elif (( ${#left} > ${#right} )); then
        printf '%s' '1'
    elif [[ "$left" == "$right" ]]; then
        printf '%s' '0'
    elif [[ "$left" < "$right" ]]; then
        printf '%s' '-1'
    else
        printf '%s' '1'
    fi
}

termux_neo_update_compare_versions() {
    local left="${1-}"
    local right="${2-}"
    local left_major=""
    local left_minor=""
    local left_patch=""
    local left_prerelease=""
    local right_major=""
    local right_minor=""
    local right_patch=""
    local right_prerelease=""
    local left_parts=()
    local right_parts=()
    local left_part=""
    local right_part=""
    local result=""
    local index=0
    local maximum=0

    termux_neo_update_version_split "$left" left || return 1
    termux_neo_update_version_split "$right" right || return 1

    result="$(
        termux_neo_update_compare_numeric_text "$left_major" "$right_major"
    )"
    [[ "$result" == "0" ]] || {
        printf '%s' "$result"
        return 0
    }
    result="$(
        termux_neo_update_compare_numeric_text "$left_minor" "$right_minor"
    )"
    [[ "$result" == "0" ]] || {
        printf '%s' "$result"
        return 0
    }
    result="$(
        termux_neo_update_compare_numeric_text "$left_patch" "$right_patch"
    )"
    [[ "$result" == "0" ]] || {
        printf '%s' "$result"
        return 0
    }

    if [[ -z "$left_prerelease" && -z "$right_prerelease" ]]; then
        printf '%s' '0'
        return 0
    elif [[ -z "$left_prerelease" ]]; then
        printf '%s' '1'
        return 0
    elif [[ -z "$right_prerelease" ]]; then
        printf '%s' '-1'
        return 0
    fi

    IFS='.' read -r -a left_parts <<< "$left_prerelease"
    IFS='.' read -r -a right_parts <<< "$right_prerelease"
    maximum=${#left_parts[@]}
    if (( ${#right_parts[@]} > maximum )); then
        maximum=${#right_parts[@]}
    fi

    for (( index = 0; index < maximum; index += 1 )); do
        if (( index >= ${#left_parts[@]} )); then
            printf '%s' '-1'
            return 0
        elif (( index >= ${#right_parts[@]} )); then
            printf '%s' '1'
            return 0
        fi

        left_part="${left_parts[index]}"
        right_part="${right_parts[index]}"
        [[ "$left_part" == "$right_part" ]] && continue

        if [[ "$left_part" =~ ^[0-9]+$ &&
              "$right_part" =~ ^[0-9]+$ ]]; then
            termux_neo_update_compare_numeric_text \
                "$left_part" "$right_part"
        elif [[ "$left_part" =~ ^[0-9]+$ ]]; then
            printf '%s' '-1'
        elif [[ "$right_part" =~ ^[0-9]+$ ]]; then
            printf '%s' '1'
        elif [[ "$left_part" < "$right_part" ]]; then
            printf '%s' '-1'
        else
            printf '%s' '1'
        fi
        return 0
    done

    printf '%s' '0'
}

termux_neo_update_validate_source() {
    local required_path=""
    local shell_file=""
    local target_version=""
    local unexpected_link=""

    for required_path in \
        "$SOURCE_ROOT/VERSION" \
        "$SOURCE_ROOT/LICENSE" \
        "$SOURCE_ROOT/README.md" \
        "$SOURCE_ROOT/install.sh" \
        "$SOURCE_ROOT/update.sh" \
        "$SOURCE_ROOT/uninstall.sh" \
        "$SOURCE_ROOT/bin/termux-neo" \
        "$SOURCE_ROOT/config/settings.example.conf" \
        "$SOURCE_ROOT/docs/cli.md" \
        "$SOURCE_ROOT/docs/installation.md" \
        "$SOURCE_ROOT/docs/release-artifacts.md" \
        "$SOURCE_ROOT/docs/security.md" \
        "$SOURCE_ROOT/docs/settings-schema-v1.md" \
        "$SOURCE_ROOT/docs/update.md" \
        "$SOURCE_ROOT/docs/uninstallation.md" \
        "$SOURCE_ROOT/src/main.sh" \
        "$SOURCE_ROOT/src/config.sh" \
        "$SOURCE_ROOT/src/release.sh" \
        "$SOURCE_ROOT/src/startup_integration.sh"
    do
        [[ -f "$required_path" && ! -L "$required_path" &&
           -r "$required_path" ]] || {
            termux_neo_update_error \
                "required target source file is unavailable: $required_path"
            return 1
        }
    done

    unexpected_link="$(
        find \
            "$SOURCE_ROOT/VERSION" \
            "$SOURCE_ROOT/LICENSE" \
            "$SOURCE_ROOT/README.md" \
            "$SOURCE_ROOT/install.sh" \
            "$SOURCE_ROOT/update.sh" \
            "$SOURCE_ROOT/uninstall.sh" \
            "$SOURCE_ROOT/bin" \
            "$SOURCE_ROOT/config/settings.example.conf" \
            "$SOURCE_ROOT/docs/cli.md" \
            "$SOURCE_ROOT/docs/installation.md" \
            "$SOURCE_ROOT/docs/release-artifacts.md" \
            "$SOURCE_ROOT/docs/security.md" \
            "$SOURCE_ROOT/docs/settings-schema-v1.md" \
            "$SOURCE_ROOT/docs/update.md" \
            "$SOURCE_ROOT/docs/uninstallation.md" \
            "$SOURCE_ROOT/src" \
            -type l -print -quit
    )" || return 1
    [[ -z "$unexpected_link" ]] || {
        termux_neo_update_error \
            "target source contains a symbolic link: $unexpected_link"
        return 1
    }

    IFS= read -r target_version < "$SOURCE_ROOT/VERSION" || return 1
    termux_neo_update_version_split "$target_version" target_check || {
        termux_neo_update_error "target VERSION is not valid SemVer"
        return 1
    }

    bash -n "$SOURCE_ROOT/src/release.sh" || return 1
    source "$SOURCE_ROOT/src/release.sh"
    termux_neo_release_manifest_verify \
        "$SOURCE_ROOT" termux_neo_update_error || return 1

    while IFS= read -r -d '' shell_file; do
        bash -n "$shell_file" || {
            termux_neo_update_error \
                "target shell syntax check failed: $shell_file"
            return 1
        }
    done < <(
        find "$SOURCE_ROOT/src" "$SOURCE_ROOT/bin" -type f \
            \( -name '*.sh' -o -name 'termux-neo' \) -print0
    )
    bash -n "$SOURCE_ROOT/install.sh" "$SOURCE_ROOT/update.sh" \
        "$SOURCE_ROOT/uninstall.sh" || {
        termux_neo_update_error "target lifecycle shell syntax check failed"
        return 1
    }

    (
        cd "$SOURCE_ROOT"
        source src/config.sh
        termux_neo_config_load config/settings.example.conf
    ) || {
        termux_neo_update_error "target settings example is invalid"
        return 1
    }

    TARGET_VERSION="$target_version"
}

termux_neo_update_manifest_is_owned() {
    local manifest="$RUNTIME_ROOT/INSTALL_MANIFEST"
    local line=""
    local key=""
    local value=""
    local format=""
    local product=""
    local version=""
    local runtime_root=""
    local command_path=""
    local config_path=""
    local format_seen=0
    local product_seen=0
    local version_seen=0
    local runtime_seen=0
    local command_seen=0
    local config_seen=0

    [[ -f "$manifest" && ! -L "$manifest" && -r "$manifest" ]] ||
        return 1

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" == *=* ]] || return 1
        key="${line%%=*}"
        value="${line#*=}"
        case "$key" in
            format)
                (( format_seen == 0 )) || return 1
                format="$value"
                format_seen=1
                ;;
            product)
                (( product_seen == 0 )) || return 1
                product="$value"
                product_seen=1
                ;;
            version)
                (( version_seen == 0 )) || return 1
                version="$value"
                version_seen=1
                ;;
            runtime_root)
                (( runtime_seen == 0 )) || return 1
                runtime_root="$value"
                runtime_seen=1
                ;;
            command_path)
                (( command_seen == 0 )) || return 1
                command_path="$value"
                command_seen=1
                ;;
            config_path)
                (( config_seen == 0 )) || return 1
                config_path="$value"
                config_seen=1
                ;;
            *)
                return 1
                ;;
        esac
    done < "$manifest"

    (( format_seen == 1 && product_seen == 1 && version_seen == 1 &&
       runtime_seen == 1 && command_seen == 1 && config_seen == 1 )) ||
        return 1
    [[ "$format" == "1" &&
       "$product" == "termux-neo" &&
       "$runtime_root" == "$RUNTIME_ROOT" &&
       "$command_path" == "$COMMAND_PATH" &&
       "$config_path" == "$CONFIG_PATH" ]] || return 1

    termux_neo_update_version_split "$version" manifest_check || return 1
    CURRENT_VERSION="$version"
}

termux_neo_update_command_is_owned() {
    local bash_command_quoted=""
    local runtime_command_quoted=""
    local command_path_quoted=""
    local -a launcher_lines=()

    [[ -f "$COMMAND_PATH" && ! -L "$COMMAND_PATH" &&
       -r "$COMMAND_PATH" && -x "$COMMAND_PATH" ]] || return 1
    mapfile -t launcher_lines < "$COMMAND_PATH" || return 1

    printf -v bash_command_quoted '%q' "$UPDATE_PREFIX/bin/bash"
    printf -v runtime_command_quoted '%q' "$RUNTIME_ROOT/src/main.sh"
    printf -v command_path_quoted '%q' "$COMMAND_PATH"

    (( ${#launcher_lines[@]} == 7 )) || return 1
    [[ "${launcher_lines[0]}" == "#!$UPDATE_PREFIX/bin/bash" &&
       "${launcher_lines[1]}" == '# Termux Neo installed launcher v1' &&
       "${launcher_lines[2]}" == 'set -e' &&
       "${launcher_lines[3]}" == \
           'TERMUX_NEO_CONFIG_PATH="${TERMUX_NEO_CONFIG_PATH:-$HOME/.config/termux-neo/settings.conf}"' &&
       "${launcher_lines[4]}" == \
           "TERMUX_NEO_COMMAND_PATH=$command_path_quoted" &&
       "${launcher_lines[5]}" == \
           'export TERMUX_NEO_CONFIG_PATH TERMUX_NEO_COMMAND_PATH' &&
       "${launcher_lines[6]}" == \
           "exec $bash_command_quoted $runtime_command_quoted \"\$@\"" ]]
}

termux_neo_update_validate_installed() {
    local runtime_version=""

    [[ -d "$LIB_PARENT" && ! -L "$LIB_PARENT" && -w "$LIB_PARENT" ]] || {
        termux_neo_update_error \
            "installed runtime parent is not a writable regular directory"
        return 1
    }
    [[ -d "$BIN_PARENT" && ! -L "$BIN_PARENT" && -w "$BIN_PARENT" ]] || {
        termux_neo_update_error \
            "installed command parent is not a writable regular directory"
        return 1
    }
    [[ -d "$RUNTIME_ROOT" && ! -L "$RUNTIME_ROOT" ]] || {
        termux_neo_update_error \
            "owned installation is unavailable; run install.sh first"
        return 1
    }
    termux_neo_update_manifest_is_owned || {
        termux_neo_update_error \
            "installed runtime ownership manifest is invalid"
        return 1
    }
    termux_neo_update_command_is_owned || {
        termux_neo_update_error "installed command ownership marker is invalid"
        return 1
    }

    [[ -f "$RUNTIME_ROOT/VERSION" && ! -L "$RUNTIME_ROOT/VERSION" &&
       -r "$RUNTIME_ROOT/VERSION" ]] ||
        return 1
    IFS= read -r runtime_version < "$RUNTIME_ROOT/VERSION" || return 1
    [[ "$runtime_version" == "$CURRENT_VERSION" ]] || {
        termux_neo_update_error \
            "installed runtime and manifest versions disagree"
        return 1
    }

    if [[ -e "$CONFIG_PATH" || -L "$CONFIG_PATH" ]]; then
        [[ -f "$CONFIG_PATH" && ! -L "$CONFIG_PATH" &&
           -r "$CONFIG_PATH" ]] || {
            termux_neo_update_error \
                "installed configuration is not a readable regular file"
            return 1
        }
        [[ -d "$CONFIG_DIR" && ! -L "$CONFIG_DIR" &&
           -w "$CONFIG_DIR" ]] || {
            termux_neo_update_error \
                "configuration directory is not writable"
            return 1
        }
    fi
}

termux_neo_update_determine_version_relation() {
    VERSION_RELATION="$(
        termux_neo_update_compare_versions "$CURRENT_VERSION" "$TARGET_VERSION"
    )" || {
        termux_neo_update_error \
            "current or target version cannot be compared"
        return 1
    }

    printf 'current version: %s\n' "$CURRENT_VERSION"
    printf 'target version: %s\n' "$TARGET_VERSION"

    case "$VERSION_RELATION" in
        -1)
            REPLACE_RUNTIME=1
            printf 'version relation: upgrade\n'
            ;;
        0)
            REPLACE_RUNTIME=0
            printf 'version relation: already current\n'
            ;;
        1)
            if (( FORCE_DOWNGRADE == 0 )); then
                termux_neo_update_error \
                    "downgrade refused; use --force-downgrade explicitly"
                return 1
            fi
            REPLACE_RUNTIME=1
            printf 'version relation: forced downgrade\n'
            ;;
        *)
            return 1
            ;;
    esac
}

termux_neo_update_prepare_config_migration() {
    local config_mode=""

    if [[ ! -e "$CONFIG_PATH" && ! -L "$CONFIG_PATH" ]]; then
        CONFIG_SOURCE_SCHEMA="absent"
        return 0
    fi

    source "$SOURCE_ROOT/src/config.sh" || return 1
    termux_neo_config_load "$CONFIG_PATH" || {
        termux_neo_update_error \
            "installed configuration is invalid or unsupported"
        return 1
    }
    CONFIG_SOURCE_SCHEMA="$TERMUX_NEO_CONFIG_SOURCE_SCHEMA_VERSION"

    if [[ "$CONFIG_SOURCE_SCHEMA" == \
          "$TERMUX_NEO_SETTINGS_SCHEMA_CURRENT" ]]; then
        return 0
    fi

    STAGE_CONFIG="$(
        mktemp "$CONFIG_DIR/.settings.conf.update.XXXXXX"
    )" || return 1
    termux_neo_config_write_current "$STAGE_CONFIG" || {
        termux_neo_update_error \
            "could not serialize migrated configuration"
        return 1
    }

    config_mode="$(stat -c '%a' "$CONFIG_PATH")" || return 1
    [[ "$config_mode" =~ ^[0-7]{3,4}$ ]] || return 1
    chmod "$config_mode" "$STAGE_CONFIG" || return 1

    termux_neo_config_load "$STAGE_CONFIG" || {
        termux_neo_update_error \
            "staged migrated configuration failed validation"
        return 1
    }
    [[ "$TERMUX_NEO_CONFIG_SOURCE_SCHEMA_VERSION" == \
       "$TERMUX_NEO_SETTINGS_SCHEMA_CURRENT" ]] || return 1

    CONFIG_MIGRATION=1
}

termux_neo_update_prepare_runtime() {
    local bash_command_quoted=""
    local runtime_command_quoted=""
    local command_path_quoted=""
    local version_output=""
    local shell_file=""

    (( REPLACE_RUNTIME == 1 )) || return 0

    STAGE_CONTAINER="$(
        mktemp -d "$LIB_PARENT/.termux-neo.update-stage.XXXXXX"
    )" || return 1
    STAGE_RUNTIME="$STAGE_CONTAINER/runtime"
    mkdir "$STAGE_RUNTIME" "$STAGE_RUNTIME/bin" \
        "$STAGE_RUNTIME/config" "$STAGE_RUNTIME/docs" || return 1

    cp -p "$SOURCE_ROOT/VERSION" "$SOURCE_ROOT/LICENSE" \
        "$SOURCE_ROOT/README.md" "$STAGE_RUNTIME/" || return 1
    cp -p "$SOURCE_ROOT/bin/termux-neo" "$STAGE_RUNTIME/bin/" || return 1
    cp -p "$SOURCE_ROOT/config/settings.example.conf" \
        "$STAGE_RUNTIME/config/" || return 1
    cp -p "$SOURCE_ROOT/docs/cli.md" "$SOURCE_ROOT/docs/installation.md" \
        "$SOURCE_ROOT/docs/release-artifacts.md" \
        "$SOURCE_ROOT/docs/security.md" \
        "$SOURCE_ROOT/docs/settings-schema-v1.md" \
        "$SOURCE_ROOT/docs/update.md" \
        "$SOURCE_ROOT/docs/uninstallation.md" \
        "$STAGE_RUNTIME/docs/" || return 1
    cp -pR "$SOURCE_ROOT/src" "$STAGE_RUNTIME/" || return 1

    printf '%s\n' \
        'format=1' \
        'product=termux-neo' \
        "version=$TARGET_VERSION" \
        "runtime_root=$RUNTIME_ROOT" \
        "command_path=$COMMAND_PATH" \
        "config_path=$CONFIG_PATH" > "$STAGE_RUNTIME/INSTALL_MANIFEST" ||
        return 1

    find "$STAGE_RUNTIME" -type d -exec chmod 755 {} + || return 1
    find "$STAGE_RUNTIME" -type f -exec chmod 644 {} + || return 1
    chmod 755 "$STAGE_RUNTIME/bin/termux-neo" \
        "$STAGE_RUNTIME"/src/*.sh \
        "$STAGE_RUNTIME"/src/modules/*.sh || return 1

    STAGE_LAUNCHER="$(
        mktemp "$BIN_PARENT/.termux-neo.update-launcher.XXXXXX"
    )" || return 1
    printf -v bash_command_quoted '%q' "$UPDATE_PREFIX/bin/bash"
    printf -v runtime_command_quoted '%q' "$RUNTIME_ROOT/src/main.sh"
    printf -v command_path_quoted '%q' "$COMMAND_PATH"
    printf '%s\n' \
        "#!$UPDATE_PREFIX/bin/bash" \
        '# Termux Neo installed launcher v1' \
        'set -e' \
        'TERMUX_NEO_CONFIG_PATH="${TERMUX_NEO_CONFIG_PATH:-$HOME/.config/termux-neo/settings.conf}"' \
        "TERMUX_NEO_COMMAND_PATH=$command_path_quoted" \
        'export TERMUX_NEO_CONFIG_PATH TERMUX_NEO_COMMAND_PATH' \
        "exec $bash_command_quoted $runtime_command_quoted \"\$@\"" \
        > "$STAGE_LAUNCHER" || return 1
    chmod 755 "$STAGE_LAUNCHER" || return 1

    while IFS= read -r -d '' shell_file; do
        bash -n "$shell_file" || return 1
    done < <(
        find "$STAGE_RUNTIME/src" "$STAGE_RUNTIME/bin" -type f \
            \( -name '*.sh' -o -name 'termux-neo' \) -print0
    )
    bash -n "$STAGE_LAUNCHER" || return 1

    version_output="$(
        TERMUX_NEO_CONFIG_PATH="$CONFIG_PATH" \
            bash "$STAGE_RUNTIME/src/main.sh" --version
    )" || return 1
    [[ "$version_output" == "termux-neo $TARGET_VERSION" ]] || return 1
}

termux_neo_update_prepare_backups() {
    if (( REPLACE_RUNTIME == 1 )); then
        RUNTIME_BACKUP="$(
            mktemp -d "$LIB_PARENT/.termux-neo.update-rollback.XXXXXX"
        )" || return 1
        COMMAND_BACKUP="$(
            mktemp -d "$BIN_PARENT/.termux-neo.update-rollback.XXXXXX"
        )" || return 1
    fi

    if (( CONFIG_MIGRATION == 1 )); then
        CONFIG_BACKUP="$(
            mktemp -d "$CONFIG_DIR/.termux-neo.update-rollback.XXXXXX"
        )" || return 1
    fi
}

termux_neo_update_swap() {
    if (( REPLACE_RUNTIME == 1 )); then
        mv -- "$RUNTIME_ROOT" "$RUNTIME_BACKUP/original" || return 1
        OLD_RUNTIME_MOVED=1
        mv -- "$STAGE_RUNTIME" "$RUNTIME_ROOT" || return 1
        NEW_RUNTIME_INSTALLED=1

        mv -- "$COMMAND_PATH" "$COMMAND_BACKUP/original" || return 1
        OLD_COMMAND_MOVED=1
        mv -- "$STAGE_LAUNCHER" "$COMMAND_PATH" || return 1
        NEW_COMMAND_INSTALLED=1
    fi

    if (( CONFIG_MIGRATION == 1 )); then
        mv -- "$CONFIG_PATH" "$CONFIG_BACKUP/original" || return 1
        OLD_CONFIG_MOVED=1
        mv -- "$STAGE_CONFIG" "$CONFIG_PATH" || return 1
        NEW_CONFIG_INSTALLED=1
    fi
}

termux_neo_update_smoke_test() {
    local version_output=""
    local config_output=""

    [[ -d "$RUNTIME_ROOT" && ! -L "$RUNTIME_ROOT" ]] || return 1
    [[ -x "$COMMAND_PATH" && -x "$RUNTIME_ROOT/bin/termux-neo" ]] ||
        return 1
    bash -n "$COMMAND_PATH" || return 1

    version_output="$(
        unset TERMUX_NEO_CONFIG_PATH TERMUX_NEO_COMMAND_PATH
        HOME="$UPDATE_HOME" "$COMMAND_PATH" --version
    )" || return 1
    [[ "$version_output" == "termux-neo $TARGET_VERSION" ]] || return 1

    config_output="$(
        unset TERMUX_NEO_CONFIG_PATH TERMUX_NEO_COMMAND_PATH
        HOME="$UPDATE_HOME" "$COMMAND_PATH" --config
    )" || return 1
    [[ "$config_output" == "$CONFIG_PATH" ]] || return 1

    if [[ -e "$CONFIG_PATH" ]]; then
        (
            source "$RUNTIME_ROOT/src/config.sh"
            termux_neo_config_load "$CONFIG_PATH"
        ) || return 1
    fi
}

termux_neo_update_rollback() {
    set +e

    if (( NEW_CONFIG_INSTALLED == 1 )); then
        if rm -f -- "$CONFIG_PATH"; then
            NEW_CONFIG_INSTALLED=0
        else
            ROLLBACK_FAILED=1
        fi
    fi
    if (( OLD_CONFIG_MOVED == 1 )); then
        if mv -- "$CONFIG_BACKUP/original" "$CONFIG_PATH"; then
            OLD_CONFIG_MOVED=0
        else
            ROLLBACK_FAILED=1
        fi
    fi

    if (( NEW_COMMAND_INSTALLED == 1 )); then
        if rm -f -- "$COMMAND_PATH"; then
            NEW_COMMAND_INSTALLED=0
        else
            ROLLBACK_FAILED=1
        fi
    fi
    if (( OLD_COMMAND_MOVED == 1 )); then
        if mv -- "$COMMAND_BACKUP/original" "$COMMAND_PATH"; then
            OLD_COMMAND_MOVED=0
        else
            ROLLBACK_FAILED=1
        fi
    fi

    if (( NEW_RUNTIME_INSTALLED == 1 )); then
        if rm -rf -- "$RUNTIME_ROOT"; then
            NEW_RUNTIME_INSTALLED=0
        else
            ROLLBACK_FAILED=1
        fi
    fi
    if (( OLD_RUNTIME_MOVED == 1 )); then
        if mv -- "$RUNTIME_BACKUP/original" "$RUNTIME_ROOT"; then
            OLD_RUNTIME_MOVED=0
        else
            ROLLBACK_FAILED=1
        fi
    fi

    if (( ROLLBACK_FAILED == 0 )); then
        termux_neo_update_error \
            "update rolled back; the previous state was restored"
    else
        termux_neo_update_error \
            "rollback could not be completed; rollback storage was preserved"
        [[ -z "$RUNTIME_BACKUP" ]] ||
            termux_neo_update_error \
                "runtime rollback storage: $RUNTIME_BACKUP"
        [[ -z "$COMMAND_BACKUP" ]] ||
            termux_neo_update_error \
                "command rollback storage: $COMMAND_BACKUP"
        [[ -z "$CONFIG_BACKUP" ]] ||
            termux_neo_update_error \
                "configuration rollback storage: $CONFIG_BACKUP"
    fi
}

termux_neo_update_cleanup() {
    set +e

    [[ -z "$STAGE_LAUNCHER" || ! -e "$STAGE_LAUNCHER" ]] ||
        rm -f -- "$STAGE_LAUNCHER"
    [[ -z "$STAGE_CONFIG" || ! -e "$STAGE_CONFIG" ]] ||
        rm -f -- "$STAGE_CONFIG"
    [[ -z "$STAGE_CONTAINER" || ! -e "$STAGE_CONTAINER" ]] ||
        rm -rf -- "$STAGE_CONTAINER"

    if (( ROLLBACK_FAILED == 0 || UPDATE_COMMITTED == 1 )); then
        [[ -z "$RUNTIME_BACKUP" || ! -e "$RUNTIME_BACKUP" ]] ||
            rm -rf -- "$RUNTIME_BACKUP"
        [[ -z "$COMMAND_BACKUP" || ! -e "$COMMAND_BACKUP" ]] ||
            rm -rf -- "$COMMAND_BACKUP"
        [[ -z "$CONFIG_BACKUP" || ! -e "$CONFIG_BACKUP" ]] ||
            rm -rf -- "$CONFIG_BACKUP"
    fi
}

termux_neo_update_report_success() {
    printf 'Termux Neo update complete\n'
    printf 'previous version: %s\n' "$CURRENT_VERSION"
    printf 'installed version: %s\n' "$TARGET_VERSION"

    if (( REPLACE_RUNTIME == 1 )); then
        printf 'changed: replaced %s\n' "$RUNTIME_ROOT"
        printf 'changed: replaced %s\n' "$COMMAND_PATH"
    else
        printf 'unchanged: %s\n' "$RUNTIME_ROOT"
        printf 'unchanged: %s\n' "$COMMAND_PATH"
    fi

    if (( CONFIG_MIGRATION == 1 )); then
        printf 'changed: migrated schema %s to %s at %s\n' \
            "$CONFIG_SOURCE_SCHEMA" \
            "$TERMUX_NEO_SETTINGS_SCHEMA_CURRENT" \
            "$CONFIG_PATH"
    elif [[ "$CONFIG_SOURCE_SCHEMA" == "absent" ]]; then
        printf 'unchanged: configuration remains absent at %s\n' "$CONFIG_PATH"
    else
        printf 'preserved: %s\n' "$CONFIG_PATH"
    fi
    printf 'startup integration: unchanged\n'
}

termux_neo_update_exit() {
    local status="${1-1}"
    local report_status=0

    trap - EXIT
    set +e
    if (( status != 0 && ROLLBACK_ARMED == 1 )); then
        termux_neo_update_rollback
    fi
    termux_neo_update_cleanup
    if (( REPORT_READY == 1 )); then
        printf 'update report: %s\n' "$UPDATE_REPORT_PATH"
        termux_neo_update_close_report || report_status=1
    fi
    if (( status == 0 && report_status != 0 )); then
        termux_neo_update_error "update report could not be completed"
        status=1
    fi
    exit "$status"
}

trap 'termux_neo_update_exit $?' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

termux_neo_update_require_tools || exit 1
termux_neo_update_parse_arguments "$@" || exit 1
termux_neo_update_validate_environment || exit 1
termux_neo_update_open_report || exit 1
termux_neo_update_validate_source || exit 1
termux_neo_update_validate_installed || exit 1
termux_neo_update_determine_version_relation || exit 1
termux_neo_update_prepare_config_migration ||
    termux_neo_update_fail "could not prepare configuration migration"
termux_neo_update_prepare_runtime ||
    termux_neo_update_fail "could not stage and verify the target executable"

if (( REPLACE_RUNTIME == 0 && CONFIG_MIGRATION == 0 )); then
    termux_neo_update_report_success
    UPDATE_COMMITTED=1
    exit 0
fi

termux_neo_update_prepare_backups ||
    termux_neo_update_fail "could not prepare rollback storage"
ROLLBACK_ARMED=1
termux_neo_update_swap ||
    termux_neo_update_fail "could not replace owned installation paths"
termux_neo_update_smoke_test ||
    termux_neo_update_fail "updated command failed its smoke test"

termux_neo_update_report_success
UPDATE_COMMITTED=1
ROLLBACK_ARMED=0
exit 0
