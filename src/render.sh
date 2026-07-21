#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - Shared Rendering Primitives
# ==========================================================

# ----------------------------------------------------------
# Render Left Margin
# ----------------------------------------------------------

ui_render_margin() {
    printf "%*s" "$UI_MARGIN_LEFT" ""
}
