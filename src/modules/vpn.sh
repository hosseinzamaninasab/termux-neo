#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - VPN Data Module
# ==========================================================

module_vpn_state() {
    local interface

    while IFS= read -r interface
    do
        case "$interface" in
            tun*|tap*|wg*|ppp*|tailscale*|zt*)
                printf 'ON'
                return 0
                ;;
        esac
    done < <(module_interface_names)

    printf 'OFF'
}
