#!/bin/bash -eu

###
# openssh install
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

source config.sh

echo "Installing ssh"
apt-get -qq -y install ssh > /dev/null

echo "Configuring openssh server"

if ( grep 'UseDNS' /etc/ssh/sshd_config ); then
    echo "UseDNS already defined!"
else
    echo "Removing DNS check on ssh login"
    echo "UseDNS no" | tee -a /etc/ssh/sshd_config
fi

if ( grep 'PermitRootLogin no' /etc/ssh/sshd_config ); then
    echo "PermitRootLogin already set to no"
else
    mv /etc/ssh/sshd_config /etc/ssh/sshd_config.org > /dev/null
    cat /etc/ssh/sshd_config.org | sed 's/PermitRootLogin .*/PermitRootLogin no/' > /etc/ssh/sshd_config
fi

if ( grep 'Port 2222' /etc/ssh/sshd_config ); then
    echo "Port 2222 already defined!"
else
    echo "Adding port 2222 for ssh service"
    echo "Port 2222" | tee -a /etc/ssh/sshd_config
fi

service ssh restart

echo "openssh install complete"