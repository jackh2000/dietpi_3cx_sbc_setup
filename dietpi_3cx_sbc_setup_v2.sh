#!/bin/bash
# Script to automatically setup a 3CX SBC on a Raspberry Pi, utilizing the 
# official dietpi automated install. This script adds additional features, such
# as updating packages, hardening ssh, configuring unattended upgrades,
# creating a new sudo user, and configuring the 3CX SBC install.
# The script will pull custom values from a corresponding json file if that
# file exists. If not, the script will use default or empty values. 
