#!/bin/bash
# 
# 
# Script to automatically setup a 3CX SBC on a Raspberry Pi with DietPi OS.
#
# GOALS:
#
# Use the official dietpi automated install via a customized /boot/dietpi.txt
# file.
#
# This script should:
#
# Fill some values in dietpi.txt that will vary from the 3cx_sbc_dietpi.txt
# template that change on each install. These will be pulled from a
# corresponding json file.
#
# Copy the txt template and rename it to /boot/dietpi.txt
#
# Perform additional configuration options:
#
# 1. Update packages
# 2. Harden ssh
# 3. Configure unattended upgrades
# 4. Configure the 3CX SBC
