#!/bin/bash -eu

###
# Base install
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

#####################################################################
# Update everything
#####################################################################
echo "Updating system"
apt-get -qq update > /dev/null
apt-get -qq -y dist-upgrade > /dev/null

#####################################################################
# Install packages
#####################################################################
echo "Installing screen htop unzip unrar emacs wget rsync man mc..."
apt-get -qq -y install screen tmux htop unzip unrar emacs wget rsync man mc > /dev/null

# Get a sane build environment
echo "Installing autoconf build-essential ..."
apt-get -qq -y install autoconf build-essential checkinstall > /dev/null

# Version control
echo "Installing git-core subversion cvs..."
apt-get -qq -y install git-core subversion cvs > /dev/null

# MySQL
apt-get -qq -y install mysql-server

# PHP
echo "Installing php5-cli php5-cgi psmisc spawn-fcgi php5-mysql php5-curl memcached php5-memcached..."
apt-get -qq -y install php5 php5-dev php-pear php5-gd php5-mysql php5-curl memcached php5-memcached > /dev/null


# Apache
echo "Installing apache2"
apt-get -qq -y install apache2 > /dev/null

# ntp
echo "Installing ntp ntpdate..."
apt-get -qq -y install ntp ntpdate > /dev/null

echo "Installations done"