#!/data/data/com.termux/files/usr/bin/bash

# Release artifact integrity boundary.

termux_neo_release_manifest_error() {
    local error_function="${1-}"
    local message="${2-release manifest validation failed}"

    if [[ -n "$error_function" ]] &&
       declare -F "$error_function" >/dev/null 2>&1
    then
        "$error_function" "release manifest: $message"
    else
        printf 'termux-neo: release manifest: %s\n' "$message" >&2
    fi
}

termux_neo_release_manifest_path_is_safe() {
    local relative_path="${1-}"

    [[ "$relative_path" =~ ^\./[A-Za-z0-9._/-]+$ ]] || return 1
    [[ "$relative_path" != "./" ]] || return 1
    [[ "$relative_path" != *"//"* ]] || return 1
    [[ "$relative_path" != *"/./"* ]] || return 1
    [[ "$relative_path" != *"/../"* ]] || return 1
    [[ "$relative_path" != */. ]] || return 1
    [[ "$relative_path" != */.. ]] || return 1
    [[ "$relative_path" != "./RELEASE_MANIFEST.sha256" ]]
}

termux_neo_release_manifest_verify() {
    local source_root="${1-}"
    local error_function="${2-}"
    local manifest="$source_root/RELEASE_MANIFEST.sha256"
    local line=""
    local checksum=""
    local separator=""
    local relative_path=""
    local absolute_path=""
    local actual_checksum=""
    local discovered_path=""
    local discovered_relative=""
    local listed_count=0
    local discovered_count=0
    local symlink_path=""
    declare -A listed_paths=()

    if [[ ! -e "$manifest" && ! -L "$manifest" ]]; then
        return 0
    fi

    [[ -d "$source_root" && ! -L "$source_root" ]] || {
        termux_neo_release_manifest_error \
            "$error_function" "source root is not a regular directory"
        return 1
    }
    [[ -f "$manifest" && ! -L "$manifest" && -r "$manifest" ]] || {
        termux_neo_release_manifest_error \
            "$error_function" "manifest is not a readable regular file"
        return 1
    }
    command -v sha256sum >/dev/null 2>&1 || {
        termux_neo_release_manifest_error \
            "$error_function" "required command is unavailable: sha256sum"
        return 1
    }

    symlink_path="$(find "$source_root" -type l -print -quit)" || {
        termux_neo_release_manifest_error \
            "$error_function" "could not inspect the release tree"
        return 1
    }
    [[ -z "$symlink_path" ]] || {
        termux_neo_release_manifest_error \
            "$error_function" "release tree contains a symbolic link"
        return 1
    }

    while IFS= read -r line || [[ -n "$line" ]]; do
        (( ${#line} >= 69 )) || {
            termux_neo_release_manifest_error \
                "$error_function" "manifest line has an invalid format"
            return 1
        }

        checksum="${line:0:64}"
        separator="${line:64:2}"
        relative_path="${line:66}"

        [[ "$checksum" =~ ^[0-9a-f]{64}$ && "$separator" == "  " ]] || {
            termux_neo_release_manifest_error \
                "$error_function" "manifest checksum line is invalid"
            return 1
        }
        termux_neo_release_manifest_path_is_safe "$relative_path" || {
            termux_neo_release_manifest_error \
                "$error_function" "manifest path is unsafe: $relative_path"
            return 1
        }
        [[ -z "${listed_paths[$relative_path]+present}" ]] || {
            termux_neo_release_manifest_error \
                "$error_function" "manifest path is duplicated: $relative_path"
            return 1
        }

        absolute_path="$source_root/${relative_path#./}"
        [[ -f "$absolute_path" && ! -L "$absolute_path" && -r "$absolute_path" ]] || {
            termux_neo_release_manifest_error \
                "$error_function" "manifest file is unavailable: $relative_path"
            return 1
        }
        actual_checksum="$(sha256sum -- "$absolute_path")" || {
            termux_neo_release_manifest_error \
                "$error_function" "could not hash: $relative_path"
            return 1
        }
        actual_checksum="${actual_checksum%% *}"
        [[ "$actual_checksum" == "$checksum" ]] || {
            termux_neo_release_manifest_error \
                "$error_function" "checksum mismatch: $relative_path"
            return 1
        }

        listed_paths["$relative_path"]=1
        listed_count=$((listed_count + 1))
    done < "$manifest"

    (( listed_count > 0 )) || {
        termux_neo_release_manifest_error \
            "$error_function" "manifest is empty"
        return 1
    }

    while IFS= read -r -d '' discovered_path; do
        [[ "$discovered_path" != "$manifest" ]] || continue
        discovered_relative="./${discovered_path#"$source_root/"}"
        [[ -n "${listed_paths[$discovered_relative]+present}" ]] || {
            termux_neo_release_manifest_error \
                "$error_function" "unlisted release file: $discovered_relative"
            return 1
        }
        discovered_count=$((discovered_count + 1))
    done < <(find "$source_root" -type f -print0)

    (( discovered_count == listed_count )) || {
        termux_neo_release_manifest_error \
            "$error_function" "manifest does not match the complete release tree"
        return 1
    }
}
