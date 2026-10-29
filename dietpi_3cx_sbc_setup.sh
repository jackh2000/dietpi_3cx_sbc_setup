#!/bin/bash
# Script to automatically setup a 3CX SBC on a Raspberry Pi
# Installs as /usr/local/sbin/dietpi_3cx_sbc_setup and resumes at login during 
# install process. Removes itself upon completion.
# User should log in as root until the sudo user is created.
# Developed for DietPi 10.8, but 10.7 should also work.
# Uses the dietpi-config CLI helpers. See dietpi documentation.

# --- DEFAULTS --- #
# see dietpi-config documentation for options
DEFAULT_KEYBOARD='us'
DEFAULT_LOCALE='en_US.UTF-8'
DEFAULT_TIMEZONE='America/Los_Angeles' # Pacific with automatic DST
DEFAULT_INTERFACE='eth0' # may need to change for VMs
DEFAULT_TIME_SYNC_MODE=4 # 1=time sync on boot, 2=sync on boot+daily, 
# 3=on boot+hourly, 4=run as background daemon and account for drift
# Time inaccuracies can cause errors internet connections, esp apt
DEFAULT_3CX_INSTALLER_URL='https://downloads-global.3cx.com/downloads/sbc/3cxsbc.zip'
REBOOT_DELAY=15 # Seconds. Enter reboots immediately.
AUTO_RESUME_ON_LOGIN=1

# --- Modify terminal settings --- #
set +x # Disable command tracing since some lines will contain passwords
set -E # Enable errtrace: failure of a command within a command substitution or 
# subshell will be inherited as a failure of the overall command
set -e # Enable errexit: exit immediately on an unhandled command failure, even
# if it is within command subsitution or subshell
set -o pipefail # Enable pipefail: return value of a pipeline fails if any
# command in the pipeline fails, rather than returning the value of the
# rightmost command in the pipeline

umask 077 # set permissions

# --- ENVIRONMENT VARS --- #
export PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' #set
# PATH explicitly to account for varying install environments
unset BASH_ENV ENV APT_CONFIG # unset environment var's from previous scripts
export SBC_SETUP_RUNNING=1 # save state of script to avoid pauses on reboots,
# available to new bash processes or programs

# --- DIRECTORY PATHS --- #
DPiScripts='/boot/dietpi' # location of built in dietpi scripts
RUNNER='/usr/local/sbin/dietpi_3cx_sbc_setup' # path to this script
DATA='/var/lib/dietpi_3cx_sbc_setup' # store progress, backups, etc
STATE="$DATA/state" # record progress of script
LOGIN_HOOK='/etc/profile.d/90dietpi-3cx-sbc-setup.sh' # hook to launch this 
# script on login

# --- PROGRESS TRACKING --- #
STAGE='basics' # stage can be basics, network, network-verify, updates, 
# passwords, account, autoupdates, 3cx-sbc, sbc-verify, sys-verify, done
BOOT_UUID_SCRIPT='' # boot UUID when script requests a reboot. Can compare to
# later UUID to verify the reboot occurred
BOOT_UUID_3CX=''; # boot UUID when 3CX installer runs

# --- NETWORK VARIABLES --- #
# note RPI_IP must be in CIDR notation, ie 192.168.1.250/24
INTERFACE=''; RPI_IP=''; GATEWAY=''; DNS=''; HOSTNAME=''; 

# --- NEW USER --- #
ADMIN_UN=''; ADMIN_UID=''