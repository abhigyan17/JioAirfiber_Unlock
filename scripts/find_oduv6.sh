#!/bin/ash

# Check for MAC argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 <MAC_ADDRESS>"
    exit 1
fi

mac=$(echo "$1" | tr 'A-F' 'a-f')

# Validate MAC format (12 hex digits, no separators)
case "$mac" in
    [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
    *)
        echo "Invalid MAC address format. Must be 12 hex digits, no colons or dashes."
        exit 1
        ;;
esac

# Split into bytes
m1=${mac:0:2}
m2=${mac:2:2}
m3=${mac:4:2}
m4=${mac:6:2}
m5=${mac:8:2}
m6=${mac:10:2}

# Flip 7th bit of first byte
flip_byte=$(printf "%02x" $((0x$m1 ^ 0x02)))

# Construct link-local IPv6 (EUI-64)
ipv6="fe80::${flip_byte}${m2}:${m3}ff:fe${m4}:${m5}${m6}"

echo "[*] Generated IPv6 from MAC: $ipv6"

# Try interfaces eth0 to eth5
for i in 0 1 2 3 4 5; do
    iface="eth$i"
    echo "[*] Trying interface: $iface"

    result=$(curl -g -6 -v --interface "$iface" "https://[$ipv6]/" --insecure --max-time 5 2>&1)
    code=$(echo "$result" | sed -n 's/.*< HTTP\/[^ ]* \([0-9][0-9][0-9]\).*/\1/p')

    case "$code" in
        ''|*[!0-9]*) code=0 ;;
    esac

    if [ "$code" -ge 200 ] 2>/dev/null && [ "$code" -lt 400 ] 2>/dev/null; then
        echo ""
        echo "[+] SUCCESS on interface: $iface (HTTP $code)"
        echo "------------------------------------------------------------"
        echo "✅ ODU Web UI is accessible at:"
        echo "   https://[$ipv6%$iface]:443"
        echo ""
        echo "🔐 To create an SSH tunnel from your local device, run:"
        echo "   ssh -L 8443:[$ipv6%$iface]:443 root@192.168.31.1"
        echo "Then access it at https://localhost:8443"
        echo "------------------------------------------------------------"
        exit 0
    else
        echo "[-] Failed on $iface (HTTP $code)"
    fi
done

echo "[!] Could not reach ODU on any interface."
exit 1
