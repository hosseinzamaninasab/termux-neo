#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MODE="${1-}"

PERFORMANCE_WARMUP_RUNS=3
PERFORMANCE_SAMPLE_RUNS=15
PERFORMANCE_STABILITY_RUNS=25
PERFORMANCE_HARNESS_CEILING="10s"
PERFORMANCE_RUNTIME_IPC_CEILING="2s"

TEMP_PARENT="${TMPDIR:-/tmp}"
TEMP_PARENT="${TEMP_PARENT%/}"
TEMP_DIR=""

PERFORMANCE_SELFTEST_FD_BEFORE=0
PERFORMANCE_SELFTEST_FD_AFTER=0
PERFORMANCE_SELFTEST_CHILD_CHECK=0

performance_error() {
    printf 'termux-neo performance: %s\n' \
        "${1-performance verification failed}" >&2
}

performance_fail() {
    performance_error "${1-performance verification failed}"
    exit 1
}

performance_path_is_safe() {
    local value="${1-}"

    [[ "$value" == /* ]] || return 1
    [[ "$value" != "/" ]] || return 1
    [[ "$value" != *"//"* ]] || return 1
    [[ "$value" != *"/./"* && "$value" != */. ]] || return 1
    [[ "$value" != *"/../"* && "$value" != */.. ]] || return 1
    [[ ! "$value" =~ [[:cntrl:]] ]]
}

performance_cleanup() {
    local exit_code=$?

    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" &&
          "$TEMP_DIR" == "$TEMP_PARENT"/termux-neo-performance.* ]]
    then
        rm -rf -- "$TEMP_DIR" || true
    fi

    return "$exit_code"
}

trap performance_cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

performance_now_us() {
    local raw="${EPOCHREALTIME-}"
    local seconds=""
    local fraction=""

    [[ "$raw" == *.* ]] ||
        performance_fail "Bash EPOCHREALTIME is unavailable"
    seconds="${raw%%.*}"
    fraction="${raw#*.}000000"
    fraction="${fraction:0:6}"
    [[ "$seconds" =~ ^[0-9]+$ && "$fraction" =~ ^[0-9]{6}$ ]] ||
        performance_fail "Bash EPOCHREALTIME is invalid"

    printf '%s' "$((10#$seconds * 1000000 + 10#$fraction))"
}

performance_fd_count_into() {
    local target_variable="${1-}"
    local -a fd_paths=()

    [[ "$target_variable" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 1
    [[ -d "/proc/self/fd" ]] || return 1

    fd_paths=("/proc/self/fd/"*)
    printf -v "$target_variable" '%s' "${#fd_paths[@]}"
}

performance_children_into() {
    local target_variable="${1-}"
    local children_file="/proc/thread-self/children"
    local process_snapshot="$TEMP_DIR/children.ps"
    local value=""
    local self_pid=""
    local pid=""
    local parent_pid=""
    local command_name=""

    [[ "$target_variable" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 1
    if [[ ! -r "$children_file" ]]; then
        IFS=' ' read -r self_pid _ < /proc/self/stat || return 2
        [[ "$self_pid" =~ ^[0-9]+$ ]] || return 2
        children_file="/proc/$self_pid/task/$self_pid/children"
    fi
    if [[ -r "$children_file" ]]; then
        IFS= read -r value < "$children_file" || true
    else
        command -v ps >/dev/null 2>&1 || return 2
        self_pid="$BASHPID"
        ps -A -o pid=,ppid=,comm= \
            > "$process_snapshot" 2>/dev/null || return 2
        while read -r pid parent_pid command_name; do
            [[ "$parent_pid" == "$self_pid" ]] || continue
            [[ "$command_name" == "ps" ]] && continue
            value="${value:+$value }$pid"
        done < "$process_snapshot"
    fi
    while [[ "$value" == " "* ]]; do
        value="${value# }"
    done
    while [[ "$value" == *" " ]]; do
        value="${value% }"
    done
    printf -v "$target_variable" '%s' "$value"
}

performance_self_test_worker() {
    local worker_home="$TEMP_DIR/self-test-home"
    local original_pwd="$PWD"
    local reference_output=""
    local output=""
    local children_before=""
    local children_after=""
    local child_check=1
    local jobs_before=""
    local jobs_after=""
    local fd_before=0
    local fd_after=0
    local run=0

    mkdir -p "$worker_home"
    export HOME="$worker_home"
    export TERMUX_NEO_CONFIG_PATH="$TEMP_DIR/self-test-missing.conf"
    export NO_COLOR=1

    cd "$PROJECT_ROOT"
    source src/main.sh

    tput() {
        case "${1-}" in
            cols) printf '56' ;;
            colors) printf '0' ;;
            *) return 1 ;;
        esac
    }

    module_network_prepare_render_cache() { :; }
    module_battery_prepare_render_cache() { :; }
    module_device_user() { printf 'Zoro'; }
    module_device_name() { printf 'Samsung Note5'; }
    module_system_name() { printf 'Android 11'; }
    module_network_type() { printf 'Wi-Fi'; }
    module_network_local_ip() { printf '192.168.0.135'; }
    module_network_state() { printf 'UP'; }
    module_vpn_state() { printf 'ON'; }
    module_battery_value() { printf '82+'; }
    module_time_value() { printf '21:35'; }

    performance_fd_count_into fd_before ||
        performance_fail "could not inspect self-test file descriptors"
    if ! performance_children_into children_before; then
        child_check=0
    fi
    jobs_before="$(jobs -pr)"

    (( child_check == 0 )) || [[ -z "$children_before" ]] ||
        performance_fail "self-test began with a persistent child process"
    [[ -z "$jobs_before" ]] ||
        performance_fail "self-test began with a background job"

    for ((run = 1; run <= PERFORMANCE_STABILITY_RUNS; run += 1)); do
        output="$(termux_neo_render_once)" ||
            performance_fail "fixed-input render failed at run $run"
        if (( run == 1 )); then
            reference_output="$output"
        else
            [[ "$output" == "$reference_output" ]] ||
                performance_fail \
                    "fixed-input output changed at run $run"
        fi
    done

    [[ "$(printf '%s\n' "$reference_output" | wc -l)" == "16" ]] ||
        performance_fail "fixed-input output line count is inconsistent"

    performance_fd_count_into fd_after ||
        performance_fail "could not recheck self-test file descriptors"
    if (( child_check == 1 )); then
        performance_children_into children_after ||
            performance_fail "could not recheck self-test child processes"
    fi
    jobs_after="$(jobs -pr)"

    [[ "$fd_after" == "$fd_before" ]] ||
        performance_fail \
            "file-descriptor count changed: $fd_before to $fd_after"
    (( child_check == 0 )) || [[ -z "$children_after" ]] ||
        performance_fail "render left a persistent child process"
    [[ -z "$jobs_after" ]] ||
        performance_fail "render left a background job"

    cd "$original_pwd"
    printf 'fd_before=%s\n' "$fd_before"
    printf 'fd_after=%s\n' "$fd_after"
    printf 'child_check=%s\n' "$child_check"
}

performance_self_test() {
    local summary_file="$TEMP_DIR/self-test-summary"
    local line=""
    local key=""
    local value=""

    (
        performance_self_test_worker
    ) > "$summary_file"

    while IFS= read -r line; do
        key="${line%%=*}"
        value="${line#*=}"
        case "$key" in
            fd_before)
                [[ "$value" =~ ^[0-9]+$ ]] ||
                    performance_fail "self-test FD baseline is invalid"
                PERFORMANCE_SELFTEST_FD_BEFORE="$value"
                ;;
            fd_after)
                [[ "$value" =~ ^[0-9]+$ ]] ||
                    performance_fail "self-test FD result is invalid"
                PERFORMANCE_SELFTEST_FD_AFTER="$value"
                ;;
            child_check)
                [[ "$value" == "0" || "$value" == "1" ]] ||
                    performance_fail \
                        "self-test child-process result is invalid"
                PERFORMANCE_SELFTEST_CHILD_CHECK="$value"
                ;;
            *)
                performance_fail "self-test summary is invalid"
                ;;
        esac
    done < "$summary_file"

    [[ "$PERFORMANCE_SELFTEST_FD_BEFORE" == \
       "$PERFORMANCE_SELFTEST_FD_AFTER" ]] ||
        performance_fail "self-test descriptor result is inconsistent"
}

performance_validate_root() {
    local root="${1-}"

    performance_path_is_safe "$root" || return 1
    [[ -d "$root" && ! -L "$root" ]] || return 1
    [[ -f "$root/VERSION" && ! -L "$root/VERSION" ]] || return 1
    [[ -f "$root/src/main.sh" && ! -L "$root/src/main.sh" ]] || return 1
    [[ -f "$root/config/settings.example.conf" &&
       ! -L "$root/config/settings.example.conf" ]]
}

performance_validate_render_output() {
    local output_file="${1-}"
    local error_file="${2-}"
    local -a lines=()

    [[ -f "$output_file" && ! -L "$output_file" ]] || return 1
    [[ -f "$error_file" && ! -L "$error_file" ]] || return 1
    [[ ! -s "$error_file" ]] || return 1
    mapfile -t lines < "$output_file"
    (( ${#lines[@]} == 16 )) || return 1
    [[ "${lines[1]}" == *"TERMUX NEO"* ]] || return 1
    [[ "${lines[14]}" == *"╭─ "*" • "* ]]
}

performance_run_entry() {
    local root="${1-}"
    local output_file="${2-}"
    local error_file="${3-}"
    local benchmark_home="$TEMP_DIR/benchmark-home"

    mkdir -p "$benchmark_home"
    : > "$output_file"
    : > "$error_file"

    (
        cd "$root"
        HOME="$benchmark_home" \
        TERM="xterm-256color" \
        COLUMNS=80 \
        LINES=24 \
        NO_COLOR=1 \
        TERMUX_NEO_CONFIG_PATH="$root/config/settings.example.conf" \
            timeout \
                --signal=TERM \
                --kill-after=1s \
                "$PERFORMANCE_HARNESS_CEILING" \
                bash "$root/src/main.sh" --no-color
    ) > "$output_file" 2> "$error_file"

    performance_validate_render_output "$output_file" "$error_file"
}

performance_measure_once() {
    local root="${1-}"
    local sample_file="${2-}"
    local label="${3-}"
    local output_file="$TEMP_DIR/$label.stdout"
    local error_file="$TEMP_DIR/$label.stderr"
    local started_us=0
    local finished_us=0
    local elapsed_us=0

    started_us="$(performance_now_us)"
    performance_run_entry "$root" "$output_file" "$error_file" ||
        performance_fail "$label startup run failed"
    finished_us="$(performance_now_us)"
    elapsed_us=$((finished_us - started_us))
    (( elapsed_us > 0 )) ||
        performance_fail "$label startup duration is invalid"

    printf '%s\n' "$elapsed_us" >> "$sample_file"
}

performance_collect_comparison() {
    local baseline_root="${1-}"
    local candidate_root="${2-}"
    local baseline_samples="$TEMP_DIR/baseline.samples"
    local candidate_samples="$TEMP_DIR/candidate.samples"
    local round=0
    local throwaway="$TEMP_DIR/warmup.samples"
    local children=""

    : > "$baseline_samples"
    : > "$candidate_samples"
    : > "$throwaway"

    for ((round = 1; round <= PERFORMANCE_WARMUP_RUNS; round += 1)); do
        performance_measure_once \
            "$baseline_root" "$throwaway" "baseline-warmup"
        performance_measure_once \
            "$candidate_root" "$throwaway" "candidate-warmup"
    done

    for ((round = 1; round <= PERFORMANCE_SAMPLE_RUNS; round += 1)); do
        if (( round % 2 == 1 )); then
            performance_measure_once \
                "$baseline_root" "$baseline_samples" "baseline"
            performance_measure_once \
                "$candidate_root" "$candidate_samples" "candidate"
        else
            performance_measure_once \
                "$candidate_root" "$candidate_samples" "candidate"
            performance_measure_once \
                "$baseline_root" "$baseline_samples" "baseline"
        fi

        if ! performance_children_into children; then
            performance_fail "could not inspect benchmark child processes"
        fi
        [[ -z "$children" ]] ||
            performance_fail "benchmark left a persistent child process"
    done
}

performance_metrics() {
    local sample_file="${1-}"
    local prefix="${2-}"
    local -a sorted=()
    local count=0
    local q1_index=0
    local median_index=0
    local q3_index=0
    local p95_index=0
    local minimum=0
    local q1=0
    local median=0
    local q3=0
    local p95=0
    local maximum=0
    local iqr=0
    local budget=0

    [[ "$prefix" =~ ^[A-Z_]+$ ]] || return 1
    mapfile -t sorted < <(LC_ALL=C sort -n "$sample_file")
    count="${#sorted[@]}"
    (( count == PERFORMANCE_SAMPLE_RUNS )) || return 1
    for value in "${sorted[@]}"; do
        [[ "$value" =~ ^[0-9]+$ ]] || return 1
    done

    q1_index=$(((25 * count + 99) / 100 - 1))
    median_index=$(((50 * count + 99) / 100 - 1))
    q3_index=$(((75 * count + 99) / 100 - 1))
    p95_index=$(((95 * count + 99) / 100 - 1))

    minimum="${sorted[0]}"
    q1="${sorted[q1_index]}"
    median="${sorted[median_index]}"
    q3="${sorted[q3_index]}"
    p95="${sorted[p95_index]}"
    maximum="${sorted[count - 1]}"
    iqr=$((q3 - q1))
    budget=$((q3 + 3 * iqr))
    (( budget >= maximum )) || budget="$maximum"

    printf -v "${prefix}_MIN_US" '%s' "$minimum"
    printf -v "${prefix}_Q1_US" '%s' "$q1"
    printf -v "${prefix}_MEDIAN_US" '%s' "$median"
    printf -v "${prefix}_Q3_US" '%s' "$q3"
    printf -v "${prefix}_P95_US" '%s' "$p95"
    printf -v "${prefix}_MAX_US" '%s' "$maximum"
    printf -v "${prefix}_BUDGET_US" '%s' "$budget"
}

performance_format_ms() {
    local microseconds="${1-}"

    [[ "$microseconds" =~ ^[0-9]+$ ]] || return 1
    printf '%s.%03d' \
        "$((microseconds / 1000))" \
        "$((microseconds % 1000))"
}

performance_write_record() {
    local output_path="${1-}"
    local baseline_root="${2-}"
    local manufacturer="${3-}"
    local model="${4-}"
    local android_release="${5-}"
    local temporary_record="$TEMP_DIR/performance-baseline.md"

    umask 077
    {
        printf '# Reference Performance Baseline\n\n'
        printf 'This file is generated on the verified reference device by '
        printf '`scripts/performance-check.sh`. It records Task 26 and Task 27 '
        printf 'startup measurements taken in one interleaved run.\n\n'
        printf '## Environment\n\n'
        printf -- '- Manufacturer: `%s`\n' "$manufacturer"
        printf -- '- Model: `%s`\n' "$model"
        printf -- '- Android release: `%s`\n' "$android_release"
        printf -- '- Bash: `%s`\n' "${BASH_VERSION%%(*}"
        printf -- '- Baseline source: Task 26 checkout at `%s`\n' \
            "${baseline_root##*/}"
        printf -- '- Candidate source: Task 27 working tree\n'
        printf -- '- Warm-up runs per source: `%s`\n' \
            "$PERFORMANCE_WARMUP_RUNS"
        printf -- '- Measured runs per source: `%s`\n' \
            "$PERFORMANCE_SAMPLE_RUNS"
        printf -- '- Ordering: interleaved and alternated by round\n'
        printf -- '- Metric: elapsed wall-clock time from Bash '
        printf '`EPOCHREALTIME`, including process startup and render output\n\n'
        printf '## Measurements\n\n'
        printf '| Source | Min | Median | p95 | Max |\n'
        printf '| --- | ---: | ---: | ---: | ---: |\n'
        printf '| Task 26 baseline | %s ms | %s ms | %s ms | %s ms |\n' \
            "$(performance_format_ms "$BASELINE_MIN_US")" \
            "$(performance_format_ms "$BASELINE_MEDIAN_US")" \
            "$(performance_format_ms "$BASELINE_P95_US")" \
            "$(performance_format_ms "$BASELINE_MAX_US")"
        printf '| Task 27 candidate | %s ms | %s ms | %s ms | %s ms |\n\n' \
            "$(performance_format_ms "$CANDIDATE_MIN_US")" \
            "$(performance_format_ms "$CANDIDATE_MEDIAN_US")" \
            "$(performance_format_ms "$CANDIDATE_P95_US")" \
            "$(performance_format_ms "$CANDIDATE_MAX_US")"
        printf 'The measured startup budget is `%s ms`. It is the larger of ' \
            "$(performance_format_ms "$BASELINE_BUDGET_US")"
        printf 'the observed Task 26 maximum and its outer Tukey fence '
        printf '(`Q3 + 3 × IQR`). No fixed millisecond target was chosen '
        printf 'before measurement.\n\n'
        printf 'Acceptance requires the Task 27 median not to exceed the '
        printf 'Task 26 p95, and the Task 27 p95 not to exceed the '
        printf 'measurement-derived budget.\n\n'
        printf '```text\n'
        printf 'Task 27 median <= Task 26 p95: PASS\n'
        printf 'Task 27 p95 <= measured budget: PASS\n'
        printf 'Fixed-input repeated renders: PASS (%s exact runs)\n' \
            "$PERFORMANCE_STABILITY_RUNS"
        printf 'Persistent child processes after render: 0\n'
        printf 'Background jobs after render: 0\n'
        printf 'File descriptors before/after: %s / %s\n' \
            "$PERFORMANCE_SELFTEST_FD_BEFORE" \
            "$PERFORMANCE_SELFTEST_FD_AFTER"
        printf '```\n\n'
        printf 'The `%s` benchmark harness ceiling and the runtime `%s` IPC ' \
            "$PERFORMANCE_HARNESS_CEILING" \
            "$PERFORMANCE_RUNTIME_IPC_CEILING"
        printf 'probe ceiling are failure-safety limits, not startup '
        printf 'performance budgets.\n'
    } > "$temporary_record"
    chmod 644 "$temporary_record"
    mv -- "$temporary_record" "$output_path"
    umask 022
}

performance_record() {
    local baseline_root="${1-}"
    local output_path="${2-}"
    local expected_output="$PROJECT_ROOT/docs/performance-baseline.md"
    local manufacturer=""
    local model=""
    local android_release=""

    performance_validate_root "$baseline_root" ||
        performance_fail "Task 26 baseline root is invalid"
    [[ "$output_path" == "$expected_output" ]] ||
        performance_fail "record output must be docs/performance-baseline.md"
    if [[ -e "$output_path" || -L "$output_path" ]]; then
        [[ -f "$output_path" && ! -L "$output_path" ]] ||
            performance_fail "record output path is not a regular file"
    fi

    command -v getprop >/dev/null 2>&1 ||
        performance_fail "getprop is unavailable on the reference device"
    manufacturer="$(getprop ro.product.manufacturer 2>/dev/null || true)"
    model="$(getprop ro.product.model 2>/dev/null || true)"
    android_release="$(
        getprop ro.build.version.release 2>/dev/null || true
    )"
    [[ "${manufacturer,,}" == "samsung" &&
       "$model" == "SM-N920C" &&
       "$android_release" == "11" ]] ||
        performance_fail \
            "reference device must be samsung SM-N920C / Android 11"

    performance_self_test
    if (( PERFORMANCE_SELFTEST_CHILD_CHECK != 1 )); then
        performance_fail \
            "reference-device child-process inspection is unavailable"
    fi
    performance_collect_comparison "$baseline_root" "$PROJECT_ROOT"
    performance_metrics "$TEMP_DIR/baseline.samples" BASELINE ||
        performance_fail "Task 26 startup metrics are invalid"
    performance_metrics "$TEMP_DIR/candidate.samples" CANDIDATE ||
        performance_fail "Task 27 startup metrics are invalid"

    (( CANDIDATE_MEDIAN_US <= BASELINE_P95_US )) ||
        performance_fail \
            "Task 27 median exceeds the measured Task 26 p95"
    (( CANDIDATE_P95_US <= BASELINE_BUDGET_US )) ||
        performance_fail \
            "Task 27 p95 exceeds the measurement-derived budget"

    performance_write_record \
        "$output_path" \
        "$baseline_root" \
        "$manufacturer" \
        "$model" \
        "$android_release"

    printf 'PASS: reference-device performance and stability verification\n'
    printf 'Task 26 median/p95/max: %s / %s / %s ms\n' \
        "$(performance_format_ms "$BASELINE_MEDIAN_US")" \
        "$(performance_format_ms "$BASELINE_P95_US")" \
        "$(performance_format_ms "$BASELINE_MAX_US")"
    printf 'Task 27 median/p95/max: %s / %s / %s ms\n' \
        "$(performance_format_ms "$CANDIDATE_MEDIAN_US")" \
        "$(performance_format_ms "$CANDIDATE_P95_US")" \
        "$(performance_format_ms "$CANDIDATE_MAX_US")"
    printf 'Measurement-derived budget: %s ms\n' \
        "$(performance_format_ms "$BASELINE_BUDGET_US")"
    printf 'Record: %s\n' "$output_path"
}

case "$MODE" in
    --self-test)
        (( $# == 1 )) || {
            performance_error \
                "usage: bash scripts/performance-check.sh --self-test"
            exit 2
        }
        ;;
    --record)
        (( $# == 3 )) || {
            performance_error \
                "usage: bash scripts/performance-check.sh --record BASELINE_ROOT OUTPUT"
            exit 2
        }
        ;;
    *)
        performance_error \
            "usage: bash scripts/performance-check.sh --self-test | --record BASELINE_ROOT OUTPUT"
        exit 2
        ;;
esac

for required_command in bash chmod getprop mkdir mktemp mv rm sort timeout wc
do
    if [[ "$MODE" == "--self-test" && "$required_command" == "getprop" ]]; then
        continue
    fi
    command -v "$required_command" >/dev/null 2>&1 ||
        performance_fail "required command is unavailable: $required_command"
done

performance_path_is_safe "$TEMP_PARENT" ||
    performance_fail "temporary directory parent is unsafe"
[[ -d "$TEMP_PARENT" && ! -L "$TEMP_PARENT" && -w "$TEMP_PARENT" ]] ||
    performance_fail "temporary directory parent is unavailable"

umask 077
TEMP_DIR="$(mktemp -d "$TEMP_PARENT/termux-neo-performance.XXXXXX")" ||
    performance_fail "temporary directory could not be created"
chmod 700 "$TEMP_DIR"
umask 022

case "$MODE" in
    --self-test)
        performance_self_test
        printf 'PASS: deterministic repeated-render stability, jobs, children, and file descriptors\n'
        ;;
    --record)
        performance_record "$2" "$3"
        ;;
esac
