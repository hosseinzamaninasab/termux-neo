#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - Dashboard Renderer
# ==========================================================


ui_render_top() {
    echo "╔$(printf '═%.0s' $(seq 1 "$UI_WIDTH"))╗"
}


ui_render_title() {

    printf "║%*s%s%*s║\n" \
        $(((UI_WIDTH-${#UI_TITLE})/2)) "" \
        "$UI_TITLE" \
        $(((UI_WIDTH-${#UI_TITLE})/2)) ""

}


ui_render_separator() {
    echo "║$(printf '─%.0s' $(seq 1 "$UI_WIDTH"))║"
}


ui_render_rows() {

    for row in "${UI_ROWS[@]}"
    do
        IFS="|" read -r key value <<< "$row"

        printf "║  %-9s %-25s║\n" \
            "$key" \
            "$value"
    done

}


ui_render_bottom() {
    echo "╚$(printf '═%.0s' $(seq 1 "$UI_WIDTH"))╝"
}


ui_render() {

    ui_render_top

    ui_render_title

    ui_render_separator

    ui_render_rows

    ui_render_bottom

}
