#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${1-"$SOURCE_ROOT/dist"}"

TEMP_DIR=""
REPORT_FILE=""
SUCCESS=0
ARCHIVE_PUBLISHED=0
CHECKSUM_PUBLISHED=0
REPORT_READY=0
REPORT_TEE_PID=""
REPORT_ORIGINAL_STDOUT_FD=""
REPORT_ORIGINAL_STDERR_FD=""

release_error() {
    printf 'termux-neo release: %s\n' "${1-release packaging failed}" >&2
}

release_fail() {
    release_error "${1-release packaging failed}"
    exit 1
}

release_path_is_safe() {
    local value="${1-}"

    [[ "$value" == /* ]] || return 1
    [[ "$value" != "/" ]] || return 1
    [[ "$value" != *"//"* ]] || return 1
    [[ "$value" != *"/./"* && "$value" != */. ]] || return 1
    [[ "$value" != *"/../"* && "$value" != */.. ]] || return 1
    [[ ! "$value" =~ [[:cntrl:]] ]]
}

release_close_report() {
    local tee_status=0

    (( REPORT_READY == 1 )) || return 0

    exec 1>&"$REPORT_ORIGINAL_STDOUT_FD" 2>&"$REPORT_ORIGINAL_STDERR_FD"
    wait "$REPORT_TEE_PID" || tee_status=$?
    exec {REPORT_ORIGINAL_STDOUT_FD}>&-
    exec {REPORT_ORIGINAL_STDERR_FD}>&-
    REPORT_READY=0

    (( tee_status == 0 ))
}

release_cleanup() {
    local exit_code=$?
    local report_status=0

    trap - EXIT
    set +e

    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" &&
          "$TEMP_DIR" == "$OUTPUT_DIR"/.termux-neo-release.* ]]
    then
        rm -rf -- "$TEMP_DIR" || true
    fi

    if (( SUCCESS == 0 )); then
        if (( CHECKSUM_PUBLISHED == 1 )); then
            rm -f -- "$OUTPUT_DIR/$checksum_name" || true
        fi
        if (( ARCHIVE_PUBLISHED == 1 )); then
            rm -f -- "$OUTPUT_DIR/$archive_name" || true
        fi
        printf 'Release packaging failed with status %s\n' "$exit_code" >&2
        [[ -z "$REPORT_FILE" ]] ||
            printf 'release report: %s\n' "$REPORT_FILE" >&2
    fi

    release_close_report || report_status=1
    if (( exit_code == 0 && report_status != 0 )); then
        release_error "release report could not be completed"
        (( CHECKSUM_PUBLISHED == 0 )) ||
            rm -f -- "$OUTPUT_DIR/$checksum_name" || true
        (( ARCHIVE_PUBLISHED == 0 )) ||
            rm -f -- "$OUTPUT_DIR/$archive_name" || true
        exit_code=1
    fi

    exit "$exit_code"
}

trap release_cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

(( $# <= 1 )) || release_fail "usage: bash scripts/package-release.sh [OUTPUT_DIR]"

if [[ "$OUTPUT_DIR" != /* ]]; then
    OUTPUT_DIR="$PWD/$OUTPUT_DIR"
fi
OUTPUT_DIR="${OUTPUT_DIR%/}"
release_path_is_safe "$OUTPUT_DIR" ||
    release_fail "output directory is not a safe absolute path"

for required_command in \
    bash chmod cp dirname find gzip mkdir mktemp mv rm sha256sum sort tar tee
do
    command -v "$required_command" >/dev/null 2>&1 ||
        release_fail "required command is unavailable: $required_command"
done

[[ -d "$SOURCE_ROOT" && ! -L "$SOURCE_ROOT" ]] ||
    release_fail "source root is not a regular directory"
[[ -f "$SOURCE_ROOT/VERSION" && -r "$SOURCE_ROOT/VERSION" ]] ||
    release_fail "VERSION is unavailable"

IFS= read -r version < "$SOURCE_ROOT/VERSION" ||
    release_fail "VERSION could not be read"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] ||
    release_fail "VERSION is invalid"

package_name="termux-neo-$version"
archive_name="$package_name.tar.gz"
checksum_name="$archive_name.sha256"
report_name="$package_name-release-report.txt"

if [[ ! -e "$OUTPUT_DIR" && ! -L "$OUTPUT_DIR" ]]; then
    mkdir -p -- "$OUTPUT_DIR" ||
        release_fail "output directory could not be created"
fi
[[ -d "$OUTPUT_DIR" && ! -L "$OUTPUT_DIR" ]] ||
    release_fail "output path is not a regular directory"

REPORT_FILE="$OUTPUT_DIR/$report_name"

[[ ! -e "$OUTPUT_DIR/$archive_name" &&
   ! -L "$OUTPUT_DIR/$archive_name" ]] ||
    release_fail "archive already exists: $OUTPUT_DIR/$archive_name"
[[ ! -e "$OUTPUT_DIR/$checksum_name" &&
   ! -L "$OUTPUT_DIR/$checksum_name" ]] ||
    release_fail "checksum already exists: $OUTPUT_DIR/$checksum_name"
if [[ -e "$REPORT_FILE" || -L "$REPORT_FILE" ]]; then
    [[ -f "$REPORT_FILE" && ! -L "$REPORT_FILE" ]] ||
        release_fail "release report path is not a regular file"
fi

for required_path in \
    VERSION LICENSE README.md install.sh update.sh uninstall.sh \
    bin config docs src scripts/package-release.sh \
    scripts/beta-field-test.sh scripts/performance-check.sh \
    scripts/smoke-release.sh
do
    [[ -e "$SOURCE_ROOT/$required_path" &&
       ! -L "$SOURCE_ROOT/$required_path" ]] ||
        release_fail "required package path is unavailable: $required_path"
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
        "$SOURCE_ROOT/config" \
        "$SOURCE_ROOT/docs" \
        "$SOURCE_ROOT/src" \
        "$SOURCE_ROOT/scripts/package-release.sh" \
        "$SOURCE_ROOT/scripts/beta-field-test.sh" \
        "$SOURCE_ROOT/scripts/performance-check.sh" \
        "$SOURCE_ROOT/scripts/smoke-release.sh" \
        -type l -print -quit
)" || release_fail "package source could not be inspected"
[[ -z "$unexpected_link" ]] ||
    release_fail "package source contains a symbolic link: $unexpected_link"

bash -n "$SOURCE_ROOT/src/release.sh" ||
    release_fail "release manifest boundary failed syntax validation"
source "$SOURCE_ROOT/src/release.sh"
termux_neo_release_manifest_verify "$SOURCE_ROOT" release_error ||
    release_fail "source release manifest verification failed"

umask 077
if [[ -e "$REPORT_FILE" ]]; then
    chmod 600 -- "$REPORT_FILE" ||
        release_fail "release report mode could not be set"
fi
: > "$REPORT_FILE" || release_fail "release report could not be created"
chmod 600 -- "$REPORT_FILE" ||
    release_fail "release report mode could not be set"
umask 022

exec {REPORT_ORIGINAL_STDOUT_FD}>&1
exec {REPORT_ORIGINAL_STDERR_FD}>&2
exec > >(tee -- "$REPORT_FILE" >&"$REPORT_ORIGINAL_STDOUT_FD") 2>&1
REPORT_TEE_PID=$!
REPORT_READY=1

printf '===== Termux Neo release packaging =====\n'
printf 'version: %s\n' "$version"
printf 'source: %s\n' "$SOURCE_ROOT"
printf 'output: %s\n\n' "$OUTPUT_DIR"

for shell_file in \
    "$SOURCE_ROOT/install.sh" \
    "$SOURCE_ROOT/update.sh" \
    "$SOURCE_ROOT/uninstall.sh" \
    "$SOURCE_ROOT/scripts/package-release.sh" \
    "$SOURCE_ROOT/scripts/beta-field-test.sh" \
    "$SOURCE_ROOT/scripts/performance-check.sh" \
    "$SOURCE_ROOT/scripts/smoke-release.sh" \
    "$SOURCE_ROOT"/src/*.sh \
    "$SOURCE_ROOT"/src/modules/*.sh \
    "$SOURCE_ROOT/bin/termux-neo"
do
    bash -n "$shell_file" ||
        release_fail "shell syntax check failed: ${shell_file#"$SOURCE_ROOT/"}"
done

TEMP_DIR="$(mktemp -d "$OUTPUT_DIR/.termux-neo-release.XXXXXX")" ||
    release_fail "temporary release directory could not be created"
stage_parent="$TEMP_DIR/stage"
package_root="$stage_parent/$package_name"
verify_root="$TEMP_DIR/verify"
archive_temp="$TEMP_DIR/$archive_name"
checksum_temp="$TEMP_DIR/$checksum_name"

mkdir "$stage_parent" "$package_root" "$package_root/scripts" "$verify_root"
cp -p \
    "$SOURCE_ROOT/VERSION" \
    "$SOURCE_ROOT/LICENSE" \
    "$SOURCE_ROOT/README.md" \
    "$SOURCE_ROOT/install.sh" \
    "$SOURCE_ROOT/update.sh" \
    "$SOURCE_ROOT/uninstall.sh" \
    "$package_root/"
cp -pR \
    "$SOURCE_ROOT/bin" \
    "$SOURCE_ROOT/config" \
    "$SOURCE_ROOT/docs" \
    "$SOURCE_ROOT/src" \
    "$package_root/"
cp -p \
    "$SOURCE_ROOT/scripts/package-release.sh" \
    "$SOURCE_ROOT/scripts/beta-field-test.sh" \
    "$SOURCE_ROOT/scripts/performance-check.sh" \
    "$SOURCE_ROOT/scripts/smoke-release.sh" \
    "$package_root/scripts/"

find "$package_root" -type d -exec chmod 755 {} +
find "$package_root" -type f -exec chmod 644 {} +
chmod 755 \
    "$package_root/install.sh" \
    "$package_root/update.sh" \
    "$package_root/uninstall.sh" \
    "$package_root/scripts/package-release.sh" \
    "$package_root/scripts/beta-field-test.sh" \
    "$package_root/scripts/performance-check.sh" \
    "$package_root/scripts/smoke-release.sh" \
    "$package_root/bin/termux-neo" \
    "$package_root"/src/*.sh \
    "$package_root"/src/modules/*.sh

(
    cd "$package_root"
    while IFS= read -r -d '' package_file; do
        sha256sum -- "$package_file"
    done < <(
        LC_ALL=C find . -type f ! -name RELEASE_MANIFEST.sha256 -print0 |
            LC_ALL=C sort -z
    )
) > "$package_root/RELEASE_MANIFEST.sha256"
chmod 644 "$package_root/RELEASE_MANIFEST.sha256"

termux_neo_release_manifest_verify "$package_root" release_error ||
    release_fail "staged release manifest verification failed"

tar \
    --sort=name \
    --format=ustar \
    --mtime='@0' \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    -cf "$TEMP_DIR/$package_name.tar" \
    -C "$stage_parent" \
    "$package_name"
gzip -n -9 "$TEMP_DIR/$package_name.tar"

gzip -t "$archive_temp"
tar --extract --gzip --same-permissions \
    --file "$archive_temp" \
    --directory "$verify_root"
[[ -d "$verify_root/$package_name" &&
   ! -L "$verify_root/$package_name" ]] ||
    release_fail "archive root is invalid"
termux_neo_release_manifest_verify "$verify_root/$package_name" release_error ||
    release_fail "archive release manifest verification failed"
bash "$verify_root/$package_name/scripts/smoke-release.sh" ||
    release_fail "archive smoke verification failed"

archive_checksum="$(sha256sum -- "$archive_temp")"
archive_checksum="${archive_checksum%% *}"
[[ "$archive_checksum" =~ ^[0-9a-f]{64}$ ]] ||
    release_fail "archive checksum is invalid"
printf '%s  %s\n' "$archive_checksum" "$archive_name" > "$checksum_temp"
chmod 644 "$archive_temp" "$checksum_temp"

mv -- "$archive_temp" "$OUTPUT_DIR/$archive_name"
ARCHIVE_PUBLISHED=1
mv -- "$checksum_temp" "$OUTPUT_DIR/$checksum_name"
CHECKSUM_PUBLISHED=1

printf '\nPASS: reproducible release artifact created and verified\n'
printf 'archive: %s\n' "$OUTPUT_DIR/$archive_name"
printf 'checksum: %s\n' "$OUTPUT_DIR/$checksum_name"
printf 'release report: %s\n' "$REPORT_FILE"

SUCCESS=1
exit 0
