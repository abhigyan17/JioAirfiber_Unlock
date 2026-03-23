#!/bin/bash

# ========== Dependency Checks ==========
echo "[*] Checking dependencies..."

# Check for Python 3
if ! command -v python3 &> /dev/null; then
  echo "[!] Python3 is not installed. Install it first."
  exit 1
fi

# Check for 'bcrypt' module in Python
if ! python3 -c "import bcrypt" &> /dev/null; then
  echo "[!] Python3 module 'bcrypt' not found. Installing..."
  if command -v pip3 &> /dev/null; then
    pip3 install bcrypt || { echo "[!] Failed to install bcrypt."; exit 1; }
  else
    echo "[!] pip3 is not available. Please install 'bcrypt' manually."
    exit 1
  fi
fi

# Check for jq
if ! command -v jq &> /dev/null; then
  echo "[!] 'jq' is not installed. Please install it using your package manager."
  exit 1
fi

echo "[✓] All dependencies are satisfied."

# Global variables
SALT='$2a$11$W8/KspexdthEsSV3kVygMO'

# Step 1: Get user input
read -p "Enter host (e.g. localhost): " HOST
read -p "Enter port (e.g. 8443): " PORT
read -p "Enter username: " USERNAME
read -s -p "Enter hashed password (leave blank to use text based pass): " HASHED_PW
echo ""

# Check if HASHED_PW is empty
if [[ -z "$HASHED_PW" ]]; then
  read -s -p "Enter Admin password (text): " ASCII_PW
  echo ""

  read -p "Do you want to use a custom bcrypt salt? (y/N): " CHANGE_SALT
  if [[ "$CHANGE_SALT" =~ ^[Yy]$ ]]; then
    read -p "Enter bcrypt salt (must be 29 chars, e.g., \$2a\$11\$W8/KspexdthEsSV3kVygMO): " CUSTOM_SALT
    SALT="$CUSTOM_SALT"
  else
    echo "[*] Using default salt."
  fi

  # Generate bcrypt hash using Python
  HASHED_PW=$(python3 -c "
import bcrypt
password = b'$ASCII_PW'
salt = b'$SALT'
hashed = bcrypt.hashpw(password, salt)
print(hashed.decode())
")
  echo "[*] Password hashed with bcrypt."
fi


# Define URLs
BASE_URL="https://${HOST}:${PORT}"
LOGIN_URL="${BASE_URL}/auth.fcgi"
STATS_URL="${BASE_URL}/restful/lte/cellular_info_nr5g_sa"

# Step 2: Send login request
echo "[*] Logging in..."

RESPONSE=$(curl -sk -X POST "$LOGIN_URL" \
  -H "Cookie: Secure; LANGUAGE=1; expert=true" \
  -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
  --data-binary "{\"AuthCmd\":\"Login\",\"UserPW\":\"$HASHED_PW\",\"UserName\":\"$USERNAME\"}")

# Step 3: Extract UID
USER_ID=$(echo "$RESPONSE" | jq -r '.Result[0].Login')

if [[ "$USER_ID" == "null" || -z "$USER_ID" ]]; then
  echo "[!] Login failed. Check your credentials or connection."
  exit 1
fi

echo "[+] Logged in successfully. UID: $USER_ID"


# Step 4: Live fetch of 5G NR SA stats every 0.5s
while true; do
  clear
  echo "[*] Fetching 5G NR SA stats at $(date '+%H:%M:%S')..."

  STATS=$(curl -sk -X GET "$STATS_URL" \
    -H "Cookie: Secure; LANGUAGE=1; expert=true; UID=${USER_ID}; FIRST_LOGIN_FLAG=0; privilege=0; login_block=false" \
    -H "Accept: application/json")

  echo "[+] 5G NR SA Statistics:"
  echo "$STATS" | jq

  sleep 0.5
done

