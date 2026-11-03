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
# Load DietPi helper scripts
source /boot/dietpi/func/dietpi-globals
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
    local setting_name="$1"

    # read the value of the matching setting from the config file
    sed -n "s/^${setting_name}=//p" "$DIETPI_CONFIG"
}

# Create a systemd service so the script will continue on next boot
# Accepts the name of the next stage as an argument
configure_next_boot_stage() {
    local next_stage="$1"

    cat > "$SERVICE_FILE" <<EOF
[UNIT]
Description=Continue DietPi initial SBC setup
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
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
}

main() {
    case "$1" in # compare first arg against case. default to empty string
        --updates)
                # package update
                ;;
        --configure)
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