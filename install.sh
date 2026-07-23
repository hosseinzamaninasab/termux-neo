#!/data/data/com.termux/files/usr/bin/bash

set -Eeu -o pipefail

# ==========================================================
# Termux Neo - Production Installer
# ==========================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$SCRIPT_DIR"

INSTALL_HOME="${HOME-}"
INSTALL_PREFIX="${PREFIX-}"
LIB_PARENT="${INSTALL_PREFIX}/lib"
BIN_PARENT="${INSTALL_PREFIX}/bin"
RUNTIME_ROOT="${LIB_PARENT}/termux-neo"
COMMAND_PATH="${BIN_PARENT}/termux-neo"
CONFIG_PARENT="${INSTALL_HOME}/.config"
CONFIG_DIR="${CONFIG_PARENT}/termux-neo"
CONFIG_PATH="${CONFIG_DIR}/settings.conf"

CREATED_LIB_PARENT=0
CREATED_BIN_PARENT=0
CREATED_CONFIG_PARENT=0
CREATED_CONFIG_DIR=0
OLD_RUNTIME_MOVED=0
NEW_RUNTIME_INSTALLED=0
OLD_COMMAND_MOVED=0
NEW_COMMAND_INSTALLED=0
CONFIG_CREATED=0
INSTALL_COMMITTED=0
ROLLBACK_ARMED=0
ROLLBACK_FAILED=0

STAGE_CONTAINER=""
STAGE_RUNTIME=""
STAGE_LAUNCHER=""
STAGE_CONFIG=""
RUNTIME_BACKUP=""
COMMAND_BACKUP=""

termux_neo_install_error() {
    printf 'termux-neo installer: %s\n' "${1-installation failed}" >&2
}

termux_neo_install_fail() {
    termux_neo_install_error "${1-installation failed}"
    exit 1
}

termux_neo_install_path_is_safe() {
    local value="${1-}"

    [[ "$value" == /* ]] || return 1
    [[ "$value" != "/" ]] || return 1
    [[ "$value" != *$'\n'* ]] || return 1
    [[ "$value" != *$'\r'* ]] || return 1
    [[ "$value" != *$'\t'* ]] || return 1
    [[ "$value" != *$'\e'* ]] || return 1
}

termux_neo_install_require_tools() {
    local command_name=""

    for command_name in bash chmod cp dirname find mkdir mktemp mv rm rmdir
    do
        command -v "$command_name" >/dev/null 2>&1 || {
            termux_neo_install_error "required command is unavailable: $command_name"
            return 1
        }
    done
}

termux_neo_install_validate_environment() {
    local expected_prefix=""

    termux_neo_install_path_is_safe "$INSTALL_HOME" || {
        termux_neo_install_error "HOME is not a safe absolute Termux path"
        return 1
    }
    termux_neo_install_path_is_safe "$INSTALL_PREFIX" || {
        termux_neo_install_error "PREFIX is not a safe absolute Termux path"
        return 1
    }

    expected_prefix="$(dirname "$INSTALL_HOME")/usr" || return 1
    [[ "$INSTALL_PREFIX" == "$expected_prefix" ]] || {
        termux_neo_install_error "PREFIX is not the Termux-owned sibling of HOME"
        return 1
    }

    [[ -d "$INSTALL_HOME" && ! -L "$INSTALL_HOME" ]] || {
        termux_neo_install_error "HOME is not a regular Termux directory"
        return 1
    }
    [[ -d "$INSTALL_PREFIX" && ! -L "$INSTALL_PREFIX" ]] || {
        termux_neo_install_error "PREFIX is not a regular Termux directory"
        return 1
    }
    [[ -x "$INSTALL_PREFIX/bin/bash" ]] || {
        termux_neo_install_error "Termux Bash is unavailable at PREFIX/bin/bash"
        return 1
    }
    [[ "$SOURCE_ROOT" != "$RUNTIME_ROOT" ]] || {
        termux_neo_install_error "the installer cannot replace its own source tree"
        return 1
    }
}

termux_neo_install_validate_source() {
    local required_path=""
    local shell_file=""
    local version=""

    for required_path in \
        "$SOURCE_ROOT/VERSION" \
        "$SOURCE_ROOT/LICENSE" \
        "$SOURCE_ROOT/README.md" \
        "$SOURCE_ROOT/update.sh" \
        "$SOURCE_ROOT/uninstall.sh" \
        "$SOURCE_ROOT/bin/termux-neo" \
        "$SOURCE_ROOT/config/settings.example.conf" \
        "$SOURCE_ROOT/docs/cli.md" \
        "$SOURCE_ROOT/docs/installation.md" \
        "$SOURCE_ROOT/docs/release-artifacts.md" \
        "$SOURCE_ROOT/docs/settings-schema-v1.md" \
        "$SOURCE_ROOT/docs/update.md" \
        "$SOURCE_ROOT/docs/uninstallation.md" \
        "$SOURCE_ROOT/src/main.sh" \
        "$SOURCE_ROOT/src/config.sh" \
        "$SOURCE_ROOT/src/release.sh" \
        "$SOURCE_ROOT/src/startup_integration.sh"
    do
        [[ -f "$required_path" && -r "$required_path" ]] || {
            termux_neo_install_error "required source file is unavailable: $required_path"
            return 1
        }
    done

    IFS= read -r version < "$SOURCE_ROOT/VERSION" || return 1
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || {
        termux_neo_install_error "VERSION is invalid"
        return 1
    }

    bash -n "$SOURCE_ROOT/src/release.sh" || return 1
    source "$SOURCE_ROOT/src/release.sh"
    termux_neo_release_manifest_verify \
        "$SOURCE_ROOT" termux_neo_install_error || return 1

    while IFS= read -r -d '' shell_file; do
        bash -n "$shell_file" || {
            termux_neo_install_error "shell syntax check failed: $shell_file"
            return 1
        }
    done < <(
        find "$SOURCE_ROOT/src" "$SOURCE_ROOT/bin" -type f \
            \( -name '*.sh' -o -name 'termux-neo' \) -print0
    )
    bash -n "$SOURCE_ROOT/update.sh" "$SOURCE_ROOT/uninstall.sh" || return 1

    (
        cd "$SOURCE_ROOT"
        source src/config.sh
        termux_neo_config_load config/settings.example.conf
    ) || {
        termux_neo_install_error "settings example is invalid"
        return 1
    }
}

termux_neo_install_runtime_is_owned() {
    local first_line=""
    local second_line=""
    local manifest="$RUNTIME_ROOT/INSTALL_MANIFEST"

    [[ -d "$RUNTIME_ROOT" && ! -L "$RUNTIME_ROOT" ]] || return 1
    [[ -f "$manifest" && ! -L "$manifest" && -r "$manifest" ]] || return 1
    {
        IFS= read -r first_line
        IFS= read -r second_line
    } < "$manifest" || return 1

    [[ "$first_line" == "format=1" && "$second_line" == "product=termux-neo" ]]
}

termux_neo_install_command_is_owned() {
    local first_line=""
    local second_line=""

    [[ -f "$COMMAND_PATH" && ! -L "$COMMAND_PATH" && -r "$COMMAND_PATH" ]] ||
        return 1
    {
        IFS= read -r first_line
        IFS= read -r second_line
    } < "$COMMAND_PATH" || return 1

    [[ "$first_line" == "#!$INSTALL_PREFIX/bin/bash" &&
       "$second_line" == '# Termux Neo installed launcher v1' ]]
}

termux_neo_install_check_existing_targets() {
    if [[ -e "$RUNTIME_ROOT" || -L "$RUNTIME_ROOT" ]]; then
        termux_neo_install_runtime_is_owned || {
            termux_neo_install_error "refusing to replace an unowned runtime path: $RUNTIME_ROOT"
            return 1
        }
    fi

    if [[ -e "$COMMAND_PATH" || -L "$COMMAND_PATH" ]]; then
        termux_neo_install_command_is_owned || {
            termux_neo_install_error "refusing to replace an unowned command path: $COMMAND_PATH"
            return 1
        }
    fi

    if [[ -e "$CONFIG_PATH" || -L "$CONFIG_PATH" ]]; then
        [[ -f "$CONFIG_PATH" && -r "$CONFIG_PATH" ]] || {
            termux_neo_install_error "existing configuration is not a readable file: $CONFIG_PATH"
            return 1
        }
    fi
}

termux_neo_install_make_directory() {
    local directory="${1-}"
    local parent=""

    if [[ -e "$directory" || -L "$directory" ]]; then
        [[ -d "$directory" && ! -L "$directory" ]] || {
            termux_neo_install_error "installation parent is not a regular directory: $directory"
            return 1
        }
        return 0
    fi

    parent="$(dirname "$directory")" || return 1
    [[ -d "$parent" && ! -L "$parent" ]] || {
        termux_neo_install_error "installation parent is unavailable: $parent"
        return 1
    }
    mkdir "$directory"
}

termux_neo_install_prepare_directories() {
    if [[ ! -e "$LIB_PARENT" ]]; then
        termux_neo_install_make_directory "$LIB_PARENT" || return 1
        CREATED_LIB_PARENT=1
    else
        termux_neo_install_make_directory "$LIB_PARENT" || return 1
    fi

    if [[ ! -e "$BIN_PARENT" ]]; then
        termux_neo_install_make_directory "$BIN_PARENT" || return 1
        CREATED_BIN_PARENT=1
    else
        termux_neo_install_make_directory "$BIN_PARENT" || return 1
    fi

    if [[ ! -e "$CONFIG_PARENT" ]]; then
        termux_neo_install_make_directory "$CONFIG_PARENT" || return 1
        CREATED_CONFIG_PARENT=1
    else
        termux_neo_install_make_directory "$CONFIG_PARENT" || return 1
    fi

    if [[ ! -e "$CONFIG_DIR" ]]; then
        termux_neo_install_make_directory "$CONFIG_DIR" || return 1
        CREATED_CONFIG_DIR=1
    else
        termux_neo_install_make_directory "$CONFIG_DIR" || return 1
    fi
}

termux_neo_install_prepare_runtime() {
    local bash_command_quoted=""
    local runtime_command_quoted=""
    local command_path_quoted=""
    local version=""
    local version_output=""
    local shell_file=""

    STAGE_CONTAINER="$(mktemp -d "$LIB_PARENT/.termux-neo.stage.XXXXXX")" ||
        return 1
    STAGE_RUNTIME="$STAGE_CONTAINER/runtime"
    mkdir "$STAGE_RUNTIME" "$STAGE_RUNTIME/bin" \
        "$STAGE_RUNTIME/config" "$STAGE_RUNTIME/docs"

    cp -p "$SOURCE_ROOT/VERSION" "$SOURCE_ROOT/LICENSE" \
        "$SOURCE_ROOT/README.md" "$STAGE_RUNTIME/"
    cp -p "$SOURCE_ROOT/bin/termux-neo" "$STAGE_RUNTIME/bin/"
    cp -p "$SOURCE_ROOT/config/settings.example.conf" "$STAGE_RUNTIME/config/"
    cp -p "$SOURCE_ROOT/docs/cli.md" "$SOURCE_ROOT/docs/installation.md" \
        "$SOURCE_ROOT/docs/release-artifacts.md" \
        "$SOURCE_ROOT/docs/settings-schema-v1.md" "$SOURCE_ROOT/docs/update.md" \
        "$SOURCE_ROOT/docs/uninstallation.md" \
        "$STAGE_RUNTIME/docs/"
    cp -pR "$SOURCE_ROOT/src" "$STAGE_RUNTIME/"

    IFS= read -r version < "$SOURCE_ROOT/VERSION"
    printf '%s\n' \
        'format=1' \
        'product=termux-neo' \
        "version=$version" \
        "runtime_root=$RUNTIME_ROOT" \
        "command_path=$COMMAND_PATH" \
        "config_path=$CONFIG_PATH" > "$STAGE_RUNTIME/INSTALL_MANIFEST"

    find "$STAGE_RUNTIME" -type d -exec chmod 755 {} +
    find "$STAGE_RUNTIME" -type f -exec chmod 644 {} +
    chmod 755 "$STAGE_RUNTIME/bin/termux-neo" \
        "$STAGE_RUNTIME"/src/*.sh \
        "$STAGE_RUNTIME"/src/modules/*.sh

    STAGE_LAUNCHER="$(mktemp "$BIN_PARENT/.termux-neo.launcher.XXXXXX")" ||
        return 1
    printf -v bash_command_quoted '%q' "$INSTALL_PREFIX/bin/bash"
    printf -v runtime_command_quoted '%q' "$RUNTIME_ROOT/src/main.sh"
    printf -v command_path_quoted '%q' "$COMMAND_PATH"
    printf '%s\n' \
        "#!$INSTALL_PREFIX/bin/bash" \
        '# Termux Neo installed launcher v1' \
        'set -e' \
        'TERMUX_NEO_CONFIG_PATH="${TERMUX_NEO_CONFIG_PATH:-$HOME/.config/termux-neo/settings.conf}"' \
        "TERMUX_NEO_COMMAND_PATH=$command_path_quoted" \
        'export TERMUX_NEO_CONFIG_PATH TERMUX_NEO_COMMAND_PATH' \
        "exec $bash_command_quoted $runtime_command_quoted \"\$@\"" > "$STAGE_LAUNCHER"
    chmod 755 "$STAGE_LAUNCHER"

    if [[ ! -e "$CONFIG_PATH" && ! -L "$CONFIG_PATH" ]]; then
        STAGE_CONFIG="$(mktemp "$CONFIG_DIR/.settings.conf.XXXXXX")" || return 1
        cp -p "$SOURCE_ROOT/config/settings.example.conf" "$STAGE_CONFIG"
        chmod 600 "$STAGE_CONFIG"
    fi

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
    [[ "$version_output" == "termux-neo $version" ]] || return 1
}

termux_neo_install_prepare_backups() {
    if [[ -e "$RUNTIME_ROOT" || -L "$RUNTIME_ROOT" ]]; then
        RUNTIME_BACKUP="$(mktemp -d "$LIB_PARENT/.termux-neo.rollback.XXXXXX")" ||
            return 1
    fi
    if [[ -e "$COMMAND_PATH" || -L "$COMMAND_PATH" ]]; then
        COMMAND_BACKUP="$(mktemp -d "$BIN_PARENT/.termux-neo.rollback.XXXXXX")" ||
            return 1
    fi
}

termux_neo_install_swap() {
    if [[ -n "$RUNTIME_BACKUP" ]]; then
        mv "$RUNTIME_ROOT" "$RUNTIME_BACKUP/original"
        OLD_RUNTIME_MOVED=1
    fi
    mv "$STAGE_RUNTIME" "$RUNTIME_ROOT"
    NEW_RUNTIME_INSTALLED=1

    if [[ -n "$COMMAND_BACKUP" ]]; then
        mv "$COMMAND_PATH" "$COMMAND_BACKUP/original"
        OLD_COMMAND_MOVED=1
    fi
    mv "$STAGE_LAUNCHER" "$COMMAND_PATH"
    NEW_COMMAND_INSTALLED=1

    if [[ -n "$STAGE_CONFIG" ]]; then
        mv "$STAGE_CONFIG" "$CONFIG_PATH"
        CONFIG_CREATED=1
    fi
}

termux_neo_install_smoke_test() {
    local version=""
    local version_output=""
    local config_output=""

    [[ -d "$RUNTIME_ROOT" && ! -L "$RUNTIME_ROOT" ]] || return 1
    [[ -x "$COMMAND_PATH" && -x "$RUNTIME_ROOT/bin/termux-neo" ]] || return 1
    bash -n "$COMMAND_PATH" || return 1

    IFS= read -r version < "$RUNTIME_ROOT/VERSION" || return 1
    version_output="$(
        unset TERMUX_NEO_CONFIG_PATH TERMUX_NEO_COMMAND_PATH
        HOME="$INSTALL_HOME" "$COMMAND_PATH" --version
    )" || return 1
    [[ "$version_output" == "termux-neo $version" ]] || return 1

    config_output="$(
        unset TERMUX_NEO_CONFIG_PATH TERMUX_NEO_COMMAND_PATH
        HOME="$INSTALL_HOME" "$COMMAND_PATH" --config
    )" || return 1
    [[ "$config_output" == "$CONFIG_PATH" ]] || return 1
}

termux_neo_install_rollback() {
    set +e

    if (( CONFIG_CREATED == 1 )); then
        if rm -f "$CONFIG_PATH"; then
            CONFIG_CREATED=0
        else
            ROLLBACK_FAILED=1
        fi
    fi

    if (( NEW_COMMAND_INSTALLED == 1 )); then
        if rm -f "$COMMAND_PATH"; then
            NEW_COMMAND_INSTALLED=0
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

    if (( NEW_RUNTIME_INSTALLED == 1 )); then
        if rm -rf "$RUNTIME_ROOT"; then
            NEW_RUNTIME_INSTALLED=0
        else
            ROLLBACK_FAILED=1
        fi
    fi
    if (( OLD_RUNTIME_MOVED == 1 )); then
        if mv "$RUNTIME_BACKUP/original" "$RUNTIME_ROOT"; then
            OLD_RUNTIME_MOVED=0
        else
            ROLLBACK_FAILED=1
        fi
    fi

    if (( ROLLBACK_FAILED == 0 )); then
        termux_neo_install_error "installation rolled back; the previous state was restored"
    else
        termux_neo_install_error "rollback could not be completed; rollback storage was preserved"
        [[ -z "$RUNTIME_BACKUP" ]] ||
            termux_neo_install_error "runtime rollback storage: $RUNTIME_BACKUP"
        [[ -z "$COMMAND_BACKUP" ]] ||
            termux_neo_install_error "command rollback storage: $COMMAND_BACKUP"
    fi
}

termux_neo_install_cleanup() {
    set +e

    [[ -z "$STAGE_LAUNCHER" || ! -e "$STAGE_LAUNCHER" ]] ||
        rm -f "$STAGE_LAUNCHER"
    [[ -z "$STAGE_CONFIG" || ! -e "$STAGE_CONFIG" ]] ||
        rm -f "$STAGE_CONFIG"
    [[ -z "$STAGE_CONTAINER" || ! -e "$STAGE_CONTAINER" ]] ||
        rm -rf "$STAGE_CONTAINER"
    if (( ROLLBACK_FAILED == 0 || INSTALL_COMMITTED == 1 )); then
        [[ -z "$RUNTIME_BACKUP" || ! -e "$RUNTIME_BACKUP" ]] ||
            rm -rf "$RUNTIME_BACKUP"
        [[ -z "$COMMAND_BACKUP" || ! -e "$COMMAND_BACKUP" ]] ||
            rm -rf "$COMMAND_BACKUP"
    fi

    if (( INSTALL_COMMITTED == 0 )); then
        (( CREATED_CONFIG_DIR == 0 )) || rmdir "$CONFIG_DIR" 2>/dev/null
        (( CREATED_CONFIG_PARENT == 0 )) || rmdir "$CONFIG_PARENT" 2>/dev/null
        (( CREATED_BIN_PARENT == 0 )) || rmdir "$BIN_PARENT" 2>/dev/null
        (( CREATED_LIB_PARENT == 0 )) || rmdir "$LIB_PARENT" 2>/dev/null
    fi
}

termux_neo_install_exit() {
    local status="${1-1}"

    trap - EXIT
    set +e
    if (( status != 0 && ROLLBACK_ARMED == 1 )); then
        termux_neo_install_rollback
    fi
    termux_neo_install_cleanup
    exit "$status"
}

termux_neo_install_report() {
    local version=""

    IFS= read -r version < "$RUNTIME_ROOT/VERSION"
    printf 'Termux Neo installation complete\n'
    printf 'version: %s\n' "$version"
    (( CREATED_LIB_PARENT == 0 )) || printf 'changed: created %s\n' "$LIB_PARENT"
    (( CREATED_BIN_PARENT == 0 )) || printf 'changed: created %s\n' "$BIN_PARENT"
    (( CREATED_CONFIG_PARENT == 0 )) || printf 'changed: created %s\n' "$CONFIG_PARENT"
    (( CREATED_CONFIG_DIR == 0 )) || printf 'changed: created %s\n' "$CONFIG_DIR"
    if (( OLD_RUNTIME_MOVED == 1 )); then
        printf 'changed: replaced %s\n' "$RUNTIME_ROOT"
    else
        printf 'changed: created %s\n' "$RUNTIME_ROOT"
    fi
    if (( OLD_COMMAND_MOVED == 1 )); then
        printf 'changed: replaced %s\n' "$COMMAND_PATH"
    else
        printf 'changed: created %s\n' "$COMMAND_PATH"
    fi
    if (( CONFIG_CREATED == 1 )); then
        printf 'changed: created %s\n' "$CONFIG_PATH"
    else
        printf 'preserved: %s\n' "$CONFIG_PATH"
    fi
    printf 'startup integration: unchanged\n'
}

trap 'termux_neo_install_exit $?' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

termux_neo_install_require_tools || exit 1
termux_neo_install_validate_environment || exit 1
termux_neo_install_validate_source || exit 1
termux_neo_install_check_existing_targets || exit 1

ROLLBACK_ARMED=1
termux_neo_install_prepare_directories || exit 1
termux_neo_install_prepare_runtime ||
    termux_neo_install_fail "could not prepare and validate the staged installation"
termux_neo_install_prepare_backups ||
    termux_neo_install_fail "could not prepare rollback storage"
termux_neo_install_swap ||
    termux_neo_install_fail "could not atomically replace installation paths"
termux_neo_install_smoke_test ||
    termux_neo_install_fail "installed command failed its smoke test"

termux_neo_install_report
INSTALL_COMMITTED=1
ROLLBACK_ARMED=0
exit 0
