#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(dirname "$SCRIPT_DIR")"
TEMP_PARENT="${TMPDIR:-${HOME:-}/.cache/termux-neo}"
TEMP_PARENT="${TEMP_PARENT%/}"
TEMP_DIR=""
MATRIX_ROOT=""
MATRIX_HOME=""
MATRIX_PREFIX=""
MATRIX_RUNTIME=""
MATRIX_COMMAND=""
MATRIX_CONFIG=""
MATRIX_STDOUT=""
MATRIX_STDERR=""
MATRIX_PORTRAIT_WIDTH=""
MATRIX_LANDSCAPE_WIDTH=""
MATRIX_MODE=""
MATRIX_SOURCE=""
REPORT_OUTPUT=""
REPORT_TEMP=""
ARTIFACT_CHECKSUM_RESULT="NOT RUN"
ARTIFACT_MANIFEST_RESULT="NOT RUN"
ARTIFACT_SMOKE_RESULT="NOT RUN"
ARTIFACT_STABILITY_RESULT="NOT RUN"
DEVICE_MANUFACTURER=""
DEVICE_MODEL=""
DEVICE_ANDROID=""
DEVICE_BASH=""
SUCCESS=0
LEGACY_SHEBANG_LIMIT=128

beta_error() {
    printf 'termux-neo beta: %s\n' \
        "${1-public beta field test failed}" >&2
}

beta_fail() {
    beta_error "${1-public beta field test failed}"
    exit 1
}

beta_path_is_safe() {
    local value="${1-}"

    [[ "$value" == /* ]] || return 1
    [[ "$value" != "/" ]] || return 1
    [[ "$value" != *"//"* ]] || return 1
    [[ "$value" != *"/./"* && "$value" != */. ]] || return 1
    [[ "$value" != *"/../"* && "$value" != */.. ]] || return 1
    [[ ! "$value" =~ [[:cntrl:]] ]]
}

beta_fact_is_safe() {
    local value="${1-}"
    local pattern='^[A-Za-z0-9._+()/ -]+$'

    [[ -n "$value" ]] || return 1
    (( ${#value} <= 80 )) || return 1
    [[ "$value" =~ $pattern ]]
}

beta_cleanup() {
    local exit_code=$?

    trap - EXIT
    set +e

    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" &&
          "$TEMP_DIR" == "$TEMP_PARENT"/tnb.* ]]
    then
        rm -rf -- "$TEMP_DIR" || true
    fi
    if [[ -n "$REPORT_TEMP" &&
          -f "$REPORT_TEMP" &&
          ! -L "$REPORT_TEMP" &&
          "${REPORT_TEMP##*/}" == .beta-field-report.* ]]
    then
        rm -f -- "$REPORT_TEMP" || true
    fi

    if (( SUCCESS == 0 && exit_code != 0 )); then
        beta_error "field matrix stopped with status $exit_code"
    fi

    exit "$exit_code"
}

trap beta_cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

beta_make_command_stub() {
    local path="${1-}"
    local body="${2-}"
    local bash_path=""

    bash_path="$(command -v bash)" || return 1
    printf '#!%s\n%s\n' "$bash_path" "$body" > "$path"
    chmod 755 "$path"
}

beta_link_command() {
    local name="${1-}"
    local target=""

    target="$(command -v "$name")" || return 1
    ln -s "$target" "$2/$name"
}

beta_run_lifecycle() {
    local action="${1-}"
    local status=0
    shift

    : > "$MATRIX_STDOUT"
    : > "$MATRIX_STDERR"

    env -i \
        HOME="$MATRIX_HOME" \
        PREFIX="$MATRIX_PREFIX" \
        PATH="$MATRIX_PREFIX/bin:$PATH" \
        TMPDIR="$MATRIX_ROOT/tmp" \
        TERM="${TERM:-xterm-256color}" \
        LANG="${LANG:-C.UTF-8}" \
        bash "$MATRIX_SOURCE/$action" "$@" \
        > "$MATRIX_STDOUT" 2> "$MATRIX_STDERR" ||
        status=$?

    if (( status != 0 )); then
        if [[ -s "$MATRIX_STDOUT" ]]; then
            printf -- '--- %s stdout ---\n' "$action" >&2
            sed -n '1,80p' "$MATRIX_STDOUT" >&2
        fi
        if [[ -s "$MATRIX_STDERR" ]]; then
            printf -- '--- %s stderr ---\n' "$action" >&2
            sed -n '1,80p' "$MATRIX_STDERR" >&2
        fi
        beta_fail "$action failed with status $status"
    fi
}

beta_legacy_shebang_is_safe() {
    local interpreter="${1-}"
    local line_length=0

    line_length=$((2 + ${#interpreter} + 1))
    (( line_length <= LEGACY_SHEBANG_LIMIT ))
}

beta_assert_success_output() {
    local label="${1-}"

    [[ ! -s "$MATRIX_STDERR" ]] ||
        beta_fail "$label produced stderr"
}

beta_max_line_width() {
    local file="${1-}"
    local line=""
    local max=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        (( ${#line} <= max )) || max="${#line}"
    done < "$file"

    printf '%s' "$max"
}

beta_verify_render() {
    local label="${1-}"
    local width="${2-}"
    local stdout_file="${3-}"
    local stderr_file="${4-}"
    local max_width=""

    [[ ! -s "$stderr_file" ]] ||
        beta_fail "$label produced stderr"
    grep -Fq 'TERMUX NEO' "$stdout_file" ||
        beta_fail "$label omitted the dashboard title"
    grep -Fq 'NET:' "$stdout_file" ||
        beta_fail "$label omitted network state"
    grep -Fq '╰─❯' "$stdout_file" ||
        beta_fail "$label omitted the prompt"
    [[ "$(wc -l < "$stdout_file")" == "16" ]] ||
        beta_fail "$label changed the render line count"
    max_width="$(beta_max_line_width "$stdout_file")"
    [[ "$max_width" =~ ^[0-9]+$ && "$max_width" -le "$width" ]] ||
        beta_fail "$label exceeded the recorded terminal width"
}

beta_run_live_orientation() {
    local label="${1-}"
    local width="${2-}"
    local stdout_file="$MATRIX_ROOT/$label.stdout"
    local stderr_file="$MATRIX_ROOT/$label.stderr"

    (
        cd "$MATRIX_HOME"
        HOME="$MATRIX_HOME" \
        PREFIX="$MATRIX_PREFIX" \
        PATH="$MATRIX_ROOT/orientation-bin:$PATH" \
        TERM="${TERM:-xterm-256color}" \
        NO_COLOR=1 \
        USER="BetaTester" \
        TERMUX_NEO_BETA_WIDTH="$width" \
            "$MATRIX_COMMAND"
    ) > "$stdout_file" 2> "$stderr_file" ||
        beta_fail "$label render failed"

    beta_verify_render "$label" "$width" "$stdout_file" "$stderr_file"
}

beta_capture_orientation_widths() {
    local first=""
    local second=""

    if [[ "$MATRIX_MODE" == "record" ]]; then
        [[ -t 0 ]] ||
            beta_fail "record mode requires an interactive terminal"

        printf '\nRotate the device to PORTRAIT, wait for Termux to resize, then press Enter: '
        IFS= read -r _
        first="$(tput cols 2>/dev/null || true)"

        printf 'Rotate the device to LANDSCAPE, wait for Termux to resize, then press Enter: '
        IFS= read -r _
        second="$(tput cols 2>/dev/null || true)"
        printf '\n'
    else
        first="34"
        second="94"
    fi

    [[ "$first" =~ ^[0-9]+$ && "$second" =~ ^[0-9]+$ ]] ||
        beta_fail "terminal orientation widths are invalid"
    (( first >= 34 && second >= 34 )) ||
        beta_fail "an orientation is below the supported 34-column minimum"
    (( first < second )) ||
        beta_fail "landscape must record more columns than portrait"

    MATRIX_PORTRAIT_WIDTH="$first"
    MATRIX_LANDSCAPE_WIDTH="$second"
}

beta_prepare_restricted_bins() {
    local offline_bin="$MATRIX_ROOT/offline-bin"
    local denied_bin="$MATRIX_ROOT/permission-bin"
    local orientation_bin="$MATRIX_ROOT/orientation-bin"
    local command_name=""

    mkdir "$offline_bin" "$denied_bin" "$orientation_bin"

    for command_name in bash dirname seq
    do
        beta_link_command "$command_name" "$offline_bin" ||
            beta_fail "could not prepare offline command: $command_name"
        beta_link_command "$command_name" "$denied_bin" ||
            beta_fail "could not prepare restricted command: $command_name"
    done

    for command_name in awk grep head sed
    do
        beta_link_command "$command_name" "$denied_bin" ||
            beta_fail "could not prepare parser command: $command_name"
    done

    beta_make_command_stub "$offline_bin/tput" \
        'case "${1-}" in cols) printf "%s" "${TERMUX_NEO_BETA_WIDTH:-56}" ;; colors) printf "0" ;; *) exit 1 ;; esac'
    beta_make_command_stub "$denied_bin/tput" \
        'case "${1-}" in cols) printf "%s" "${TERMUX_NEO_BETA_WIDTH:-56}" ;; colors) printf "0" ;; *) exit 1 ;; esac'
    beta_make_command_stub "$orientation_bin/tput" \
        'case "${1-}" in cols) printf "%s" "${TERMUX_NEO_BETA_WIDTH:-56}" ;; colors) printf "0" ;; *) exit 1 ;; esac'

    for command_name in ip ifconfig getprop termux-battery-status dumpsys
    do
        beta_make_command_stub "$denied_bin/$command_name" \
            'printf "permission denied\n" >&2; exit 13'
    done

    beta_make_command_stub "$denied_bin/timeout" \
        'while [[ "${1-}" == --* ]]; do shift; done; shift || exit 1; exec "$@"'
}

beta_run_constrained_render() {
    local label="${1-}"
    local path_value="${2-}"
    local width="${3-}"
    local stdout_file="$MATRIX_ROOT/$label.stdout"
    local stderr_file="$MATRIX_ROOT/$label.stderr"

    (
        cd "$MATRIX_HOME"
        env -i \
            HOME="$MATRIX_HOME" \
            PREFIX="$MATRIX_PREFIX" \
            PATH="$path_value" \
            TERM="xterm-256color" \
            LANG="C.UTF-8" \
            NO_COLOR=1 \
            USER="BetaTester" \
            TERMUX_NEO_BETA_WIDTH="$width" \
            TERMUX_NEO_NET_CLASS_ROOT="$MATRIX_ROOT/empty-net" \
            TERMUX_NEO_POWER_SUPPLY_ROOT="$MATRIX_ROOT/empty-power" \
            "$MATRIX_COMMAND"
    ) > "$stdout_file" 2> "$stderr_file" ||
        beta_fail "$label render failed"

    beta_verify_render "$label" "$width" "$stdout_file" "$stderr_file"
}

beta_run_matrix() {
    local expected_version=""
    local config_before="$MATRIX_ROOT/config-before"
    local bashrc_before="$MATRIX_ROOT/bashrc-before"
    local offline_bin="$MATRIX_ROOT/offline-bin"
    local denied_bin="$MATRIX_ROOT/permission-bin"
    local leftover=""
    local -a leftovers=()

    IFS= read -r expected_version < "$MATRIX_SOURCE/VERSION" ||
        beta_fail "candidate VERSION could not be read"
    [[ "$expected_version" == "0.9.0-beta" ]] ||
        beta_fail "field candidate is not 0.9.0-beta"

    mkdir -p \
        "$MATRIX_HOME" \
        "$MATRIX_PREFIX/bin" \
        "$MATRIX_ROOT/tmp" \
        "$MATRIX_ROOT/empty-net" \
        "$MATRIX_ROOT/empty-power"
    ln -s "$(command -v bash)" "$MATRIX_PREFIX/bin/bash"

    MATRIX_RUNTIME="$MATRIX_PREFIX/lib/termux-neo"
    MATRIX_COMMAND="$MATRIX_PREFIX/bin/termux-neo"
    MATRIX_CONFIG="$MATRIX_HOME/.config/termux-neo/settings.conf"
    MATRIX_STDOUT="$MATRIX_ROOT/lifecycle.stdout"
    MATRIX_STDERR="$MATRIX_ROOT/lifecycle.stderr"

    printf 'export BETA_EXISTING_VALUE=kept\n' > "$MATRIX_HOME/.bashrc"
    cp -p "$MATRIX_HOME/.bashrc" "$bashrc_before"

    beta_run_lifecycle install.sh
    beta_assert_success_output "clean install"
    [[ -d "$MATRIX_RUNTIME" && ! -L "$MATRIX_RUNTIME" &&
       -x "$MATRIX_COMMAND" &&
       -f "$MATRIX_CONFIG" && ! -L "$MATRIX_CONFIG" ]] ||
        beta_fail "clean install did not create the owned layout"
    [[ "$("$MATRIX_COMMAND" --version)" == \
       "termux-neo $expected_version" ]] ||
        beta_fail "clean install version is inconsistent"
    [[ "$(stat -c '%a' "$MATRIX_CONFIG")" == "600" ]] ||
        beta_fail "clean install configuration mode is not 600"
    cmp -s "$MATRIX_HOME/.bashrc" "$bashrc_before" ||
        beta_fail "clean install changed unrelated Bash startup content"

    beta_prepare_restricted_bins
    beta_capture_orientation_widths
    if [[ "$MATRIX_MODE" == "record" ]]; then
        beta_run_live_orientation \
            "portrait" "$MATRIX_PORTRAIT_WIDTH"
        beta_run_live_orientation \
            "landscape" "$MATRIX_LANDSCAPE_WIDTH"
    else
        beta_run_constrained_render \
            "portrait" "$offline_bin" "$MATRIX_PORTRAIT_WIDTH"
        beta_run_constrained_render \
            "landscape" "$offline_bin" "$MATRIX_LANDSCAPE_WIDTH"
    fi

    beta_run_constrained_render \
        "offline-startup" "$offline_bin" "$MATRIX_PORTRAIT_WIDTH"
    grep -Fq 'NET:DOWN' "$MATRIX_ROOT/offline-startup.stdout" ||
        beta_fail "offline startup did not report a down network"

    beta_run_constrained_render \
        "permission-startup" "$denied_bin" "$MATRIX_LANDSCAPE_WIDTH"
    if grep -Fiq 'permission denied' \
        "$MATRIX_ROOT/permission-startup.stdout" \
        "$MATRIX_ROOT/permission-startup.stderr"
    then
        beta_fail "restricted-command stderr reached the rendered interface"
    fi

    printf '%s\n' \
        'schema_version=1' \
        'display_user=BetaTester' \
        'theme=matrix' \
        'color_mode=never' \
        'startup_integration=false' > "$MATRIX_CONFIG"
    chmod 640 "$MATRIX_CONFIG"
    cp -p "$MATRIX_CONFIG" "$config_before"

    beta_run_lifecycle uninstall.sh
    beta_assert_success_output "configuration-preserving uninstall"
    [[ ! -e "$MATRIX_RUNTIME" && ! -e "$MATRIX_COMMAND" ]] ||
        beta_fail "configuration-preserving uninstall left owned code"
    cmp -s "$MATRIX_CONFIG" "$config_before" ||
        beta_fail "configuration-preserving uninstall changed settings"
    [[ "$(stat -c '%a' "$MATRIX_CONFIG")" == "640" ]] ||
        beta_fail "configuration-preserving uninstall changed settings mode"

    beta_run_lifecycle install.sh
    beta_assert_success_output "existing-configuration install"
    cmp -s "$MATRIX_CONFIG" "$config_before" ||
        beta_fail "existing-configuration install changed settings"
    [[ "$(stat -c '%a' "$MATRIX_CONFIG")" == "640" ]] ||
        beta_fail "existing-configuration install changed settings mode"

    printf '0.4.0-alpha\n' > "$MATRIX_RUNTIME/VERSION"
    sed -i 's/^version=.*/version=0.4.0-alpha/' \
        "$MATRIX_RUNTIME/INSTALL_MANIFEST"

    beta_run_lifecycle update.sh
    beta_assert_success_output "prior-alpha update"
    grep -Fqx 'version relation: upgrade' "$MATRIX_STDOUT" ||
        beta_fail "prior-alpha update did not report an upgrade"
    [[ "$("$MATRIX_COMMAND" --version)" == \
       "termux-neo $expected_version" ]] ||
        beta_fail "prior-alpha update installed the wrong version"
    cmp -s "$MATRIX_CONFIG" "$config_before" ||
        beta_fail "prior-alpha update changed settings"

    beta_run_lifecycle uninstall.sh --remove-config
    beta_assert_success_output "configuration-removing uninstall"
    [[ ! -e "$MATRIX_RUNTIME" &&
       ! -e "$MATRIX_COMMAND" &&
       ! -e "$MATRIX_CONFIG" ]] ||
        beta_fail "configuration-removing uninstall left owned state"
    cmp -s "$MATRIX_HOME/.bashrc" "$bashrc_before" ||
        beta_fail "field lifecycle changed unrelated Bash startup content"

    shopt -s nullglob
    leftovers=(
        "$MATRIX_PREFIX/lib"/.termux-neo.*
        "$MATRIX_PREFIX/bin"/.termux-neo.*
        "$MATRIX_HOME/.config/termux-neo"/.settings.conf.*
    )
    if (( ${#leftovers[@]} != 0 )); then
        for leftover in "${leftovers[@]}"; do
            beta_error \
                "transaction path remained: ${leftover#"$MATRIX_ROOT/"}"
        done
        beta_fail "field lifecycle left transaction paths"
    fi
}

beta_prepare_artifact() {
    local version=""
    local archive_name=""
    local checksum_name=""
    local package_root=""
    local dist="$TEMP_DIR/dist"
    local extract="$TEMP_DIR/extract"

    mkdir "$dist" "$extract"
    IFS= read -r version < "$SOURCE_ROOT/VERSION" ||
        beta_fail "VERSION could not be read"
    archive_name="termux-neo-$version.tar.gz"
    checksum_name="$archive_name.sha256"
    package_root="$extract/termux-neo-$version"

    bash "$SOURCE_ROOT/scripts/package-release.sh" "$dist" \
        > "$TEMP_DIR/package.stdout" 2> "$TEMP_DIR/package.stderr" ||
        beta_fail "release artifact build or packaged smoke failed"
    ARTIFACT_SMOKE_RESULT="PASS"

    (
        cd "$dist"
        sha256sum -c "$checksum_name"
    ) > "$TEMP_DIR/checksum.stdout" ||
        beta_fail "external release checksum failed"
    ARTIFACT_CHECKSUM_RESULT="PASS"

    tar --extract --gzip --same-permissions \
        --file "$dist/$archive_name" \
        --directory "$extract"
    [[ -d "$package_root" && ! -L "$package_root" ]] ||
        beta_fail "extracted beta artifact root is invalid"
    (
        cd "$package_root"
        sha256sum -c RELEASE_MANIFEST.sha256
    ) > "$TEMP_DIR/manifest.stdout" ||
        beta_fail "internal release manifest failed"
    ARTIFACT_MANIFEST_RESULT="PASS"

    TMPDIR="$TEMP_DIR" \
        bash "$package_root/scripts/performance-check.sh" --self-test \
        > "$TEMP_DIR/stability.stdout" 2> "$TEMP_DIR/stability.stderr" ||
        beta_fail "packaged stability self-test failed"
    [[ ! -s "$TEMP_DIR/stability.stderr" ]] ||
        beta_fail "packaged stability self-test produced stderr"
    ARTIFACT_STABILITY_RESULT="PASS"

    MATRIX_SOURCE="$package_root"
}

beta_collect_device() {
    local bash_path=""

    [[ "${PREFIX-}" == "/data/data/com.termux/files/usr" ]] ||
        beta_fail "record mode requires the canonical Termux PREFIX"
    [[ "${HOME-}" == "/data/data/com.termux/files/home" ]] ||
        beta_fail "record mode requires the canonical Termux HOME"

    bash_path="$(command -v bash)" || beta_fail "Bash is unavailable"
    [[ "$bash_path" == "$PREFIX/bin/bash" ]] ||
        beta_fail "record mode is not using Termux Bash"

    DEVICE_MANUFACTURER="$(getprop ro.product.manufacturer 2>/dev/null || true)"
    DEVICE_MODEL="$(getprop ro.product.model 2>/dev/null || true)"
    DEVICE_ANDROID="$(getprop ro.build.version.release 2>/dev/null || true)"
    DEVICE_BASH="${BASH_VERSION-}"

    beta_fact_is_safe "$DEVICE_MANUFACTURER" ||
        beta_fail "device manufacturer evidence is invalid"
    beta_fact_is_safe "$DEVICE_MODEL" ||
        beta_fail "device model evidence is invalid"
    beta_fact_is_safe "$DEVICE_ANDROID" ||
        beta_fail "Android release evidence is invalid"
    beta_fact_is_safe "$DEVICE_BASH" ||
        beta_fail "Bash version evidence is invalid"
}

beta_write_report() {
    local version=""
    local output_parent=""

    IFS= read -r version < "$SOURCE_ROOT/VERSION" ||
        beta_fail "VERSION could not be read for the report"
    output_parent="$(dirname "$REPORT_OUTPUT")"
    [[ -d "$output_parent" && ! -L "$output_parent" ]] ||
        beta_fail "report parent is unavailable"
    if [[ -e "$REPORT_OUTPUT" || -L "$REPORT_OUTPUT" ]]; then
        [[ -f "$REPORT_OUTPUT" && ! -L "$REPORT_OUTPUT" ]] ||
            beta_fail "report path is not a regular file"
    fi

    REPORT_TEMP="$(mktemp "$output_parent/.beta-field-report.XXXXXX")" ||
        beta_fail "report temporary file could not be created"
    chmod 600 "$REPORT_TEMP"

    {
        printf '# Public Beta Field Report\n\n'
        printf 'This report was generated by the strict Task 28 field gate. '
        printf 'It contains aggregate, redacted evidence only.\n\n'
        printf '## Environment\n\n'
        printf -- '- Manufacturer: `%s`\n' "$DEVICE_MANUFACTURER"
        printf -- '- Model: `%s`\n' "$DEVICE_MODEL"
        printf -- '- Android release: `%s`\n' "$DEVICE_ANDROID"
        printf -- '- Bash: `%s`\n' "$DEVICE_BASH"
        printf -- '- Termux filesystem layout: canonical\n'
        printf -- '- Real devices recorded at this checkpoint: `1`\n'
        printf -- '- Additional real devices available: none recorded\n\n'
        printf 'One device record is evidence for that environment only. '
        printf 'It is not a general compatibility claim.\n\n'
        printf '## Candidate artifact\n\n'
        printf -- '- Version: `%s`\n' "$version"
        printf -- '- External archive checksum: %s\n' \
            "$ARTIFACT_CHECKSUM_RESULT"
        printf -- '- Internal file manifest: %s\n' \
            "$ARTIFACT_MANIFEST_RESULT"
        printf -- '- Extracted artifact smoke: %s\n' \
            "$ARTIFACT_SMOKE_RESULT"
        printf -- '- Packaged repeated-render stability: %s\n\n' \
            "$ARTIFACT_STABILITY_RESULT"
        printf '## Field matrix\n\n'
        printf '| Scenario | Result | Evidence boundary |\n'
        printf '| --- | --- | --- |\n'
        printf '| Fresh isolated Termux HOME/PREFIX | PASS | Empty paths under `env -i` |\n'
        printf '| Clean install | PASS | Extracted candidate artifact |\n'
        printf '| Existing-config install | PASS | Bytes and mode preserved |\n'
        printf '| Update from prior alpha | PASS | `0.4.0-alpha` to `%s` |\n' \
            "$version"
        printf '| Uninstall with config preserved | PASS | Code removed; config unchanged |\n'
        printf '| Uninstall with config removed | PASS | Explicit `--remove-config` |\n'
        printf '| Offline startup | PASS | Empty network and battery sources |\n'
        printf '| Restricted-permission startup | PASS | Optional probes denied; no raw stderr |\n'
        printf '| Portrait render | PASS | Physical terminal at `%s` columns |\n' \
            "$MATRIX_PORTRAIT_WIDTH"
        printf '| Landscape render | PASS | Physical terminal at `%s` columns |\n\n' \
            "$MATRIX_LANDSCAPE_WIDTH"
        printf 'The lifecycle matrix used isolated temporary HOME/PREFIX paths and '
        printf 'did not mutate the user installation, settings, or `.bashrc`.\n\n'
        printf '## Defect and freeze gate\n\n'
        printf -- '- Open critical security defects: `0`\n'
        printf -- '- Open release-blocking defects: `0`\n'
        printf -- '- Feature freeze: ACTIVE\n'
        printf -- '- Task 28 result: PASS\n\n'
        printf 'Offline and restricted-permission cases use deterministic inputs. '
        printf 'Portrait and landscape widths were observed from the interactive '
        printf 'terminal on the recorded device.\n'
    } > "$REPORT_TEMP"

    chmod 644 "$REPORT_TEMP"
    mv -f -- "$REPORT_TEMP" "$REPORT_OUTPUT"
    REPORT_TEMP=""
}

case "${1-}" in
    --self-test)
        (( $# == 1 )) ||
            beta_fail "usage: bash scripts/beta-field-test.sh --self-test | --record OUTPUT"
        MATRIX_MODE="self-test"
        ;;
    --record)
        (( $# == 2 )) ||
            beta_fail "usage: bash scripts/beta-field-test.sh --self-test | --record OUTPUT"
        MATRIX_MODE="record"
        REPORT_OUTPUT="$2"
        if [[ "$REPORT_OUTPUT" != /* ]]; then
            REPORT_OUTPUT="$PWD/$REPORT_OUTPUT"
        fi
        REPORT_OUTPUT="${REPORT_OUTPUT%/}"
        beta_path_is_safe "$REPORT_OUTPUT" ||
            beta_fail "report output path is unsafe"
        ;;
    *)
        beta_error \
            "usage: bash scripts/beta-field-test.sh --self-test | --record OUTPUT"
        exit 2
        ;;
esac

for required_command in \
    awk bash chmod cmp cp dirname env find getprop grep head ln mkdir mktemp \
    mv rm sed sha256sum sort stat tar timeout tput wc
do
    if [[ "$MATRIX_MODE" == "self-test" && "$required_command" == "getprop" ]]; then
        continue
    fi
    command -v "$required_command" >/dev/null 2>&1 ||
        beta_fail "required command is unavailable: $required_command"
done

[[ -d "$SOURCE_ROOT" && ! -L "$SOURCE_ROOT" &&
   -f "$SOURCE_ROOT/VERSION" &&
   -f "$SOURCE_ROOT/install.sh" &&
   -f "$SOURCE_ROOT/update.sh" &&
   -f "$SOURCE_ROOT/uninstall.sh" ]] ||
    beta_fail "source tree is incomplete"
grep -Fqx 'Open critical security defects: 0' \
    "$SOURCE_ROOT/docs/beta-issues.md" ||
    beta_fail "critical security defect gate is not zero"
grep -Fqx 'Open release-blocking defects: 0' \
    "$SOURCE_ROOT/docs/beta-issues.md" ||
    beta_fail "release-blocking defect gate is not zero"
grep -Fqx 'ACTIVE — 0.9.0-beta' \
    "$SOURCE_ROOT/docs/feature-freeze.md" ||
    beta_fail "feature freeze is not active"

beta_path_is_safe "$TEMP_PARENT" ||
    beta_fail "temporary parent is unsafe"
[[ -d "$TEMP_PARENT" && ! -L "$TEMP_PARENT" && -w "$TEMP_PARENT" ]] ||
    beta_fail "temporary parent is unavailable"

TEMP_DIR="$(mktemp -d "$TEMP_PARENT/tnb.XXXXXX")" ||
    beta_fail "temporary directory could not be created"
chmod 700 "$TEMP_DIR"
MATRIX_ROOT="$TEMP_DIR/matrix"
mkdir "$MATRIX_ROOT"
MATRIX_HOME="$MATRIX_ROOT/files/home"
MATRIX_PREFIX="$MATRIX_ROOT/files/usr"
beta_legacy_shebang_is_safe "$MATRIX_PREFIX/bin/bash" ||
    beta_fail "isolated prefix exceeds the legacy Android shebang limit"

if [[ "$MATRIX_MODE" == "record" ]]; then
    beta_collect_device
    beta_prepare_artifact
else
    MATRIX_SOURCE="$SOURCE_ROOT"
fi

beta_run_matrix

if [[ "$MATRIX_MODE" == "record" ]]; then
    beta_write_report
    printf 'PASS: strict public beta field record created\n'
    printf 'report: %s\n' "$REPORT_OUTPUT"
else
    printf 'PASS: portable public beta field matrix (10 scenarios)\n'
fi

SUCCESS=1
exit 0
