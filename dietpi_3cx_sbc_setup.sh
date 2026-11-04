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
set +xv # disable command tracing since the script will contain passwords
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
StandardInput=tty
StandardOutput=tty
StandardError=tty
TTYPath=/dev/tty1
TTYReset=yes

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

configure_unattended_upgrades() {
    cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
// apt install unattended-upgrades should make this file by default
// comments added for clarity
APT::Periodic::Update-Package-Lists "1"; // equivalent to daily apt update
APT::Periodic::Unattended-Upgrade "1"; // equivalent to daily apt upgrade
EOF

    cat > /etc/apt/apt.conf.d/52unattended-upgrades-local <<'EOF'
// Modifies Unattended-Upgrades default config
// Requires unattended-upgrades package to be installed

Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";// reboot at 3am machine time
// two lines below are equivalent to sudo apt autoremove -y
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
EOF

    systemctl enable --now apt-daily.timer apt-daily-upgrade.timer
}

add_sudoer() {
	set +xv # ensure tracing is disabled even if function is called elsewhere
    local sudo_un="$1"
	local +x sudo_pw # keep password local

    sudo_un=$(read_setting SUDOER_UN)
    sudo_pw=$(read_setting SUDOER_PW)

	useradd --create-home --user-group --shell /bin/bash "$sudo_un"
	# chpasswd normally reads from stdin, so redirect with builtin printf
	builtin printf '%s:%s\n' "$sudo_un" "$sudo_pw" | chpasswd
    unset sudo_pw
	sed -i '/^SUDOER_PW=/d' "$DIETPI_CONFIG" # remove password from config file
	usermod -aG sudo "$sudo_un" # add to sudo group
}

configure_ssh() {
	local sudo_un="$1"
	local dropbear_config='/etc/default/dropbear'

	# disable root login and port forwarding. allow login only from earlier
	# created user group. set max auth tries to 3 and idle timeout to 30 min
	local dropbear_args="-w -G $sudo_un -j -k -T 3 -I 1800"

	if grep -q \ # check there is a line with DROPBEAR_EXTRA_ARGS
		'^[[:space:]]*DROPBEAR_EXTRA_ARGS[[:space:]]*=' "$dropbear_config"
	then # if so, add the dropbear args to the line after DROPBEAR_EXTRA_ARGS
		sed -i \
			"s/^[[:space:]]*DROPBEAR_EXTRA_ARGS[[:space:]]*=.*/DROPBEAR_EXTRA_ARGS=\"$dropbear_args\"/" \
            "$dropbear_config"
	else
		printf '\nDROPBEAR_EXTRA_ARGS="%s"\n' "$dropbear_args" >> "$dropbear_config"
	fi
	
	systemctl enable dropbear
	systemctl restart dropbear
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
			local username
			username=$(read_setting SUDOER_UN)
            set_next_boot_service --cleanup
            configure_unattended_upgrades "$username"
            add_sudoer "$username"
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