#!/bin/sh

# Site and API URLs
BASE_URL="https://[fe80::9632:51ff:fe04:c136%eth1]"
LOGIN_URL="$BASE_URL/auth.fcgi"
DATA_URL="$BASE_URL/restful/lte/cellular_info_nr5g_sa"

# Login credentials
USERNAME="Admin"
PASSWORD="\$2a\$11\$W8/KspexdthEsSV3kVygMO1JdXShMXyf9UPLXoYF79gd6cfwwXSNC"

# CSV file path
CSV_FILE="statistics.csv"

# Check if CSV file exists, if not, add header
if [ ! -f "$CSV_FILE" ]; then
    echo "timestamp,pci,rsrp,rsrq,sinr,band,bandwidth,dl_arfcn,ul_arfcn,cell_id,tac,signal_strength" > "$CSV_FILE"
fi

# Function to log in and retrieve UID
get_uid() {
    response=$(curl -ks -X POST "$LOGIN_URL" \
        -H "Content-Type: application/json" \
        -d "{\"AuthCmd\":\"Login\",\"UserName\":\"$USERNAME\",\"UserPW\":\"$PASSWORD\"}")

    echo "$response" | jq -r '.Result[0].Login'
}

# Get the session UID
UID=$(get_uid)
if [ -z "$UID" ] || [ "$UID" == "null" ]; then
    echo "Login failed. Exiting..."
    exit 1
fi
echo "Login successful! UID: $UID"

# Refresh UID every 30 minutes
NEXT_REFRESH=$((SECONDS + 1800))

# Function to fetch data and save to CSV
fetch_data() {
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    response=$(curl -ks -X GET "$DATA_URL" \
        -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
        -H "Accept: application/json, text/plain, */*" \
        -H "Cookie: Secure; LANGUAGE=1; expert=true; UID=$UID; FIRST_LOGIN_FLAG=0; privilege=0; login_block=false")

    # Extract necessary fields
    csv_row=$(echo "$response" | jq -r --arg ts "$timestamp" '[ $ts, .Result.pci, .Result.rsrp, .Result.rsrq, .Result.sinr, .Result.band, .Result.bandwidth, .Result.dl_arfcn, .Result.ul_arfcn, .Result.cell_id, .Result.tac, .Result.signal_strength ] | @csv')

    echo "$csv_row" >> "$CSV_FILE"
    echo "Data saved: $csv_row"
}

# Infinite loop to fetch data every 5 seconds
while true; do
    # Refresh UID every 30 minutes
    if [ "$SECONDS" -ge "$NEXT_REFRESH" ]; then
        echo "Refreshing UID..."
        UID=$(get_uid)
        if [ -z "$UID" ] || [ "$UID" == "null" ]; then
            echo "Re-login failed. Retrying in 10 seconds..."
            sleep 10
        else
            echo "Re-login successful! New UID: $UID"
            NEXT_REFRESH=$((SECONDS + 1800))  # Schedule next refresh
        fi
    fi

    fetch_data
    sleep 5
done
