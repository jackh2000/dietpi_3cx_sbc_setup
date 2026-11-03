#!/bin/bash
# 
# Script to automatically setup a 3CX SBC on a Raspberry Pi with DietPi OS. In
# dietpi.txt set AUTO_SETUP_CUSTOM_SCRIPT_EXEC=0 and copy this script into 
# /boot/Automation_Custom_Script.sh to run it automatically on first boot
# 
# GOALS:
# - update packages and reboot
# - configure unattended upgrades
# - create a new sudo user
# - harden ssh
# - install the 3cx script. Note 3CX doesn't offer an unattended installation,
# so user interactioni is required for this step. It also requires a reboot
# after completion, so the user will do so manually. A cleanup function will
# then run automatically
# 

set -euo pipefail # enabled strict error checking

source /boot/dietpi/func/dietpi-globals # Load DietPi helper scripts
G_PROGRAM_NAME=SBC-Setup
G_INTERACTIVE=0 # automated script
G_INIT # initialize dietpi workspace
umask 077 # remove permissions from group and public

readonly DIETPI_CONFIG='/boot/dietpi.txt'
readonly POST_INSTALL_SCRIPT='/boot/Automation_Custom_Script.sh'
readonly SETUP_SERVICE='sbc_setup.service' # systemd service to run on next boot
readonly SERVICE_FILE="/etc/systemd/system/$SETUP_SERVICE"

# Accepts the name of a setting in the dietpi.txt config file as an argument
read_setting() {
    local setting_name="$1" # key

    # read the value of the matching setting from the config file
    sed -n "s/^${setting_name}=//p" "$DIETPI_CONFIG" # val
}

# Notify the user that system will reboot and cleanly reboot system
reboot_and_notify() {
    printf '\nRebooting now\n'
    sync # flush pending filesystem writes
    systemctl reboot
}

# Create a systemd service so the script will continue on next boot
# Accepts the name of the next stage as an argument
set_next_boot_service() {
    local next_stage="$1"

    cat > "$SERVICE_FILE" <<EOF
[UNIT]
Description=Continue DietPi initial SBC setup
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash $POST_INSTALL_SCRIPT $next_stage # what to execute on next boot
TimeoutStartSec=0 # disable timeout
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$SERVICE_FILE" # owner has r/w, others have read
    systemctl daemon-reload
    # run on future boots
    systemctl enable "$SETUP_SERVICE"
}

# Run apt update, upgrade, autoremove, autoclean. Use dietpi helper functions
# where possible
update_packages() {
    G_AGUP
    G_AGUG
    apt full-upgrade -y
    G_AGA
    apt autoclean -y

    printf 'Package updates finished\n'
}

main() {
    case "$1" in # compare first arg against case
        --updates)
                set_next_boot_service --configure_services
                update_packages
                printf 'Package updates complete. Rebooting to continue setup\n'
                reboot_and_notify
                ;;
        --configure_services)
            # after updates, configure unattended-upgrades, create new user, 
            # harden ssh, run 3cx script
            ;;
        --cleanup)
            # delete systemd setup file and service
            ;;
        *)
            echo "Invalid input"
        ;;
    esac
}

main "$@"