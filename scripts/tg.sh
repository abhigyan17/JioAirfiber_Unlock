#!/bin/sh

# Telegram Bot API credentials
BOT_TOKEN="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
CHAT_ID="XXXXXXXXXXXXXXX"
FILE="$1"
TEMP_FILE="cp-${FILE}"

# Infinite loop to send the file every 30 minutes
while true; do
    cp "$FILE" "$TEMP_FILE"
    echo "Sending ${FILE} to Telegram..."

    echo "curl -k -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" -F chat_id="${CHAT_ID}" -F document=@"${TEMP_FILE}""
    curl -k -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
        -F chat_id="${CHAT_ID}" \
        -F document=@"${TEMP_FILE}" \
        -F caption="📊 $(date)"

    echo "File sent. Waiting 30 minutes before next send."

    # Wait for 1800 seconds (30 minutes)
    sleep 1800
done
