#!/bin/bash -eu

###
# SABnzbd install
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

source config.sh

#Sabnzbd
echo "Checking if Sabnzbd is installed..."
if dpkg-query -W -f='${Status} ${Version}\n' sabnzbdplus 2>/dev/null 1>/dev/null; then
    echo "Sabnzbd already installed"
else
    echo "Sabnzbd NOT installed, installing now"
    echo "Installing Sabnzbd"
    add-apt-repository ppa:jcfp/ppa
    apt-get update > /dev/null
    apt-get -qq -y install sabnzbdplus sabnzbdplus-theme-mobile > /dev/null
fi

echo "Writing config file /etc/default/sabnzbdplus"
cat << EOF > /etc/default/sabnzbdplus
# This file is sourced by /etc/init.d/sabnzbdplus
#
# When SABnzbd+ is started using the init script, the
# --daemon option is always used, and the program is
# started under the account of $USER, as set below.
#
# Each setting is marked either "required" or "optional";
# leaving any required setting unconfigured will cause
# the service to not start.

# [required] user or uid of account to run the program as:
USER=$USERNAME

# [optional] full path to the configuration file of your choice;
#            otherwise, the default location (in $USER's home
#            directory) is used:
CONFIG=

# [optional] hostname/ip and port number to listen on:
HOST=0.0.0.0
PORT=8080

# [optional] extra command line options, if any:
EXTRAOPTS=

EOF

service sabnzbdplus start

echo "sabnzbd install complete"