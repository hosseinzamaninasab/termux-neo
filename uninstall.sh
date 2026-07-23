#!/data/data/com.termux/files/usr/bin/bash

set -Eeu -o pipefail

# ==========================================================
# Termux Neo - Safe Uninstaller
# ==========================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$SCRIPT_DIR"

UNINSTALL_HOME="${HOME-}"
UNINSTALL_PREFIX="${PREFIX-}"
LIB_PARENT="${UNINSTALL_PREFIX}/lib"
BIN_PARENT="${UNINSTALL_PREFIX}/bin"
RUNTIME_ROOT="${LIB_PARENT}/termux-neo"
COMMAND_PATH="${BIN_PARENT}/termux-neo"
CONFIG_DIR="${UNINSTALL_HOME}/.config/termux-neo"
CONFIG_PATH="${CONFIG_DIR}/settings.conf"
REPORT_CACHE_DIR="${UNINSTALL_HOME}/.cache"
REPORT_PRODUCT_DIR="${REPORT_CACHE_DIR}/termux-neo"
REPORT_DIR="${REPORT_PRODUCT_DIR}/uninstall-reports"
UNINSTALL_REPORT_PATH="${REPORT_DIR}/uninstall-report.txt"

REMOVE_CONFIG=0
RUNTIME_PRESENT=0
COMMAND_PRESENT=0
CONFIG_PRESENT=0
OLD_RUNTIME_MOVED=0
OLD_COMMAND_MOVED=0
OLD_CONFIG_MOVED=0
STARTUP_CHANGED=0
UNINSTALL_COMMITTED=0
ROLLBACK_ARMED=0
ROLLBACK_FAILED=0
REPORT_READY=0
CLEANUP_FAILED=0

INSTALLED_VERSION="absent"
STARTUP_PATH=""
STARTUP_STATE="absent"
STARTUP_BACKUP="none (no edit)"
RUNTIME_BACKUP=""
COMMAND_BACKUP=""
CONFIG_BACKUP=""

termux_neo_uninstall_error() {
    printf 'termux-neo uninstaller: %s\n' "${1-uninstall failed}" >&2
}

termux_neo_uninstall_fail() {
    termux_neo_uninstall_error "${1-uninstall failed}"
    exit 1
}

termux_neo_uninstall_path_is_safe() {
    local value="${1-}"

    [[ "$value" == /* ]] || return 1
    [[ "$value" != "/" ]] || return 1
    [[ "$value" != *$'\n'* ]] || return 1
    [[ "$value" != *$'\r'* ]] || return 1
    [[ "$value" != *$'\t'* ]] || return 1
    [[ "$value" != *$'\e'* ]] || return 1
}

termux_neo_uninstall_require_tools() {
    local command_name=""

    for command_name in \
        awk bash chmod cmp cp dirname mkdir mktemp mv rm rmdir stat tee
    do
        command -v "$command_name" >/dev/null 2>&1 || {
            termux_neo_uninstall_error \
                "required command is unavailable: $command_name"
            return 1
        }
    done
}

termux_neo_uninstall_parse_arguments() {
    if (( $# == 0 )); then
        return 0
    fi

    if (( $# == 1 )) && [[ "$1" == "--remove-config" ]]; then
        REMOVE_CONFIG=1
        return 0
    fi

    termux_neo_uninstall_error \
        "usage: bash uninstall.sh [--remove-config]"
    return 1
}

termux_neo_uninstall_validate_environment() {
    local expected_prefix=""

    termux_neo_uninstall_path_is_safe "$UNINSTALL_HOME" || {
        termux_neo_uninstall_error \
            "HOME is not a safe absolute Termux path"
        return 1
    }
    termux_neo_uninstall_path_is_safe "$UNINSTALL_PREFIX" || {
        termux_neo_uninstall_error \
            "PREFIX is not a safe absolute Termux path"
        return 1
    }

    expected_prefix="$(dirname "$UNINSTALL_HOME")/usr" || return 1
    [[ "$UNINSTALL_PREFIX" == "$expected_prefix" ]] || {
        termux_neo_uninstall_error \
            "PREFIX is not the Termux-owned sibling of HOME"
        return 1
    }

    [[ -d "$UNINSTALL_HOME" && ! -L "$UNINSTALL_HOME" ]] || {
        termux_neo_uninstall_error \
            "HOME is not a regular Termux directory"
        return 1
    }
    [[ -d "$UNINSTALL_PREFIX" && ! -L "$UNINSTALL_PREFIX" ]] || {
        termux_neo_uninstall_error \
            "PREFIX is not a regular Termux directory"
        return 1
    }
    [[ -x "$UNINSTALL_PREFIX/bin/bash" ]] || {
        termux_neo_uninstall_error \
            "Termux Bash is unavailable at PREFIX/bin/bash"
        return 1
    }
}

termux_neo_uninstall_ensure_directory() {
    local directory="${1-}"
    local parent=""

    if [[ -e "$directory" || -L "$directory" ]]; then
        [[ -d "$directory" && ! -L "$directory" ]] || {
            termux_neo_uninstall_error \
                "report parent is not a regular directory: $directory"
            return 1
        }
        return 0
    fi

    parent="$(dirname "$directory")" || return 1
    [[ -d "$parent" && ! -L "$parent" ]] || {
        termux_neo_uninstall_error \
            "report parent is unavailable: $parent"
        return 1
    }
    mkdir "$directory"
}

termux_neo_uninstall_open_report() {
    termux_neo_uninstall_ensure_directory "$REPORT_CACHE_DIR" || return 1
    termux_neo_uninstall_ensure_directory "$REPORT_PRODUCT_DIR" || return 1
    termux_neo_uninstall_ensure_directory "$REPORT_DIR" || return 1

    if [[ -e "$UNINSTALL_REPORT_PATH" || -L "$UNINSTALL_REPORT_PATH" ]]; then
        [[ -f "$UNINSTALL_REPORT_PATH" &&
           ! -L "$UNINSTALL_REPORT_PATH" ]] || {
            termux_neo_uninstall_error \
                "uninstall report path is not a regular file"
            return 1
        }
    fi

    : > "$UNINSTALL_REPORT_PATH" || return 1
    chmod 600 "$UNINSTALL_REPORT_PATH" || return 1
    exec > >(tee "$UNINSTALL_REPORT_PATH") 2>&1
    REPORT_READY=1

    printf '%s\n' '===== Termux Neo safe uninstall ====='
}

termux_neo_uninstall_validate_source() {
    local required_path=""

    for required_path in \
        "$SOURCE_ROOT/src/release.sh" \
        "$SOURCE_ROOT/src/startup_integration.sh"
    do
        [[ -f "$required_path" && ! -L "$required_path" &&
           -r "$required_path" ]] || {
            termux_neo_uninstall_error \
                "required source file is unavailable: $required_path"
            return 1
        }
    done

    bash -n "$SOURCE_ROOT/src/release.sh" \
        "$SOURCE_ROOT/src/startup_integration.sh" || {
        termux_neo_uninstall_error \
            "lifecycle source failed syntax validation"
        return 1
    }

    source "$SOURCE_ROOT/src/release.sh" || return 1
    termux_neo_release_manifest_verify \
        "$SOURCE_ROOT" termux_neo_uninstall_error || return 1
    source "$SOURCE_ROOT/src/startup_integration.sh" || return 1
}

termux_neo_uninstall_manifest_is_owned() {
    local installed_root="${1-}"
    local manifest="$installed_root/INSTALL_MANIFEST"
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

    [[ -d "$installed_root" && ! -L "$installed_root" ]] || return 1
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
       "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ &&
       "$runtime_root" == "$RUNTIME_ROOT" &&
       "$command_path" == "$COMMAND_PATH" &&
       "$config_path" == "$CONFIG_PATH" ]] || return 1

    INSTALLED_VERSION="$version"
}

termux_neo_uninstall_command_is_owned() {
    local command_file="${1-}"
    local first_line=""
    local second_line=""

    [[ -f "$command_file" && ! -L "$command_file" &&
       -r "$command_file" && -x "$command_file" ]] || return 1
    {
        IFS= read -r first_line
        IFS= read -r second_line
    } < "$command_file" || return 1

    [[ "$first_line" == "#!$UNINSTALL_PREFIX/bin/bash" &&
       "$second_line" == '# Termux Neo installed launcher v1' ]]
}

termux_neo_uninstall_validate_installed_targets() {
    if [[ -e "$RUNTIME_ROOT" || -L "$RUNTIME_ROOT" ]]; then
        termux_neo_uninstall_manifest_is_owned "$RUNTIME_ROOT" || {
            termux_neo_uninstall_error \
                "refusing to remove an unowned runtime path: $RUNTIME_ROOT"
            return 1
        }
        [[ -d "$LIB_PARENT" && ! -L "$LIB_PARENT" &&
           -w "$LIB_PARENT" ]] || return 1
        RUNTIME_PRESENT=1
    fi

    if [[ -e "$COMMAND_PATH" || -L "$COMMAND_PATH" ]]; then
        termux_neo_uninstall_command_is_owned "$COMMAND_PATH" || {
            termux_neo_uninstall_error \
                "refusing to remove an unowned command path: $COMMAND_PATH"
            return 1
        }
        [[ -d "$BIN_PARENT" && ! -L "$BIN_PARENT" &&
           -w "$BIN_PARENT" ]] || return 1
        COMMAND_PRESENT=1
    fi

    if (( REMOVE_CONFIG == 1 )) &&
       [[ -e "$CONFIG_PATH" || -L "$CONFIG_PATH" ]]; then
        [[ -f "$CONFIG_PATH" && ! -L "$CONFIG_PATH" &&
           -r "$CONFIG_PATH" ]] || {
            termux_neo_uninstall_error \
                "refusing to remove a non-regular configuration path"
            return 1
        }
        [[ -d "$CONFIG_DIR" && ! -L "$CONFIG_DIR" &&
           -w "$CONFIG_DIR" ]] || {
            termux_neo_uninstall_error \
                "configuration directory is not writable"
            return 1
        }
        CONFIG_PRESENT=1
    fi
}

termux_neo_uninstall_validate_startup() {
    STARTUP_PATH="$(termux_neo_startup_target)" || {
        termux_neo_uninstall_error \
            "HOME does not provide a safe Bash startup path"
        return 1
    }
    STARTUP_STATE="$(
        termux_neo_startup_marker_state "$STARTUP_PATH"
    )" || {
        termux_neo_uninstall_error \
            "could not inspect the Bash startup file"
        return 1
    }
    [[ "$STARTUP_STATE" != "invalid" ]] || {
        termux_neo_uninstall_error \
            "Bash startup markers are incomplete or duplicated"
        return 1
    }
}

termux_neo_uninstall_prepare_backups() {
    if (( RUNTIME_PRESENT == 1 )); then
        RUNTIME_BACKUP="$(
            mktemp -d "$LIB_PARENT/.termux-neo.uninstall-rollback.XXXXXX"
        )" || return 1
    fi
    if (( COMMAND_PRESENT == 1 )); then
        COMMAND_BACKUP="$(
            mktemp -d "$BIN_PARENT/.termux-neo.uninstall-rollback.XXXXXX"
        )" || return 1
    fi
    if (( CONFIG_PRESENT == 1 )); then
        CONFIG_BACKUP="$(
            mktemp -d "$CONFIG_DIR/.termux-neo.uninstall-rollback.XXXXXX"
        )" || return 1
    fi
}

termux_neo_uninstall_remove_startup() {
    local startup_output=""

    startup_output="$(
        termux_neo_startup_remove "$STARTUP_PATH"
    )" || return 1
    printf '%s\n' "$startup_output"

    if [[ "$STARTUP_STATE" == "managed" ]]; then
        STARTUP_BACKUP="${startup_output##*backup: }"
        [[ "$STARTUP_BACKUP" == "$UNINSTALL_HOME"/.cache/termux-neo/startup-backups/bashrc.*.bak &&
           -f "$STARTUP_BACKUP" && ! -L "$STARTUP_BACKUP" ]] || {
            termux_neo_uninstall_error \
                "startup removal did not retain a valid backup"
            return 1
        }
        STARTUP_CHANGED=1
    fi
}

termux_neo_uninstall_move_targets() {
    if (( CONFIG_PRESENT == 1 )); then
        mv "$CONFIG_PATH" "$CONFIG_BACKUP/original" || return 1
        OLD_CONFIG_MOVED=1
    fi

    if (( COMMAND_PRESENT == 1 )); then
        mv "$COMMAND_PATH" "$COMMAND_BACKUP/original" || return 1
        OLD_COMMAND_MOVED=1
    fi

    if (( RUNTIME_PRESENT == 1 )); then
        mv "$RUNTIME_ROOT" "$RUNTIME_BACKUP/original" || return 1
        OLD_RUNTIME_MOVED=1
    fi
}

termux_neo_uninstall_restore_startup() {
    local startup_dir=""
    local restore_file=""

    (( STARTUP_CHANGED == 1 )) || return 0
    [[ -f "$STARTUP_BACKUP" && ! -L "$STARTUP_BACKUP" ]] || return 1

    startup_dir="$(dirname "$STARTUP_PATH")" || return 1
    [[ -d "$startup_dir" && ! -L "$startup_dir" &&
       -w "$startup_dir" ]] || return 1
    restore_file="$(
        mktemp "$startup_dir/.termux-neo-bashrc.restore.XXXXXX"
    )" || return 1
    cp -p "$STARTUP_BACKUP" "$restore_file" || {
        rm -f "$restore_file"
        return 1
    }
    mv -f "$restore_file" "$STARTUP_PATH" || {
        rm -f "$restore_file"
        return 1
    }
    STARTUP_CHANGED=0
}

termux_neo_uninstall_rollback() {
    set +e

    if (( OLD_RUNTIME_MOVED == 1 )); then
        if mv "$RUNTIME_BACKUP/original" "$RUNTIME_ROOT"; then
            OLD_RUNTIME_MOVED=0
        else
            ROLLBACK_FAILED=1
        fi
    fi

    if (( OLD_COMMAND_MOVED == 1 )); then
        if mv "$COMMAND_BACKUP/original" "$COMMAND_PATH"; then
            OLD_COMMAND_MOVED=0
        else
            ROLLBACK_FAILED=1
        fi
    fi

    if (( OLD_CONFIG_MOVED == 1 )); then
        if mv "$CONFIG_BACKUP/original" "$CONFIG_PATH"; then
            OLD_CONFIG_MOVED=0
        else
            ROLLBACK_FAILED=1
        fi
    fi

    if ! termux_neo_uninstall_restore_startup; then
        ROLLBACK_FAILED=1
    fi

    if (( ROLLBACK_FAILED == 0 )); then
        termux_neo_uninstall_error \
            "uninstall rolled back; the previous state was restored"
    else
        termux_neo_uninstall_error \
            "rollback could not be completed; rollback storage was preserved"
        [[ -z "$RUNTIME_BACKUP" ]] ||
            termux_neo_uninstall_error \
                "runtime rollback storage: $RUNTIME_BACKUP"
        [[ -z "$COMMAND_BACKUP" ]] ||
            termux_neo_uninstall_error \
                "command rollback storage: $COMMAND_BACKUP"
        [[ -z "$CONFIG_BACKUP" ]] ||
            termux_neo_uninstall_error \
                "configuration rollback storage: $CONFIG_BACKUP"
        [[ "$STARTUP_BACKUP" == "none (no edit)" ]] ||
            termux_neo_uninstall_error \
                "startup backup: $STARTUP_BACKUP"
    fi
}

termux_neo_uninstall_remove_runtime_backup() {
    local runtime_original="$RUNTIME_BACKUP/original"

    case "$RUNTIME_BACKUP" in
        "$LIB_PARENT"/.termux-neo.uninstall-rollback.*) ;;
        *) return 1 ;;
    esac
    [[ -d "$RUNTIME_BACKUP" && ! -L "$RUNTIME_BACKUP" ]] || return 1
    termux_neo_uninstall_manifest_is_owned "$runtime_original" || return 1
    rm -rf -- "$runtime_original" || return 1
    rmdir "$RUNTIME_BACKUP"
}

termux_neo_uninstall_remove_command_backup() {
    case "$COMMAND_BACKUP" in
        "$BIN_PARENT"/.termux-neo.uninstall-rollback.*) ;;
        *) return 1 ;;
    esac
    [[ -d "$COMMAND_BACKUP" && ! -L "$COMMAND_BACKUP" ]] || return 1
    termux_neo_uninstall_command_is_owned "$COMMAND_BACKUP/original" ||
        return 1
    rm -f "$COMMAND_BACKUP/original" || return 1
    rmdir "$COMMAND_BACKUP"
}

termux_neo_uninstall_remove_config_backup() {
    case "$CONFIG_BACKUP" in
        "$CONFIG_DIR"/.termux-neo.uninstall-rollback.*) ;;
        *) return 1 ;;
    esac
    [[ -d "$CONFIG_BACKUP" && ! -L "$CONFIG_BACKUP" ]] || return 1
    [[ -f "$CONFIG_BACKUP/original" &&
       ! -L "$CONFIG_BACKUP/original" ]] || return 1
    rm -f "$CONFIG_BACKUP/original" || return 1
    rmdir "$CONFIG_BACKUP"
}

termux_neo_uninstall_cleanup() {
    set +e

    if (( UNINSTALL_COMMITTED == 1 )); then
        if [[ -n "$RUNTIME_BACKUP" ]]; then
            if termux_neo_uninstall_remove_runtime_backup; then
                RUNTIME_BACKUP=""
            else
                CLEANUP_FAILED=1
                termux_neo_uninstall_error \
                    "removed runtime remains in recovery storage: $RUNTIME_BACKUP"
            fi
        fi
        if [[ -n "$COMMAND_BACKUP" ]]; then
            if termux_neo_uninstall_remove_command_backup; then
                COMMAND_BACKUP=""
            else
                CLEANUP_FAILED=1
                termux_neo_uninstall_error \
                    "removed command remains in recovery storage: $COMMAND_BACKUP"
            fi
        fi
        if [[ -n "$CONFIG_BACKUP" ]]; then
            if termux_neo_uninstall_remove_config_backup; then
                CONFIG_BACKUP=""
            else
                CLEANUP_FAILED=1
                termux_neo_uninstall_error \
                    "removed configuration remains in recovery storage: $CONFIG_BACKUP"
            fi
        fi
        if (( REMOVE_CONFIG == 1 )); then
            rmdir "$CONFIG_DIR" 2>/dev/null || true
        fi
    elif (( ROLLBACK_FAILED == 0 )); then
        [[ -z "$RUNTIME_BACKUP" || ! -e "$RUNTIME_BACKUP" ]] ||
            rmdir "$RUNTIME_BACKUP" 2>/dev/null
        [[ -z "$COMMAND_BACKUP" || ! -e "$COMMAND_BACKUP" ]] ||
            rmdir "$COMMAND_BACKUP" 2>/dev/null
        [[ -z "$CONFIG_BACKUP" || ! -e "$CONFIG_BACKUP" ]] ||
            rmdir "$CONFIG_BACKUP" 2>/dev/null
    fi
}

termux_neo_uninstall_report_success() {
    printf 'Termux Neo uninstall complete\n'
    printf 'installed version: %s\n' "$INSTALLED_VERSION"

    if (( RUNTIME_PRESENT == 1 )); then
        printf 'removed: %s\n' "$RUNTIME_ROOT"
    else
        printf 'already absent: %s\n' "$RUNTIME_ROOT"
    fi
    if (( COMMAND_PRESENT == 1 )); then
        printf 'removed: %s\n' "$COMMAND_PATH"
    else
        printf 'already absent: %s\n' "$COMMAND_PATH"
    fi

    if (( REMOVE_CONFIG == 1 )); then
        if (( CONFIG_PRESENT == 1 )); then
            printf 'removed: %s\n' "$CONFIG_PATH"
        else
            printf 'already absent: %s\n' "$CONFIG_PATH"
        fi
    else
        printf 'preserved: %s\n' "$CONFIG_PATH"
    fi

    if [[ "$STARTUP_STATE" == "managed" ]]; then
        printf 'startup integration: removed\n'
        printf 'startup backup: %s\n' "$STARTUP_BACKUP"
    else
        printf 'startup integration: already absent\n'
    fi

    if (( CLEANUP_FAILED == 1 )); then
        printf 'warning: recovery storage requires manual review\n'
    fi
}

termux_neo_uninstall_exit() {
    local status="${1-1}"

    trap - EXIT
    set +e
    if (( status != 0 && ROLLBACK_ARMED == 1 )); then
        termux_neo_uninstall_rollback
    fi
    termux_neo_uninstall_cleanup
    if (( REPORT_READY == 1 )); then
        printf 'uninstall report: %s\n' "$UNINSTALL_REPORT_PATH"
    fi
    exit "$status"
}

trap 'termux_neo_uninstall_exit $?' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

termux_neo_uninstall_require_tools || exit 1
termux_neo_uninstall_parse_arguments "$@" || exit 1
termux_neo_uninstall_validate_environment || exit 1
termux_neo_uninstall_open_report || exit 1
termux_neo_uninstall_validate_source || exit 1
termux_neo_uninstall_validate_installed_targets || exit 1
termux_neo_uninstall_validate_startup || exit 1
termux_neo_uninstall_prepare_backups ||
    termux_neo_uninstall_fail "could not prepare rollback storage"

ROLLBACK_ARMED=1
termux_neo_uninstall_remove_startup ||
    termux_neo_uninstall_fail "could not remove startup integration"
termux_neo_uninstall_move_targets ||
    termux_neo_uninstall_fail "could not remove owned installation paths"

UNINSTALL_COMMITTED=1
ROLLBACK_ARMED=0
termux_neo_uninstall_cleanup
termux_neo_uninstall_report_success
exit 0
