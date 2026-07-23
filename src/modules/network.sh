#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# Termux Neo - Network Data Module
# ==========================================================

module_is_ipv4_address() {
    local address="${1-}"
    local a b c d

    [[ "$address" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    IFS='.' read -r a b c d <<< "$address"

    (( a >= 0 && a <= 255 )) &&
    (( b >= 0 && b <= 255 )) &&
    (( c >= 0 && c <= 255 )) &&
    (( d >= 0 && d <= 255 ))
}

module_network_primary_interface() {
    local interface=""
    local network_root=""
    local route=""
    local state=""

    if module_command_exists ip; then
        route="$(ip route show default 2>/dev/null | head -n 1 || true)"
        if [[ "$route" =~ [[:space:]]dev[[:space:]]([^[:space:]]+) ]]; then
            interface="${BASH_REMATCH[1]}"
        fi
    fi

    if [[ -z "$interface" ]]; then
        network_root="$(module_network_class_root 2>/dev/null || true)"
        [[ -n "$network_root" ]] || return 1

        while IFS= read -r interface
        do
            [[ -r "$network_root/$interface/operstate" ]] || continue
            state="$(cat "$network_root/$interface/operstate" 2>/dev/null || true)"
            case "$state" in
                up|unknown)
                    printf '%s' "$interface"
                    return 0
                    ;;
            esac
        done < <(module_interface_names)
        interface=""
    fi

    [[ -n "$interface" ]] || return 1
    printf '%s' "$interface"
}

module_network_state() {
    local interface=""
    interface="$(module_network_primary_interface 2>/dev/null || true)"
    [[ -n "$interface" ]] && printf 'UP' || printf 'DOWN'
}

module_network_type() {
    local interface=""
    interface="$(module_network_primary_interface 2>/dev/null || true)"

    case "$interface" in
        wlan*|wifi*) printf 'Wi-Fi' ;;
        rmnet*|ccmni*|pdp*|wwan*) printf 'Mobile' ;;
        eth*) printf 'Ethernet' ;;
        tun*|tap*|wg*|ppp*) printf 'VPN' ;;
        "") printf 'Offline' ;;
        *) module_clean_value "$interface" "Network" ;;
    esac
}

module_network_parse_ifconfig_ipv4() {
    local target_interface="${1-}"
    local raw_output="${2-}"
    local candidate=""

    candidate="$(
        printf '%s\n' "$raw_output" |
        awk -v target="$target_interface" '
            /^[[:alnum:]_.:-]+:/ {
                current=$1
                sub(/:$/, "", current)
            }
            {
                if (target != "" && current != target) next
                for (i=1; i<=NF; i++) {
                    if ($i == "inet" && i < NF) {
                        value=$(i + 1)
                        sub(/^addr:/, "", value)
                        print value
                        exit
                    }
                    if ($i ~ /^addr:/) {
                        value=$i
                        sub(/^addr:/, "", value)
                        print value
                        exit
                    }
                }
            }
        '
    )"

    if module_is_ipv4_address "$candidate" &&
       [[ "$candidate" != "0.0.0.0" ]] &&
       [[ "$candidate" != 127.* ]]
    then
        printf '%s' "$candidate"
        return 0
    fi

    return 1
}

module_network_local_ip_record() {
    local interface=""
    local raw=""
    local value=""

    interface="$(module_network_primary_interface 2>/dev/null || true)"

    if module_command_exists ip; then
        value="$(
            ip -o -4 addr show scope global 2>/dev/null |
            awk 'NR == 1 { sub(/\/.*/, "", $4); print $4; exit }'
        )"
        if module_is_ipv4_address "$value" && [[ "$value" != 127.* ]]; then
            printf 'ip|%s' "$value"
            return 0
        fi
    fi

    if module_command_exists ifconfig; then
        if [[ -n "$interface" ]]; then
            raw="$(ifconfig "$interface" 2>/dev/null || true)"
            value="$(module_network_parse_ifconfig_ipv4 "$interface" "$raw" 2>/dev/null || true)"
        fi

        if [[ -z "$value" ]]; then
            raw="$(ifconfig 2>/dev/null || true)"
            value="$(module_network_parse_ifconfig_ipv4 "$interface" "$raw" 2>/dev/null || true)"
        fi

        if [[ -n "$value" ]]; then
            printf 'ifconfig|%s' "$value"
            return 0
        fi
    fi

    if [[ -n "$interface" ]]; then
        for key in "dhcp.${interface}.ipaddress" "net.${interface}.local-ip" "dhcp.wlan0.ipaddress"
        do
            value="$(module_read_getprop "$key" 2>/dev/null || true)"
            if module_is_ipv4_address "$value" && [[ "$value" != 127.* ]]; then
                printf 'getprop|%s' "$value"
                return 0
            fi
        done
    fi

    printf 'unavailable|Unavailable'
}

module_network_local_ip() {
    local record=""

    record="$(module_network_local_ip_record 2>/dev/null || true)"
    [[ "$record" == *"|"* ]] || {
        printf 'Unavailable'
        return 0
    }

    printf '%s' "${record#*|}"
}

module_network_local_ip_source() {
    local record=""
    local source=""

    record="$(module_network_local_ip_record 2>/dev/null || true)"
    [[ "$record" == *"|"* ]] || {
        printf 'unavailable'
        return 0
    }

    source="${record%%|*}"
    case "$source" in
        ip|ifconfig|getprop|unavailable)
            printf '%s' "$source"
            ;;
        *)
            printf 'unavailable'
            ;;
    esac
}
