#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - Optional Bash Startup Integration
# ==========================================================

TERMUX_NEO_STARTUP_BEGIN_MARKER="# >>> termux-neo startup >>>"
TERMUX_NEO_STARTUP_END_MARKER="# <<< termux-neo startup <<<"

termux_neo_startup_error() {
    local message="${1-startup integration failed}"

    printf 'termux-neo: %s\n' "$message" >&2
}

termux_neo_startup_path_is_safe() {
    local value="${1-}"

    [[ "$value" == /* ]] || return 1
    [[ "$value" != "/" ]] || return 1
    [[ "$value" != *"//"* ]] || return 1
    [[ "$value" != *"/./"* && "$value" != */. ]] || return 1
    [[ "$value" != *"/../"* && "$value" != */.. ]] || return 1
    [[ ! "$value" =~ [[:cntrl:]] ]]
}

termux_neo_startup_target() {
    local home_path="${HOME-}"

    termux_neo_startup_path_is_safe "$home_path" || return 1
    printf '%s/.bashrc' "$home_path"
}

termux_neo_startup_backup_dir() {
    local home_path="${HOME-}"

    termux_neo_startup_path_is_safe "$home_path" || return 1
    printf '%s/.cache/termux-neo/startup-backups' "$home_path"
}

termux_neo_startup_command() {
    local command_path="${TERMUX_NEO_COMMAND_PATH:-${PROJECT_ROOT-}/bin/termux-neo}"

    termux_neo_startup_path_is_safe "$command_path" || return 1
    [[ -f "$command_path" && ! -L "$command_path" &&
       -x "$command_path" ]] || return 1
    printf '%s' "$command_path"
}

termux_neo_startup_require_tools() {
    local command_name=""

    for command_name in awk chmod cmp cp dirname mkdir mktemp mv rm
    do
        command -v "$command_name" >/dev/null 2>&1 || {
            termux_neo_startup_error "required command is unavailable: $command_name"
            return 1
        }
    done
}

termux_neo_startup_ensure_backup_dir() {
    local home_path="${HOME-}"
    local backup_dir=""
    local directory=""
    local parent=""

    termux_neo_startup_path_is_safe "$home_path" || return 1
    backup_dir="$(termux_neo_startup_backup_dir)" || return 1

    for directory in \
        "$home_path/.cache" \
        "$home_path/.cache/termux-neo" \
        "$backup_dir"
    do
        if [[ -e "$directory" || -L "$directory" ]]; then
            [[ -d "$directory" && ! -L "$directory" &&
               -w "$directory" ]] || return 1
            continue
        fi

        parent="$(dirname "$directory")" || return 1
        [[ -d "$parent" && ! -L "$parent" && -w "$parent" ]] ||
            return 1
        mkdir -m 700 -- "$directory" || return 1
    done

    chmod 700 -- "$home_path/.cache/termux-neo" "$backup_dir"
}

termux_neo_startup_marker_state() {
    local target_file="${1-}"
    local begin_count=0
    local end_count=0
    local begin_line=0
    local end_line=0
    local line=""
    local line_number=0

    if [[ ! -e "$target_file" ]]; then
        printf 'absent'
        return 0
    fi

    [[ -f "$target_file" && ! -L "$target_file" && -r "$target_file" ]] ||
        return 1

    while IFS= read -r line || [[ -n "$line" ]]; do
        (( line_number += 1 ))
        if [[ "$line" == "$TERMUX_NEO_STARTUP_BEGIN_MARKER" ]]; then
            (( begin_count += 1 ))
            begin_line=$line_number
        elif [[ "$line" == "$TERMUX_NEO_STARTUP_END_MARKER" ]]; then
            (( end_count += 1 ))
            end_line=$line_number
        fi
    done < "$target_file"

    if (( begin_count == 0 && end_count == 0 )); then
        printf 'absent'
    elif (( begin_count == 1 && end_count == 1 && begin_line < end_line )); then
        printf 'managed'
    else
        printf 'invalid'
    fi
}

termux_neo_startup_write_block() {
    local output_file="${1-}"
    local command_path="${2-}"
    local quoted_command=""

    printf -v quoted_command '%q' "$command_path"

    printf '%s\n' \
        "$TERMUX_NEO_STARTUP_BEGIN_MARKER" \
        '# Managed by Termux Neo. Apply changes with: termux-neo --startup' \
        "if [[ \$- == *i* ]] && [[ -x $quoted_command ]]; then" \
        "    $quoted_command" \
        'fi' \
        "$TERMUX_NEO_STARTUP_END_MARKER" > "$output_file"
}

termux_neo_startup_rewrite() {
    local action="${1-}"
    local target_file="${2-}"
    local block_file="${3-}"
    local target_dir=""
    local output_file=""
    local backup_dir=""
    local backup_file="none (new file)"

    target_dir="$(dirname "$target_file")" || return 1
    [[ -d "$target_dir" && -w "$target_dir" ]] || {
        termux_neo_startup_error "Bash startup directory is not writable"
        return 1
    }

    output_file="$(mktemp "$target_dir/.termux-neo-bashrc.XXXXXX")" || {
        termux_neo_startup_error "could not create an atomic startup-file update"
        return 1
    }

    if [[ -e "$target_file" ]]; then
        [[ -f "$target_file" && ! -L "$target_file" &&
           -r "$target_file" && -w "$target_file" ]] || {
            rm -f -- "$output_file"
            termux_neo_startup_error "Bash startup file is not a writable regular file"
            return 1
        }
        cp -p -- "$target_file" "$output_file" || {
            rm -f -- "$output_file"
            termux_neo_startup_error "could not preserve Bash startup-file metadata"
            return 1
        }
    fi

    case "$action" in
        append)
            {
                if [[ -e "$target_file" ]]; then
                    awk '{ print }' "$target_file" || exit 1
                fi
                awk '{ print }' "$block_file" || exit 1
            } > "$output_file" || {
                rm -f -- "$output_file"
                termux_neo_startup_error "could not prepare the Bash startup block"
                return 1
            }
            ;;
        replace)
            awk \
                -v begin="$TERMUX_NEO_STARTUP_BEGIN_MARKER" \
                -v end="$TERMUX_NEO_STARTUP_END_MARKER" \
                -v block_file="$block_file" '
                    $0 == begin {
                        while ((getline block_line < block_file) > 0) {
                            print block_line
                        }
                        close(block_file)
                        inside = 1
                        next
                    }
                    inside && $0 == end {
                        inside = 0
                        next
                    }
                    !inside { print }
                ' "$target_file" > "$output_file" || {
                    rm -f -- "$output_file"
                    termux_neo_startup_error "could not update the Bash startup block"
                    return 1
                }
            ;;
        remove)
            awk \
                -v begin="$TERMUX_NEO_STARTUP_BEGIN_MARKER" \
                -v end="$TERMUX_NEO_STARTUP_END_MARKER" '
                    $0 == begin { inside = 1; next }
                    inside && $0 == end { inside = 0; next }
                    !inside { print }
                ' "$target_file" > "$output_file" || {
                    rm -f -- "$output_file"
                    termux_neo_startup_error "could not remove the Bash startup block"
                    return 1
                }
            ;;
        *)
            rm -f -- "$output_file"
            return 1
            ;;
    esac

    if [[ -e "$target_file" ]] && cmp -s "$target_file" "$output_file"; then
        rm -f -- "$output_file"
        printf 'unchanged|none (no edit)'
        return 0
    fi

    if [[ -e "$target_file" ]]; then
        backup_dir="$(termux_neo_startup_backup_dir)" || {
            rm -f -- "$output_file"
            termux_neo_startup_error "startup backup path is invalid"
            return 1
        }
        termux_neo_startup_ensure_backup_dir || {
            rm -f -- "$output_file"
            termux_neo_startup_error \
                "startup backup directory is unsafe or unavailable"
            return 1
        }
        backup_file="$(mktemp "$backup_dir/bashrc.XXXXXX.bak")" || {
            rm -f -- "$output_file"
            termux_neo_startup_error "could not create a startup backup"
            return 1
        }
        cp -p -- "$target_file" "$backup_file" || {
            rm -f -- "$output_file" "$backup_file"
            termux_neo_startup_error "could not back up the Bash startup file"
            return 1
        }
    fi

    mv -f -- "$output_file" "$target_file" || {
        rm -f -- "$output_file"
        termux_neo_startup_error "could not replace the Bash startup file"
        return 1
    }

    printf 'changed|%s' "$backup_file"
}

termux_neo_startup_install() {
    local target_file="${1-}"
    local command_path="${2-}"
    local state=""
    local target_dir=""
    local block_file=""
    local result=""

    state="$(termux_neo_startup_marker_state "$target_file")" || {
        termux_neo_startup_error "could not inspect the Bash startup file"
        return 1
    }
    [[ "$state" != "invalid" ]] || {
        termux_neo_startup_error "Bash startup markers are incomplete or duplicated"
        return 1
    }

    target_dir="$(dirname "$target_file")" || return 1
    block_file="$(mktemp "$target_dir/.termux-neo-block.XXXXXX")" || {
        termux_neo_startup_error "could not prepare the Bash startup block"
        return 1
    }
    termux_neo_startup_write_block "$block_file" "$command_path" || {
        rm -f -- "$block_file"
        return 1
    }

    if [[ "$state" == "absent" ]]; then
        result="$(termux_neo_startup_rewrite append "$target_file" "$block_file")" || {
            rm -f -- "$block_file"
            return 1
        }
    else
        result="$(termux_neo_startup_rewrite replace "$target_file" "$block_file")" || {
            rm -f -- "$block_file"
            return 1
        }
    fi

    rm -f -- "$block_file"
    printf 'startup integration: enabled\nstartup file: %s\nbackup: %s\n' \
        "$target_file" "${result#*|}"
}

termux_neo_startup_remove() {
    local target_file="${1-}"
    local state=""
    local result=""

    state="$(termux_neo_startup_marker_state "$target_file")" || {
        termux_neo_startup_error "could not inspect the Bash startup file"
        return 1
    }
    [[ "$state" != "invalid" ]] || {
        termux_neo_startup_error "Bash startup markers are incomplete or duplicated"
        return 1
    }

    if [[ "$state" == "absent" ]]; then
        printf 'startup integration: disabled\nstartup file: %s\nbackup: none (no edit)\n' \
            "$target_file"
        return 0
    fi

    result="$(termux_neo_startup_rewrite remove "$target_file" "")" || return 1
    printf 'startup integration: disabled\nstartup file: %s\nbackup: %s\n' \
        "$target_file" "${result#*|}"
}

termux_neo_startup_sync() {
    local target_file=""
    local command_path=""

    termux_neo_startup_require_tools || return 1

    target_file="$(termux_neo_startup_target)" || {
        termux_neo_startup_error "HOME does not provide a safe Bash startup path"
        return 1
    }

    termux_neo_config_load "$TERMUX_NEO_CONFIG_PATH" || {
        termux_neo_startup_error "configuration is invalid; startup integration was not changed"
        return 1
    }

    if [[ "$TERMUX_NEO_CONFIG_STARTUP_INTEGRATION" == "true" ]]; then
        command_path="$(termux_neo_startup_command)" || {
            termux_neo_startup_error "application entry point is unavailable"
            return 1
        }
        termux_neo_startup_install "$target_file" "$command_path"
    else
        termux_neo_startup_remove "$target_file"
    fi
}
