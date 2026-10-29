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
DEFAULT_TIME_SYNC_MODE=4 # 1=time sync on boot, 2=sync on boot+daily, 
# 3=on boot+hourly, 4=run as background daemon and account for drift
# Time inaccuracies can cause errors internet connections, esp apt
DEFAULT_3CX_INSTALLER_URL='https://downloads-global.3cx.com/downloads/sbc/3cxsbc.zip'
REBOOT_DELAY=15 # Seconds. Enter reboots immediately.
AUTO_RESUME_ON_LOGIN=1
# ------------- #

set +x # Disable command tracing since some lines will contain passwords
set -E # Enable errtrace: failure of a command within a command substitution or 
# subshell will be inherited as a failure of the overall command
set -e # Enable errexit: exit immediately on an unhandled command failure, even
# if it is within command subsitution or subshell
set -o pipefail # Enable pipefail: return value of a pipeline fails if any
# command in the pipeline fails, rather than returning the value of the
# rightmost command in the pipeline

umask 077 # set permissions

export PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' # set
# PATH explicitly to account for varying install environments
export SBC_SETUP_RUNNING=1 # save state of script to avoid pauses on reboots
unset BASH_ENV ENV APT_CONFIG # unset environment var's from previous scripts
DPiScripts='/boot/dietpi' # location of built in dietpi scripts
RUNNER='/usr/local/sbin/dietpi_3cx_sbc_setup' # path to this script