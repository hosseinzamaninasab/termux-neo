#!/data/data/com.termux/files/usr/bin/bash

source src/utils.sh
source src/dashboard.sh

ui_init
ui_title "TERMUX NEO"

ui_add_row "USER" "Zoro"
ui_add_row "DEVICE" "Samsung Note5"

ui_add_status "Wi-Fi"
ui_add_status "VPN"

ui_render
