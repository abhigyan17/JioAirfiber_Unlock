#!/bin/bash

# ONLY for educational purposes, No one is responsible for any type of damage.

# Usage: ./enableRootSSH.sh <device_ip>

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display usage instructions
usage() {
  echo "This script was specifically made for Jio Extender, though this might work for normal IDUs; it is still advised to use the normal breeze.sh"
  echo "Usage: $0 <device_ip>"
  echo "Example: $0 192.168.31.1"
  exit 1
}

# Function to check the success of the last executed command
check_success() {
  if [ "$?" -ne 0 ]; then
    echo "Error: $1 failed."
    exit 1
  fi
}

check_json_success() {
  if ! jq '.status' curl.output 2>/dev/null | grep -q OK ; then
    echo "Error: $1 failed."
    exit 1
  fi
}

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
  echo "Error: Incorrect number of arguments."
  usage
fi

# Assign command-line arguments to variables
DEVICE_IP="$1"
ENCRYPTED_FILE="conf.enc"
DECRYPTED_FILE="conf.dec"
MODIFIED_TAR="conf_new.tar.gz"
MODIFIED_TAR_ENC="conf_new.enc"

# Check for required tools
REQUIRED_TOOLS=("cut" "curl" "dd" "gunzip" "jq" "openssl" "sed" "tar")
for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" &> /dev/null; then
    echo "Error: '$tool' is not installed. Please install it before running this script."
    exit 1
  fi
done

if ! grep --version | grep -v BSD | grep -q GNU; then
  echo "Error: GNU grep is not installed. Please install it before running the script."
  exit 1
fi

read -sp "Please enter your JAF IDU device admin password:" DEVICE_PASSWORD

# Step 1: Login to the device
echo "Step 1: Trying to login to the router..."

curl "https://${DEVICE_IP}/WCGI" \
  -H 'Content-Type: application/json' \
  --data-raw "{\"jsonrpc\":\"2.0\",\"method\":\"login\",\"params\":{\"username\":\"admin\",\"password\":\"${DEVICE_PASSWORD}\"}}" \
  --insecure >curl.output

check_json_success "Device login"

AUTH_TOKEN=$(jq -r '.results.token' curl.output 2>/dev/null | cut -f 1 -d\ )
COOKIE=$(jq -r '.results.token' curl.output 2>/dev/null | cut -f 2 -d\ )

curl "https://${DEVICE_IP}/WCGI" \
  -H "Cookie: cSupport=1; sysauth=${COOKIE}" \
  -H 'Content-Type: application/json' \
  --data-raw "{\"jsonrpc\":\"2.0\",\"method\":\"postLogin\",\"params\":{\"authHeader\":\"Bearer ${AUTH_TOKEN}\"}}" \
  --insecure >curl.output

check_json_success "Device post login"

# Step 2: Downloading backup file
echo "Step 1: Downloading backup file..."

curl "https://${DEVICE_IP}/WCGI" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "Cookie: cSupport=1; sysauth=${COOKIE}" \
  -H 'Content-Type: application/json' \
  --data-raw '{"jsonrpc":"2.0","method":"getBackupConfiguration","fileDownload":"yes"}' \
  --insecure --output ${ENCRYPTED_FILE}

check_success "Downloading backup file"

# Step 3: Decrypting the configuration backup
echo "Step 3: Decrypting the configuration backup..."
openssl enc -pbkdf2 -in "$ENCRYPTED_FILE" -out "$DECRYPTED_FILE" -d -aes256 -k "/etc/server.key"
check_success "Backup file decryption"

# Step 4: Extract the decrypted backup
echo "Step 4: Extracting the decrypted backup..."
EXTRACT_DIR="extracted_backup"
mkdir -p "$EXTRACT_DIR"

gzip_index=$(LANG=ISO-8859-1 grep -obUaP "\x1f\x8b\x08" ${DECRYPTED_FILE} 2>/dev/null | head -n 1 | LANG=ISO-8859-1 cut -f 1 -d:)

[ -n ${gzip_index} ] || {
  echo "Downloaded backup file is invalid"
  exit 1
}

if [ ${gzip_index} != 0 ]; then
  dd if=${DECRYPTED_FILE} of=${DECRYPTED_FILE}.stripped bs=1 skip=${gzip_index}
  mv ${DECRYPTED_FILE}.stripped ${DECRYPTED_FILE}
fi

tar -xzvf "$DECRYPTED_FILE" -C "$EXTRACT_DIR"
check_success "Extraction"

# Step 5: Modify the necessary files in the backup
SHADOW_FILE="$EXTRACT_DIR/etc/shadow"

# Ensure the shadow file exists
if [ ! -f "$SHADOW_FILE" ]; then
  echo "Error: Shadow file '$SHADOW_FILE' does not exist in the backup."
  exit 1
fi

# Update the root password hash in the shadow file
echo "Step 5: Setting new root password hash..."
PASSWORD_HASH=$(grep "^admin:" "$SHADOW_FILE" | cut -f 2 -d:)

# check if macos
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s|^root:[^:]*:|root:${PASSWORD_HASH}:|" "$SHADOW_FILE"
else
  sed -i "s|^root:[^:]*:|root:${PASSWORD_HASH}:|" "$SHADOW_FILE"
fi
check_success "Updating root password hash"

echo "Step 6: Configuring /etc/firewall.user to start dropbear..."
FIREWALL_FILE="$EXTRACT_DIR/etc/firewall.user"
echo 'dropbear -p 0.0.0.0:22' > "$FIREWALL_FILE"
check_success "Creating firewall.user for dropbear"

# Step 7: Repackage the modified backup
echo "Step 7: Repackaging the modified backup..."
tar -czvf "$MODIFIED_TAR" -C "$EXTRACT_DIR" .
check_success "Repackaging"

# Step 8: Re-encrypt the modified backup
echo "Step 8: Re-encrypting the modified backup..."
openssl enc -pbkdf2 -in "$MODIFIED_TAR" -out "$MODIFIED_TAR_ENC" -e -aes256 -k "/etc/server.key"
check_success "Re-encryption"

# Step 9: Uploading modified configuration
echo "Step 9: Uploading modified configuration..."
curl "https://${DEVICE_IP}/WCGI" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "Cookie: cSupport=1; sysauth=${COOKIE}" \
  -F restoreFile=@${MODIFIED_TAR_ENC} \
  -F fileUpload=yes -F method=setRestoreSettings \
  --insecure >curl.output

check_json_success "Restore configuration"

# Step 10: Cleanup temporary files
echo "Step 10: Cleaning up temporary files..."
rm -rf "$DECRYPTED_FILE" "$EXTRACT_DIR" "$MODIFIED_TAR" curl.output

# Final Instructions
echo "All steps completed successfully!"
