#!/bin/bash -eu

###
# firewall install
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

source config.sh

ufw disable
ufw reset

ufw default deny incoming
ufw default allow outgoing

# SSH
ufw allow OpenSSH
ufw allow 2222

# FTP
ufw allow ftp
ufw allow ftp-data

# HTTP
ufw allow http
ufw allow 8080

ufw logging on
ufw enable
ufw status

echo "firewall install complete"