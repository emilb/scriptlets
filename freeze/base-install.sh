#!/bin/bash -eu

###
# Base install
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

source config.sh

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

echo "Installing python-software-properties..."
apt-get -qq -y install python-software-properties > /dev/null

# Get a sane build environment
echo "Installing autoconf build-essential ..."
apt-get -qq -y install autoconf build-essential checkinstall > /dev/null

# Version control
echo "Installing git-core subversion cvs..."
apt-get -qq -y install git-core subversion cvs > /dev/null

# PHP
echo "Installing php5-cli php5-cgi psmisc spawn-fcgi php5-mysql php5-curl php5-fpm..."
apt-get -qq -y install php5 php5-dev php-pear php5-gd php5-mysql php5-curl php5-fpm > /dev/null

# nginx
echo "Installing nginx"
apt-get -qq -y install nginx > /dev/null

# ruby
echo "Installing ruby1.9.1..."
apt-get -qq -y install ruby1.9.1 > /dev/null

# Filesharing
echo "Installing samba sshfs vsftpd..."
apt-get -qq -y install samba > /dev/null

# Media
echo "Installing media utils and lame..."
apt-get -qq -y install lame libfaac-dev libjack-jackd2-dev libmp3lame-dev libopencore-amrnb-dev > /dev/null
apt-get -qq -y install libopencore-amrwb-dev libsdl1.2-dev libtheora-dev libva-dev libvdpau-dev > /dev/null
apt-get -qq -y install libvorbis-dev libx11-dev libxfixes-dev texi2html yasm zlib1g-dev libdirac-dev > /dev/null
apt-get -qq -y install libxvidcore-dev > /dev/null

# ntp
echo "Installing ntp ntpdate..."
apt-get -qq -y install ntp ntpdate > /dev/null

echo "Installations done"