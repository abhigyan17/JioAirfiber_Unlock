#!/bin/ash

echo "=============================================="
echo "            opensync_disabler                 "
echo "     Disable Opensync-related services        "
echo "          and patch init scripts              "
echo "                                              "
echo " Usage:                                       "
echo "     ./opensync_disabler.sh                   "
echo "     ./opensync_disabler.sh --restore         "
echo "=============================================="


set -e

SERVICES="healthcheck opensync jioWifiManagerStartup jioDscpPriority jioWifiNotifierStartup jioWifiLoggerStartup"
INIT_SCRIPTS="plumeConfigMerge platformConfigMerge opensync dnsmasq"

restore_script() {
    SCRIPT="/etc/init.d/$1"
    BACKUP="$SCRIPT.bak"

    if [ -f "$BACKUP" ]; then
        echo "  -> Restoring $SCRIPT"
        cp "$BACKUP" "$SCRIPT" || {
            echo "  !! Failed to restore $SCRIPT from backup"
            return 1
        }
        chmod +x "$SCRIPT"
    else
        echo "  !! No backup found for $SCRIPT"
    fi
}

patch_script() {
    SCRIPT="/etc/init.d/$1"
    [ -f "$SCRIPT" ] || return

    # Always backup before patching
    cp "$SCRIPT" "$SCRIPT.bak"

    case "$1" in
        plumeConfigMerge|platformConfigMerge)
            # Collapse any PlumeEnabled assignment down to 0
            sed -i 's/PlumeEnabled=".*"/PlumeEnabled="0"/g' "$SCRIPT"
            ;;
        opensync)
            # Replace service-enabled function to always return false
            awk '
            BEGIN {skip=0}
            /^opensync_service_enabled\(\)/ {
                print "opensync_service_enabled() {\n    false\n}"
                skip=1
                next
            }
            skip && /^\}/ { skip=0; next }
            !skip { print }
            ' "$SCRIPT.bak" > "$SCRIPT"
            ;;
        dnsmasq)
            # Comment out the bind-dynamic append_bool line
            sed -i '/append_bool.*nonwildcard.*--bind-dynamic/ s/^/#/' "$SCRIPT"
            ;;
    esac
}

disable_services() {
    echo "[*] Disabling services..."
    for svc in $SERVICES; do
        INIT_PATH="/etc/init.d/$svc"
        if [ -x "$INIT_PATH" ]; then
            echo "  -> Disabling $svc"
            $INIT_PATH stop 2>/dev/null || true
            $INIT_PATH disable 2>/dev/null || true
            chmod -x "$INIT_PATH"
        else
            echo "  !! Service $svc not found or not executable"
        fi
    done
}

restore_services() {
    echo "[*] Restoring services..."
    for svc in $SERVICES; do
        # If we have a backed-up init script, restore and re-enable it
        if [ -f "/etc/init.d/$svc.bak" ]; then
            echo "  -> Re-enabling $svc"
            cp "/etc/init.d/$svc.bak" "/etc/init.d/$svc"
            chmod +x "/etc/init.d/$svc"
            /etc/init.d/$svc enable 2>/dev/null || true
        fi
    done
}

# Main execution flow
if [ "$1" = "--restore" ] || [ "$1" = "-r" ]; then
    echo "[*] Restoring all changes..."
    for script in $INIT_SCRIPTS; do
        restore_script "$script"
    done
    restore_services
    echo "[*] Restore complete."
else
    disable_services
    echo "[*] Patching init scripts..."
    for script in $INIT_SCRIPTS; do
        patch_script "$script"
    done
    echo "[*] Done. All services disabled and init scripts patched."
    echo "[*] Please reboot the device for changes to take effect."
fi
