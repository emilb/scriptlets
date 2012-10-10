#!/bin/bash -eu

###
# Locale fix
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi


cat << EOF > /etc/default/locale 
LANG="en_GB"
LANGUAGE="en_GB.UTF-8"
LC_ALL="en_GB.UTF-8"
EOF

locale-gen en_GB
dpkg-reconfigure locales

echo "Log out and in to reload locales"