#!/bin/bash -eu

###
# Java from oracle install
# http://www.wikihow.com/Install-Oracle-Java-on-Ubuntu-Linux
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

JDK_FILENAME='jdk-7u7-linux-x64.tar.gz'

echo "Download jdk 7u7"
wget http://forme.doot.se/downloads/$JDK_FILENAME

mkdir -p /usr/local/java
tar zxvf $JDK_FILENAME -C /usr/local/java 

update-alternatives --install "/usr/bin/java" "java" "/usr/local/java/jdk1.7.0_07/bin/java" 1
update-alternatives --install "/usr/bin/javac" "javac" "/usr/local/java/jdk1.7.0_07/bin/javac" 1

update-alternatives --set java /usr/local/java/jdk1.7.0_07/bin/java
update-alternatives --set javac /usr/local/java/jdk1.7.0_07/bin/javac

rm $JDK_FILENAME
