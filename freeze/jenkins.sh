#!/bin/bash -eu

###
# Jenkins install
# http://jenkins-ci.org/
###

echo "Adding user jenkins"
adduser --no-create-home --disabled-login --system --group --quiet jenkins

echo "Downloading jenkins.war"
mkdir -p /opt/services/jenkins/home
pushd /opt/services/jenkins
wget http://mirrors.jenkins-ci.org/war/latest/jenkins.war

echo "Updating file ownerships to jenkins"
chown -R jenkins:jenkins /opt/services/jenkins
popd

echo "Installing nginx proxy for jenkins"
cat << EOF > /etc/nginx/sites-available/jenkins
    location /jenkins {
        # give site more time to respond
        proxy_read_timeout 120;

        # needed to forward user's IP address
        proxy_set_header  X-Real-IP  $remote_addr;

        # needed for HTTPS
        proxy_set_header  X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$http_host;
        proxy_redirect off;
        proxy_max_temp_file_size 0;

        proxy_pass http://localhost:8081;
    }
EOF

ln -s /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/jenkins 

echo "Installing upstart service for jenkins"
cat << EOF > /etc/init/jenkins.conf
description "Jenkins"

respawn
start on started network-services
stop on stopping network-services

script
export JENKINS_HOME=/opt/services/jenkins/home
sudo -Hu jenkins java -Xms128m -Xmx2048m -server -jar /opt/services/jenkins/jenkins.war -Djava.awt.headless=true --httpPort=8081 --httpListenAddress=127.0.0.1
end script
EOF
