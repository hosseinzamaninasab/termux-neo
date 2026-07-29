#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MODE="${1-full}"

quality_error() {
    printf 'termux-neo quality: %s\n' "${1-quality pipeline failed}" >&2
}

quality_fail() {
    quality_error "${1-quality pipeline failed}"
    exit 1
}

quality_group_for_test() {
    case "${1-}" in
        tests/test_cli.sh|\
        tests/test_colors.sh|\
        tests/test_config.sh|\
        tests/test_content.sh|\
        tests/test_layout.sh|\
        tests/test_prompt.sh|\
        tests/test_prompt_render.sh|\
        tests/test_status.sh|\
        tests/test_status_render.sh|\
        tests/test_ui.sh)
            printf 'unit'
            ;;
        tests/test_compatibility.sh|\
        tests/test_module_fallbacks.sh|\
        tests/test_modules.sh)
            printf 'fixtures'
            ;;
        tests/test_beta.sh|\
        tests/test_diagnostics.sh|\
        tests/test_documentation.sh|\
        tests/test_integration.sh|\
        tests/test_performance.sh|\
        tests/test_quality_pipeline.sh|\
        tests/test_security.sh|\
        tests/test_startup_integration.sh)
            printf 'integration'
            ;;
        tests/test_release_artifact.sh|\
        tests/test_release_discipline.sh)
            printf 'package'
            ;;
        tests/test_install.sh|\
        tests/test_uninstall.sh|\
        tests/test_update.sh)
            printf 'lifecycle'
            ;;
        *)
            return 1
            ;;
    esac
}

quality_list_shell_files() {
    find \
        "$PROJECT_ROOT/install.sh" \
        "$PROJECT_ROOT/update.sh" \
        "$PROJECT_ROOT/uninstall.sh" \
        "$PROJECT_ROOT/bin" \
        "$PROJECT_ROOT/scripts" \
        "$PROJECT_ROOT/src" \
        "$PROJECT_ROOT/tests" \
        -type f \
        \( -name '*.sh' -o -name '*.theme' -o -name 'termux-neo' \) \
        -print0
}

quality_list_tests() {
    local test_path=""
    local relative_path=""

    while IFS= read -r -d '' test_path; do
        relative_path="${test_path#"$PROJECT_ROOT/"}"
        quality_group_for_test "$relative_path" >/dev/null ||
            quality_fail "unassigned test: $relative_path"
        printf '%s\n' "$relative_path"
    done < <(
        find "$PROJECT_ROOT/tests" \
            -maxdepth 1 -type f -name 'test_*.sh' -print0 |
            LC_ALL=C sort -z
    )
}

quality_run_group() {
    local requested_group="${1-}"
    local relative_path=""
    local test_group=""
    local count=0

    printf '\n===== %s tests =====\n' "$requested_group"
    while IFS= read -r relative_path; do
        test_group="$(quality_group_for_test "$relative_path")" ||
            quality_fail "unassigned test: $relative_path"
        [[ "$test_group" == "$requested_group" ]] || continue

        printf '\n--- %s ---\n' "$relative_path"
        (
            cd "$PROJECT_ROOT"
            bash "$relative_path"
        )
        count=$((count + 1))
    done < <(quality_list_tests)

    (( count > 0 )) ||
        quality_fail "test group is empty: $requested_group"
    printf 'PASS: %s group (%s tests)\n' "$requested_group" "$count"
}

case "$MODE" in
    full|--list) ;;
    *)
        quality_error "usage: bash scripts/quality-check.sh [--list]"
        exit 2
        ;;
esac

for required_command in bash find git sort wc
do
    command -v "$required_command" >/dev/null 2>&1 ||
        quality_fail "required command is unavailable: $required_command"
done

[[ -d "$PROJECT_ROOT/.git" ]] ||
    quality_fail "quality pipeline requires a Git working tree"
git_root="$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel 2>/dev/null)" ||
    quality_fail "Git root could not be resolved"
[[ "$git_root" == "$PROJECT_ROOT" ]] ||
    quality_fail "quality pipeline must run from the project Git root"

if [[ "$MODE" == "--list" ]]; then
    quality_list_tests
    exit 0
fi

printf '===== Bash syntax =====\n'
shell_count=0
while IFS= read -r -d '' shell_file; do
    bash -n "$shell_file"
    shell_count=$((shell_count + 1))
done < <(quality_list_shell_files)
(( shell_count > 0 )) || quality_fail "no shell files were discovered"
printf 'PASS: Bash syntax (%s files)\n' "$shell_count"

printf '\n===== Git whitespace =====\n'
git -C "$PROJECT_ROOT" diff --check
printf 'PASS: git diff --check\n'

printf '\n===== Shell static analysis =====\n'
if command -v shellcheck >/dev/null 2>&1; then
    while IFS= read -r -d '' shell_file; do
        shellcheck \
            --shell=bash \
            --severity=error \
            --exclude=SC1090,SC1091 \
            "$shell_file"
    done < <(quality_list_shell_files)
    printf 'PASS: ShellCheck error-level analysis\n'
else
    printf 'SKIP: ShellCheck is unavailable\n'
fi

for group in unit fixtures integration package lifecycle
do
    quality_run_group "$group"
done

test_count="$(quality_list_tests | wc -l)"
[[ "$test_count" =~ ^[0-9]+$ && "$test_count" == "26" ]] ||
    quality_fail "expected 26 assigned tests, found $test_count"

printf '\nPASS: automated quality pipeline (%s test files)\n' "$test_count"
