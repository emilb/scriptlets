#!/bin/bash -eu

###
# xxx install
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

source config.sh

echo "xxx install complete"