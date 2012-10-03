#!/bin/bash -eu

###
# Plex media server install
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

PLEX_VERSION='0.9.6.9.240'
PLEX_FILENAME="plexmediaserver_$PLEX_VERSION-8fd9c6a_amd64.deb"

echo "Installing avahi..."
apt-get -qq -y install avahi-daemin avahi-utils > /dev/null

echo "Downloading plex..."
wget http://cdn.plexapp.com/PlexMediaServer/$PLEX_VERSION/$PLEX_FILENAME

dpkg -i $PLEX_FILENAME

rm $PLEX_FILENAME 