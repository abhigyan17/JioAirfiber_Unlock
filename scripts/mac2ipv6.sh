#!/bin/bash

# Convert a MAC address (e.g., 00:06:AE:A3:AE:90) to IPv6 link-local (EUI-64)
mac="$1"

if [[ -z "$mac" ]]; then
  echo "Usage: $0 <MAC_ADDRESS>"
  exit 1
fi

# Ensure MAC is lowercase and colon-separated
mac=$(echo "$mac" | tr '[:upper:]' '[:lower:]')

IFS=':' read -r -a octets <<< "$mac"

# Flip the 7th bit of the first octet
first_octet=$(( 0x${octets[0]} ^ 0x02 ))
first_octet_hex=$(printf "%02x" $first_octet)

# Construct EUI-64
eui64="${first_octet_hex}${octets[1]}:${octets[2]}ff:fe${octets[3]}:${octets[4]}${octets[5]}"

# Output full link-local IPv6 address
echo "fe80::${eui64}"

