#!/bin/bash -eu

###
# complete install
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

source config.sh

./base-install.sh
./bash-install.sh
#./newznab-install.sh
#./sabnzbd-install.sh
#./openssh-install.sh
#./firewall-install.sh