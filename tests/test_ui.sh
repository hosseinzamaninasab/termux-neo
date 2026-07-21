#!/data/data/com.termux/files/usr/bin/bash
set -e

source src/utils.sh
source src/layout.sh
source src/render.sh
source src/dashboard.sh
source src/status.sh

ui_init

TERM_WIDTH=56

ui_calculate_width
ui_calculate_margin

ui_title "TERMUX NEO"

ui_add_row "USER" "Zoro"
ui_add_row "DEVICE" "Samsung Note5"

ui_add_status "NET" "UP"
ui_add_status "VPN" "ON"
ui_add_status "BAT" "82+"
ui_add_status "TIME" "21:35"

ui_render

printf '\n'
ui_render_status
