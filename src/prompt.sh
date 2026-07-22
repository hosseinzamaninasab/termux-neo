#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - Prompt Renderer
# ==========================================================

ui_render_prompt_top() {
    ui_render_margin
    ui_render_styled prompt "$UI_PROMPT_LINE_TOP"
    printf '\n'
}

ui_render_prompt_bottom() {
    ui_render_margin
    ui_render_styled prompt "$UI_PROMPT_LINE_BOTTOM"
    printf '\n'
}

ui_render_prompt() {
    if [[ -z "$UI_PROMPT_USER" && -z "$UI_PROMPT_PATH" ]]; then
        return 0
    fi

    ui_calculate_prompt_layout || return 1

    ui_render_prompt_top
    ui_render_prompt_bottom
}
