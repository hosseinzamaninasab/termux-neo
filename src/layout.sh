#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - Layout Engine
# ==========================================================

# ----------------------------------------------------------
# Validate Layout
# ----------------------------------------------------------

ui_validate_layout() {
    local field_gap_width
    local row_width
    local dashboard_total_width
    local expected_margin_left

    field_gap_width="${#UI_FIELD_GAP}"

    (( TERM_WIDTH > 0 )) || return 1
    (( UI_WIDTH > 0 )) || return 1
    (( UI_BORDER_TOTAL_WIDTH > 0 )) || return 1

    (( UI_PADDING_LEFT >= 0 )) || return 1
    (( UI_KEY_WIDTH > 0 )) || return 1
    (( field_gap_width > 0 )) || return 1
    (( UI_VALUE_WIDTH > 0 )) || return 1
    (( UI_MARGIN_LEFT >= 0 )) || return 1

    row_width=$((
        UI_PADDING_LEFT
        + UI_KEY_WIDTH
        + field_gap_width
        + UI_VALUE_WIDTH
    ))

    (( row_width == UI_WIDTH )) || return 1

    dashboard_total_width=$((
        UI_WIDTH
        + UI_BORDER_TOTAL_WIDTH
    ))

    (( dashboard_total_width <= TERM_WIDTH )) || return 1

    expected_margin_left=$((
        (TERM_WIDTH - dashboard_total_width) / 2
    ))

    (( UI_MARGIN_LEFT == expected_margin_left ))
}


# ----------------------------------------------------------
# Calculate Dashboard Width
# ----------------------------------------------------------

ui_calculate_width() {
    local available_width
    local field_gap_width
    local calculated_ui_width
    local calculated_value_width

    # Prevent stale layout values after a failed calculation.
    UI_WIDTH=0
    UI_VALUE_WIDTH=0
    UI_MARGIN_LEFT=0

    (( TERM_WIDTH > 0 )) || return 1
    (( UI_BORDER_TOTAL_WIDTH > 0 )) || return 1
    (( UI_MIN_WIDTH > 0 )) || return 1
    (( UI_DEFAULT_WIDTH >= UI_MIN_WIDTH )) || return 1
    (( UI_PADDING_LEFT >= 0 )) || return 1
    (( UI_KEY_WIDTH > 0 )) || return 1

    field_gap_width="${#UI_FIELD_GAP}"

    (( field_gap_width > 0 )) || return 1

    available_width=$((TERM_WIDTH - UI_BORDER_TOTAL_WIDTH))

    (( available_width >= UI_MIN_WIDTH )) || return 1

    if (( available_width < UI_DEFAULT_WIDTH )); then
        calculated_ui_width="$available_width"
    else
        calculated_ui_width="$UI_DEFAULT_WIDTH"
    fi

    calculated_value_width=$((
        calculated_ui_width
        - UI_PADDING_LEFT
        - UI_KEY_WIDTH
        - field_gap_width
    ))

    (( calculated_value_width > 0 )) || return 1

    UI_WIDTH="$calculated_ui_width"
    UI_VALUE_WIDTH="$calculated_value_width"
}


# ----------------------------------------------------------
# Calculate Dashboard Margin
# ----------------------------------------------------------

ui_calculate_margin() {
    local dashboard_total_width
    local available_space

    # Prevent a previous margin from surviving a failed calculation.
    UI_MARGIN_LEFT=0

    (( TERM_WIDTH > 0 )) || return 1
    (( UI_WIDTH > 0 )) || return 1
    (( UI_BORDER_TOTAL_WIDTH > 0 )) || return 1

    dashboard_total_width=$((
        UI_WIDTH
        + UI_BORDER_TOTAL_WIDTH
    ))

    (( dashboard_total_width <= TERM_WIDTH )) || return 1

    available_space=$((
        TERM_WIDTH
        - dashboard_total_width
    ))

    UI_MARGIN_LEFT=$((available_space / 2))

    ui_validate_layout
}

# ----------------------------------------------------------
# Format Row Value
# ----------------------------------------------------------

ui_ellipsize_value() {
    local value="$1"
    local ellipsis_width
    local visible_width

    (( UI_VALUE_WIDTH > 0 )) || return 1

    ellipsis_width="${#UI_ELLIPSIS}"

    (( ellipsis_width > 0 )) || return 1
    (( ellipsis_width <= UI_VALUE_WIDTH )) || return 1

    if (( ${#value} <= UI_VALUE_WIDTH )); then
        printf '%s' "$value"
        return 0
    fi

    visible_width=$((UI_VALUE_WIDTH - ellipsis_width))

    printf '%s%s' \
        "${value:0:visible_width}" \
        "$UI_ELLIPSIS"
}


# ----------------------------------------------------------
# Validate Render Content
# ----------------------------------------------------------

ui_validate_content() {
    local row
    local key
    local value
    local ellipsis_width

    ellipsis_width="${#UI_ELLIPSIS}"

    (( ellipsis_width > 0 )) || return 1
    (( ellipsis_width <= UI_VALUE_WIDTH )) || return 1

    (( ${#UI_TITLE} <= UI_WIDTH )) || return 1

    [[ "$UI_TITLE" != *$'\n'* ]] || return 1
    [[ "$UI_TITLE" != *$'\r'* ]] || return 1
    [[ "$UI_TITLE" != *$'\t'* ]] || return 1

    [[ "$UI_ELLIPSIS" != *$'\n'* ]] || return 1
    [[ "$UI_ELLIPSIS" != *$'\r'* ]] || return 1
    [[ "$UI_ELLIPSIS" != *$'\t'* ]] || return 1

    for row in "${UI_ROWS[@]}"
    do
        [[ "$row" != *$'\n'* ]] || return 1
        [[ "$row" != *$'\r'* ]] || return 1
        [[ "$row" != *$'\t'* ]] || return 1

        IFS="|" read -r key value <<< "$row"

        (( ${#key} <= UI_KEY_WIDTH )) || return 1
    done
}

# ==========================================================
# Status Layout Engine
# ==========================================================

ui_repeat_character() {
    local character="$1"
    local count="$2"
    local output=""
    local index

    (( count >= 0 )) || return 1
    [[ -n "$character" ]] || return 1

    for ((index = 0; index < count; index++)); do
        output+="$character"
    done

    printf '%s' "$output"
}

ui_validate_status_content() {
    local entry label value

    [[ -n "$UI_STATUS_FIELD_SEPARATOR" ]] || return 1
    [[ -n "$UI_STATUS_ITEM_SEPARATOR" ]] || return 1
    [[ -n "$UI_STATUS_RULE_CHAR" ]] || return 1
    [[ -n "$UI_STATUS_RULE_GAP" ]] || return 1

    (( UI_STATUS_RULE_SEGMENT_WIDTH > 0 )) || return 1

    for entry in "${UI_STATUS[@]}"; do
        # Validate the raw stored entry before splitting it.
        [[ "$entry" != *$'\n'* ]] || return 1
        [[ "$entry" != *$'\r'* ]] || return 1
        [[ "$entry" != *$'\t'* ]] || return 1
        [[ "$entry" != *$'\e'* ]] || return 1

        # Exactly one internal delimiter must exist.
        [[ "$entry" == *"|"* ]] || return 1

        label="${entry%%|*}"
        value="${entry#*|}"

        [[ "$value" != *"|"* ]] || return 1

        [[ -n "$label" ]] || return 1
        [[ -n "$value" ]] || return 1

        [[ "$label" =~ ^[A-Z][A-Z0-9_]*$ ]] || return 1
    done
}

ui_join_status_tokens() {
    local output=""
    local token

    for token in "$@"; do
        if [[ -n "$output" ]]; then
            output+="$UI_STATUS_ITEM_SEPARATOR"
        fi

        output+="$token"
    done

    printf '%s' "$output"
}

ui_build_status_text() {
    local entry label value token candidate joined
    local truncated=0
    local last_index
    local -a tokens=()
    local -a retained=()

    UI_STATUS_TEXT=""

    (( UI_STATUS_WIDTH > 0 )) || return 1

    if (( ${#UI_STATUS[@]} == 0 )); then
        return 0
    fi

    ui_validate_status_content || return 1

    for entry in "${UI_STATUS[@]}"; do
        label="${entry%%|*}"
        value="${entry#*|}"

        token="${label}${UI_STATUS_FIELD_SEPARATOR}${value}"

        (( ${#token} <= UI_STATUS_WIDTH )) || return 1

        tokens+=("$token")
    done

    for token in "${tokens[@]}"; do
        candidate=$(ui_join_status_tokens "${retained[@]}" "$token")

        if (( ${#candidate} <= UI_STATUS_WIDTH )); then
            retained+=("$token")
        else
            truncated=1
            break
        fi
    done

    if (( truncated == 0 )); then
        UI_STATUS_TEXT=$(ui_join_status_tokens "${retained[@]}")
        return 0
    fi

    while (( ${#retained[@]} > 0 )); do
        joined=$(ui_join_status_tokens "${retained[@]}")
        candidate="${joined}${UI_STATUS_ITEM_SEPARATOR}${UI_ELLIPSIS}"

        if (( ${#candidate} <= UI_STATUS_WIDTH )); then
            UI_STATUS_TEXT="$candidate"
            return 0
        fi

        last_index=$((${#retained[@]} - 1))
        unset 'retained[last_index]'
    done

    return 1
}

ui_build_status_rule() {
    local remaining segment_width gap_width chunk

    UI_STATUS_RULE=""

    (( UI_STATUS_WIDTH > 0 )) || return 1
    (( UI_STATUS_RULE_SEGMENT_WIDTH > 0 )) || return 1

    [[ -n "$UI_STATUS_RULE_CHAR" ]] || return 1
    [[ -n "$UI_STATUS_RULE_GAP" ]] || return 1

    gap_width="${#UI_STATUS_RULE_GAP}"
    (( gap_width > 0 )) || return 1

    remaining="$UI_STATUS_WIDTH"

    while (( remaining > 0 )); do
        segment_width="$UI_STATUS_RULE_SEGMENT_WIDTH"

        if (( segment_width > remaining )); then
            segment_width="$remaining"
        fi

        chunk=$(ui_repeat_character \
            "$UI_STATUS_RULE_CHAR" \
            "$segment_width") || return 1

        UI_STATUS_RULE+="$chunk"
        remaining=$((remaining - segment_width))

        (( remaining > 0 )) || break

        if (( remaining <= gap_width )); then
            chunk=$(ui_repeat_character \
                "$UI_STATUS_RULE_CHAR" \
                "$remaining") || return 1

            UI_STATUS_RULE+="$chunk"
            remaining=0
            break
        fi

        UI_STATUS_RULE+="$UI_STATUS_RULE_GAP"
        remaining=$((remaining - gap_width))
    done

    (( ${#UI_STATUS_RULE} == UI_STATUS_WIDTH )) || return 1
    [[ "$UI_STATUS_RULE" != *" " ]] || return 1
}

ui_calculate_status_layout() {
    local available_padding

    UI_STATUS_WIDTH=0
    UI_STATUS_TEXT=""
    UI_STATUS_RULE=""

    UI_STATUS_PADDING_LEFT=0
    UI_STATUS_PADDING_RIGHT=0

    ui_validate_layout || return 1

    UI_STATUS_WIDTH=$((UI_WIDTH + UI_BORDER_TOTAL_WIDTH))

    (( UI_STATUS_WIDTH > 0 )) || return 1
    (( UI_STATUS_WIDTH <= TERM_WIDTH )) || return 1

    if (( ${#UI_STATUS[@]} == 0 )); then
        return 0
    fi

    ui_build_status_text || return 1
    ui_build_status_rule || return 1

    available_padding=$((UI_STATUS_WIDTH - ${#UI_STATUS_TEXT}))
    (( available_padding >= 0 )) || return 1

    UI_STATUS_PADDING_LEFT=$((available_padding / 2))
    UI_STATUS_PADDING_RIGHT=$((available_padding - UI_STATUS_PADDING_LEFT))

    ((
        UI_STATUS_PADDING_LEFT
        + ${#UI_STATUS_TEXT}
        + UI_STATUS_PADDING_RIGHT
        == UI_STATUS_WIDTH
    ))
}

# ==========================================================
# Prompt Layout
# ==========================================================

ui_validate_prompt_content() {
    local value

    [[ -n "$UI_PROMPT_TOP_LEFT" ]] || return 1
    [[ -n "$UI_PROMPT_BOTTOM_LEFT" ]] || return 1
    [[ -n "$UI_PROMPT_HORIZONTAL" ]] || return 1
    [[ -n "$UI_PROMPT_SYMBOL" ]] || return 1
    [[ -n "$UI_PROMPT_ITEM_SEPARATOR" ]] || return 1
    [[ -n "$UI_PROMPT_USER" ]] || return 1
    [[ -n "$UI_PROMPT_PATH" ]] || return 1
    [[ "$UI_PROMPT_USER" =~ ^[[:alnum:]_.-]+$ ]] || return 1

    for value in "$UI_PROMPT_USER" "$UI_PROMPT_PATH"; do
        [[ "$value" != *$'\n'* ]] || return 1
        [[ "$value" != *$'\r'* ]] || return 1
        [[ "$value" != *$'\t'* ]] || return 1
        [[ "$value" != *$'\e'* ]] || return 1
        [[ "$value" != *"•"* ]] || return 1
    done
}

ui_fit_prompt_path() {
    local path="${1-}"
    local max_width="${2-0}"
    local stripped suffix="" candidate part keep index
    local -a parts

    (( max_width > 0 )) || return 1

    if (( ${#path} <= max_width )); then
        printf '%s' "$path"
        return 0
    fi

    (( max_width >= 2 )) || return 1

    stripped="${path#/}"
    IFS='/' read -r -a parts <<< "$stripped"

    for (( index=${#parts[@]} - 1; index >= 0; index-- )); do
        part="${parts[index]}"
        [[ -n "$part" ]] || continue
        [[ "$part" != "~" ]] || continue

        if [[ -n "$suffix" ]]; then
            candidate="…/${part}/${suffix}"
        else
            candidate="…/${part}"
        fi

        if (( ${#candidate} <= max_width )); then
            suffix="${part}${suffix:+/$suffix}"
        else
            break
        fi
    done

    if [[ -n "$suffix" ]]; then
        printf '…/%s' "$suffix"
        return 0
    fi

    keep=$((max_width - 1))
    printf '…%s' "${path: -keep}"
}

ui_build_prompt_lines() {
    local prefix available_path_width fitted_path

    prefix="${UI_PROMPT_TOP_LEFT}${UI_PROMPT_HORIZONTAL} ${UI_PROMPT_USER}${UI_PROMPT_ITEM_SEPARATOR}"
    available_path_width=$((UI_PROMPT_WIDTH - ${#prefix}))
    (( available_path_width > 0 )) || return 1

    fitted_path=$(ui_fit_prompt_path "$UI_PROMPT_PATH" "$available_path_width") || return 1

    UI_PROMPT_LINE_TOP="${prefix}${fitted_path}"
    UI_PROMPT_LINE_BOTTOM="${UI_PROMPT_BOTTOM_LEFT}${UI_PROMPT_HORIZONTAL}${UI_PROMPT_SYMBOL}"

    (( ${#UI_PROMPT_LINE_TOP} <= UI_PROMPT_WIDTH )) || return 1
    (( ${#UI_PROMPT_LINE_BOTTOM} <= UI_PROMPT_WIDTH )) || return 1
}

ui_calculate_prompt_layout() {
    UI_PROMPT_WIDTH=0
    UI_PROMPT_LINE_TOP=""
    UI_PROMPT_LINE_BOTTOM=""

    ui_validate_prompt_content || return 1
    ui_calculate_width || return 1
    ui_calculate_margin || return 1

    UI_PROMPT_WIDTH=$((UI_WIDTH + UI_BORDER_TOTAL_WIDTH))

    ui_build_prompt_lines || {
        UI_PROMPT_WIDTH=0
        UI_PROMPT_LINE_TOP=""
        UI_PROMPT_LINE_BOTTOM=""
        return 1
    }
}
