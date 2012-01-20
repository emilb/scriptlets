#!/bin/bash -eu

#####################################################################
#
# touch base-linux-setup.sh; chmod +x base-linux-setup.sh; vi base-linux-setup.sh
# copy the contents of this file to osm-setup.sh and execute!
#
#####################################################################

USERNAME=emil
PASSWORD=secret
FULLNAME="Emil Breding"
EMAIL="emil.breding@gmail.com"
HOSTNAME=emibre
FQDN=emibre.com
IPADDRESS=209.123.162.172
WORDPRESS_FQDN=forme.emibre.com
TOMCAT_FQDN=tomcat.emibre.com
WWW_DIR=/var/www

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

function installPackages {
    #####################################################################
    # Update everything
    #####################################################################
    echo "Updating system"
    apt-get -qq update > /dev/null
    apt-get -qq -y dist-upgrade > /dev/null

    #####################################################################
    # Install packages
    #####################################################################
    echo "Installing screen htop unzip emacs wget rsync man..."
    apt-get -qq -y install screen htop unzip emacs wget rsync man > /dev/null
    echo "Installing iptables..."
    apt-get -qq -y install iptables > /dev/null

    # Get a sane build environment
    echo "Installing autoconf build-essential ..."
    apt-get -qq -y install autoconf build-essential > /dev/null

    # Version control
    echo "Installing git-core subversion cvs..."
    apt-get -qq -y install git-core subversion cvs > /dev/null

    # MySQL
    echo "Installing mysql-server..."
    apt-get -qq -y install mysql-server

    # nginx
    echo "Installing nginx..."
    apt-get -qq -y install nginx > /dev/null

    # PHP
    echo "Installing php5-cli php5-cgi psmisc spawn-fcgi php5-mysql..."
    apt-get -qq -y install php5-cli php5-cgi psmisc spawn-fcgi php5-mysql > /dev/null

    # Java
    echo "Installing openjdk-7-jdk ant ant-optional..."
    apt-get -qq -y install openjdk-7-jdk ant ant-optional > /dev/null
    echo "Setting Java 7 as default..."
    /usr/sbin/update-java-alternatives --list | /bin/egrep -i java-1.7.0-openjdk-i386
    if [ $? -eq 0 ]; then
        echo "...i386 java"
        update-java-alternatives -s java-1.7.0-openjdk-i386 > /dev/null
    else
       echo "...amd64 java"
        update-java-alternatives -s java-1.7.0-openjdk-amd64 > /dev/null
    fi

    echo "Installing tomcat7 tomcat7-common tomcat7-admin (tomcat7-docs)..."
    apt-get -qq -y install tomcat7 tomcat7-common tomcat7-admin > /dev/null

    # postfix
    echo "Installing postfix mailutils..."
    apt-get -qq -y install postfix mailutils

    # Fail2ban
    echo "Installing fail2ban..."
    apt-get -qq -y install fail2ban > /dev/null

    # Logwatch
    echo "Installing logwatch..."
    apt-get -qq -y install logwatch > /dev/null

    # ntp
    echo "Installing ntp ntpdate..."
    apt-get -qq -y install ntp ntpdate > /dev/null
    
    echo "Installations done"

}

function setupTimeZone {
    dpkg-reconfigure tzdata
}

#####################################################################
# Disable DNS lookups on ssh login and disable root login
#####################################################################
function setupSSH {
    if ( grep 'UseDNS' /etc/ssh/sshd_config ); then
        echo "UseDNS already defined!"
    else
        echo "Removing DNS check on ssh login"
        echo "UseDNS no" | tee -a /etc/ssh/sshd_config
        service ssh restart
    fi

    if ( grep 'PermitRootLogin no' /etc/ssh/sshd_config ); then
        echo "PermitRootLogin already set to no"
    else
        mv /etc/ssh/sshd_config /etc/ssh/sshd_config.org > /dev/null
        cat /etc/ssh/sshd_config.org | sed 's/PermitRootLogin .*/PermitRootLogin no/' > /etc/ssh/sshd_config
    fi

    service ssh restart
}
    
function setupIPTables {
    echo "Creating firewall rules"
    # Firewall, setting up (reference: https://help.ubuntu.com/community/IptablesHowTo)
    cat << EOF > /root/iptables.setup
# flush current tables (start from scratch)
iptables -F
# accept anything from localhost
iptables -A INPUT -i lo -j ACCEPT
# accept related connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
# open ssh from outside
iptables -A INPUT -p tcp --dport ssh -j ACCEPT
# open web server connections from outside
iptables -A INPUT -p tcp --dport www -j ACCEPT
# allow this server to be pinged
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
# disallow everything else
iptables -A INPUT -j DROP
EOF

    chmod a+x /root/iptables.setup > /dev/null
echo "Enabling firewall"
/root/iptables.setup > /dev/null

iptables-save > /etc/iptables.rules
chmod 600 /etc/iptables.rules

cat << EOF > /etc/network/if-pre-up.d/iptables
#!/bin/sh
iptables-restore < /etc/iptables.rules
EOF
    chmod a+x /etc/network/if-pre-up.d/iptables > /dev/null

    cat << EOF > /etc/network/if-post-down.d/iptables
#!/bin/sh
iptables-save -c > /etc/iptables.rules
EOF
    chmod a+x /etc/network/if-post-down.d/iptables > /dev/null
    echo "Firewall rules saved"
}

function setupHostName {
    echo "Setting hostname to $HOSTNAME"
    hostname $HOSTNAME
    hostname > /etc/hostname
    echo "$IPADDRESS    $FQDN $HOSTNAME" | cat - /etc/hosts > /etc/hosts.new
    mv /etc/hosts.new /etc/hosts > /dev/null
}

function setupFastCGI {

    # This is from here: http://igorpartola.com/tag/ubuntu-php-nginx-fastcgi-vps-performance
    # Could also use this: http://library.linode.com/lemp-guides/ubuntu-11.10-oneiric
    echo "Setting up service for fastcgi-php"
    cat << EOF > /etc/init.d/fastcgi-php
#!/bin/bash
BIND_DIR=/var/run/php-fastcgi
BIND="\$BIND_DIR/php.sock"
USER=www-data
PHP_FCGI_CHILDREN=4
PHP_FCGI_MAX_REQUESTS=128

PHP_CGI=/usr/bin/php-cgi
PHP_CGI_NAME=\`basename \$PHP_CGI\`
PHP_CGI_ARGS="- USER=\$USER PATH=/usr/bin PHP_FCGI_CHILDREN=\$PHP_FCGI_CHILDREN PHP_FCGI_MAX_REQUESTS=\$PHP_FCGI_MAX_REQUESTS \$PHP_CGI -b \$BIND"
RETVAL=0

start() {
    echo -n "Starting PHP FastCGI: "
    mkdir \$BIND_DIR
    chown -R \$USER \$BIND_DIR
    start-stop-daemon --quiet --start --background --chuid "\$USER" --exec /usr/bin/env -- \$PHP_CGI_ARGS
    RETVAL=\$?
    echo "\$PHP_CGI_NAME."
}
stop() {
    echo -n "Stopping PHP FastCGI: "
    killall -q -w -u \$USER \$PHP_CGI
    RETVAL=\$?
    rm -rf \$BIND_DIR
    echo "\$PHP_CGI_NAME."
}

case "\$1" in
    start)
        start
  ;;
    stop)
        stop
  ;;
    restart)
        stop
        start
  ;;
    *)
        echo "Usage: php-fastcgi {start|stop|restart}"
        exit 1
  ;;
esac
exit \$RETVAL
EOF
    
    echo "Setting permissions for fastcgi-php and adding to rc.d"
    chmod 755 /etc/init.d/fastcgi-php > /dev/null
    update-rc.d fastcgi-php defaults > /dev/null
    echo "Starting fastcgi-php"
    /etc/init.d/fastcgi-php start
}

function setupWordPress {
    
    mkdir -p $WWW_DIR > /dev/null
    chown www-data:www-data $WWW_DIR > /dev/null

    # Download and unpack
    cd $WWW_DIR

    echo "Downloading latest wordpress"
    wget http://wordpress.org/latest.zip > /dev/null
    echo "Unzipping wordpress"
    unzip latest.zip > /dev/null
    rm latest.zip
    echo "Changing ownership to www-data"
    chown -R www-data:www-data wordpress

    # Create wordpress database
    echo "Creating wordpress database"
    /usr/bin/mysql -u root << EOF
    create database wordpress;
EOF

    # nginx config
    echo "Setting up nginx wordpress site"
    cat << EOF > /etc/nginx/sites-available/wordpress
    server {
        listen 80; #or change this to your public IP address eg 1.1.1.1:80
        server_name $WORDPRESS_FQDN;
        access_log /var/log/nginx/wordpress.access.log;
        error_log /var/log/nginx/wordpress.error.log;

        location / {
          root $WWW_DIR/wordpress;
          index index.php index.html index.htm;

          # this serves static files that exist without running other rewrite tests
          if (-f \$request_filename) {
              expires 30d;
              break;
          }

          # this sends all non-existing file or directory requests to index.php
          if (!-e \$request_filename) {
              rewrite ^(.+)\$ /index.php?q=\$1 last;
          }
        }

        location ~ \.php\$ {
            include /etc/nginx/fastcgi_params;
            #fastcgi_pass    127.0.0.1:9000;
            fastcgi_pass    unix:/var/run/php-fastcgi/php.sock;
            fastcgi_index   index.php;
            fastcgi_param   SCRIPT_FILENAME $WWW_DIR/wordpress\$fastcgi_script_name;
        }
    }
EOF

    echo "Enabling wordpress site"
    ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/wordpress > /dev/null

    echo "Starting nginx"
    service nginx start
}

function addWordPressPlugins {
    echo "Downloading WordPress plugins"
    # Category Cloud Widget


    # Google XML Sitemaps


    # SI CAPTCHA Anti-Spam


    # WordPress Importer


    # WP-Syntax


    # WPTouch

}

function setupFail2ban {

    echo "Setting up fail2ban"
    
    mv /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.org > /dev/null

    cat << EOF > /etc/fail2ban/jail.conf
[DEFAULT]

# "ignoreip" can be an IP address, a CIDR mask or a DNS host                                                                                                               
ignoreip = 127.0.0.1 82.199.190.107 home.emibre.com lan.ath.cx
bantime  = 86400
maxretry = 3

backend = polling

destemail = root@localhost

banaction = iptables-multiport
                                                                                                                     
mta = sendmail

protocol = tcp

action_ = %(banaction)s[name=%(__name__)s, port="%(port)s", protocol="%(protocol)s]                                 
action_mw = %(banaction)s[name=%(__name__)s, port="%(port)s", protocol="%(protocol)s]
            %(mta)s-whois[name=%(__name__)s, dest="%(destemail)s", protocol="%(protocol)s]              
action_mwl = %(banaction)s[name=%(__name__)s, port="%(port)s", protocol="%(protocol)s]
             %(mta)s-whois-lines[name=%(__name__)s, dest="%(destemail)s", logpath=%(logpath)s]
                                                                                                                
action = %(action_)s

[ssh-ddos]

enabled = true
port    = ssh
filter  = sshd-ddos
logpath  = /var/log/auth.log
maxretry = 6

[ssh]

enabled = true
port    = ssh
filter  = sshd
logpath  = /var/log/auth.log
maxretry = 3
EOF
}

function setupPostfix {
    echo "Setting up postfix"
    
    mv /etc/postfix/main.cf /etc/postfix/main.cf.org > /dev/null

    cat << EOF > /etc/postfix/main.cf

smtpd_banner = \$myhostname ESMTP \$mail_name (Ubuntu)
biff = no

# appending .domain is the MUA's job.
append_dot_mydomain = no

# Uncomment the next line to generate "delayed mail" warnings
#delay_warning_time = 4h

readme_directory = no

# TLS parameters
smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
smtpd_use_tls=yes
smtpd_tls_session_cache_database = btree:\${data_directory}/smtpd_scache
smtp_tls_session_cache_database = btree:\${data_directory}/smtp_scache

# See /usr/share/doc/postfix/TLS_README.gz in the postfix-doc package for
# information on enabling SSL in the smtp client.

myhostname = emibre.com
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
myorigin = /etc/mailname
mydestination = $FQDN, localhost.com, , localhost
relayhost = 
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
mailbox_size_limit = 0
recipient_delimiter = +
inet_interfaces = all
EOF

    cat << EOF > /etc/mailname
$FQDN
EOF

    echo "Restarting postfix"
    service postfix restart
}

function setupTomcat {
    # If you want Tomcat to use JDK7 edit /etd/init.d/tomcat7 and change JDK_DIRS to:
    # JDK_DIRS="/usr/lib/jvm/java-1.7.0-openjdk-i386 /usr/lib/jvm/java-6-openjdk /usr/lib/jvm/java-6-sun"

    echo "Adding user $USERNAME to tomcat-users"
    mv /etc/tomcat7/tomcat-users.xml /etc/tomcat7/tomcat-users.xml.org > /dev/null
    cat << EOF > /etc/tomcat7/tomcat-users.xml
<?xml version='1.0' encoding='utf-8'?>
<tomcat-users>
  <role rolename="manager-gui"/>
  <role rolename="admin-gui" />

  <user username="$USERNAME" password="$PASSWORD" roles="manager-gui,admin-gui" />
</tomcat-users>
EOF

    echo "Making sure that the correct tomcat-users.xml is read in server.xml"
    mv /etc/tomcat7/server.xml /etc/tomcat7/server.xml.org > /dev/null
    cat /etc/tomcat7/server.xml.org | sed 's/conf\/tomcat-users.xml/\/etc\/tomcat7\/tomcat-users.xml/' > /etc/tomcat7/server.xml

    echo "Increasing heap size to 512 MB"
    mv /etc/default/tomcat7 /etc/default/tomcat7.org > /dev/null
    cat /etc/default/tomcat7.org | sed 's/^JAVA_OPTS=.*$/JAVA_OPTS="-Djava.awt.headless=true -Xmx512m -XX:+UseConcMarkSweepGC"/' > /etc/default/tomcat7

    echo "Restarting Tomcat"
    service tomcat7 restart

    # Print log statement on where to put war files for deployment
    # it is: /var/lib/tomcat7/webapps

    # Add deployment/undeployment script?

    # nginx config
    echo "Setting up nginx tomcat site"
    cat << EOF > /etc/nginx/sites-available/tomcat
server {
    listen 80; #or change this to your public IP address eg 1.1.1.1:80
    server_name $TOMCAT_FQDN;
    access_log /var/log/nginx/tomcat.access.log;
    error_log /var/log/nginx/tomcat.error.log;

    location / {
        # give site more time to respond
        proxy_read_timeout 120;

        # needed to forward user's IP address
        proxy_set_header  X-Real-IP  \$remote_addr;

        # needed for HTTPS
        proxy_set_header  X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$http_host;
        proxy_redirect off;
        proxy_max_temp_file_size 0;

        proxy_pass http://localhost:8080;
    }
}
EOF
    echo "Enabling tomcat site"
    ln -s /etc/nginx/sites-available/tomcat /etc/nginx/sites-enabled/tomcat > /dev/null

    echo "Restarting nginx"
    service nginx restart
}

function setupLogwatch {
    echo "Setting up logwatch"
    mv /usr/share/logwatch/default.conf/logwatch.conf /usr/share/logwatch/default.conf/logwatch.conf.org > /dev/null
    cat << EOF > /usr/share/logwatch/default.conf/logwatch.conf
########################################################
# This was written and is maintained by:
#    Kirk Bauer <kirk@kaybee.org>
#
# Please send all comments, suggestions, bug reports,
#    etc, to kirk@kaybee.org.
#
########################################################

# NOTE:
#   All these options are the defaults if you run logwatch with no
#   command-line arguments.  You can override all of these on the
#   command-line. 

# You can put comments anywhere you want to.  They are effective for the
# rest of the line.

# this is in the format of <name> = <value>.  Whitespace at the beginning
# and end of the lines is removed.  Whitespace before and after the = sign
# is removed.  Everything is case *insensitive*.

# Yes = True  = On  = 1
# No  = False = Off = 0

# Default Log Directory
# All log-files are assumed to be given relative to this directory.
LogDir = /var/log

# You can override the default temp directory (/tmp) here
TmpDir = /var/cache/logwatch

#Output/Format Options
#By default Logwatch will print to stdout in text with no encoding.
#To make email Default set Output = mail to save to file set Output = file
Output = stdout
#To make Html the default formatting Format = html
Format = html
#To make Base64 [aka uuencode] Encode = base64
Encode = none

# Default person to mail reports to.  Can be a local account or a
# complete email address.  Variable Output should be set to mail, or
# --output mail should be passed on command line to enable mail feature.
MailTo = root
# WHen using option --multiemail, it is possible to specify a different
# email recipient per host processed.  For example, to send the report
# for hostname host1 to user@example.com, use:
#Mailto_host1 = user@example.com
# Multiple recipients can be specified by separating them with a space.

# Default person to mail reports from.  Can be a local account or a
# complete email address.
MailFrom = Logwatch

# if set, the results will be saved in <filename> instead of mailed
# or displayed. Be sure to set Output = file also.
#Filename = /tmp/logwatch

# Use archives?  If set to 'Yes', the archives of logfiles
# (i.e. /var/log/messages.1 or /var/log/messages.1.gz) will
# be searched in addition to the /var/log/messages file.
# This usually will not do much if your range is set to just
# 'Yesterday' or 'Today'... it is probably best used with
# By default this is now set to Yes. To turn off Archives uncomment this.
#Archives = No
# Range = All

# The default time range for the report...
# The current choices are All, Today, Yesterday
Range = yesterday

# The default detail level for the report.
# This can either be Low, Med, High or a number.
# Low = 0
# Med = 5
# High = 10
Detail = Low 


# The 'Service' option expects either the name of a filter
# (in /usr/share/logwatch/scripts/services/*) or 'All'.
# The default service(s) to report on.  This should be left as All for
# most people.  
Service = All
# You can also disable certain services (when specifying all)
Service = "-zz-network"     # Prevents execution of zz-network service, which
                            # prints useful network configuration info.
Service = "-zz-sys"         # Prevents execution of zz-sys service, which
                            # prints useful system configuration info.
Service = "-eximstats"      # Prevents execution of eximstats service, which
                            # is a wrapper for the eximstats program.
# If you only cared about FTP messages, you could use these 2 lines
# instead of the above:
#Service = ftpd-messages   # Processes ftpd messages in /var/log/messages
#Service = ftpd-xferlog    # Processes ftpd messages in /var/log/xferlog
# Maybe you only wanted reports on PAM messages, then you would use:
#Service = pam_pwdb        # PAM_pwdb messages - usually quite a bit
#Service = pam             # General PAM messages... usually not many

# You can also choose to use the 'LogFile' option.  This will cause
# logwatch to only analyze that one logfile.. for example:
#LogFile = messages
# will process /var/log/messages.  This will run all the filters that 
# process that logfile.  This option is probably not too useful to
# most people.  Setting 'Service' to 'All' above analyizes all LogFiles
# anyways...

#
# By default we assume that all Unix systems have sendmail or a sendmail-like system.
# The mailer code Prints a header with To: From: and Subject:.
# At this point you can change the mailer to any thing else that can handle that output
# stream. TODO test variables in the mailer string to see if the To/From/Subject can be set
# From here with out breaking anything. This would allow mail/mailx/nail etc..... -mgt 
mailer = "/usr/sbin/sendmail -t"

#
# With this option set to 'Yes', only log entries for this particular host
# (as returned by 'hostname' command) will be processed.  The hostname
# can also be overridden on the commandline (with --hostname option).  This
# can allow a log host to process only its own logs, or Logwatch can be
# run once per host included in the logfiles. 
#
# The default is to report on all log entries, regardless of its source host.
# Note that some logfiles do not include host information and will not be
# influenced by this setting.
#
#HostLimit = Yes

# vi: shiftwidth=3 tabstop=3 et
EOF

    echo "Setting up logwatch cron.daily"
    rm /etc/cron.daily/00logwatch > /dev/null
    cat << EOF > /etc/cron.daily/00logwatch
#!/bin/bash

#Check if removed-but-not-purged
test -x /usr/share/logwatch/scripts/logwatch.pl || exit 0

#execute
/usr/sbin/logwatch --mailto $EMAIL
EOF
    chmod +x /etc/cron.daily/00logwatch

    echo "Setting up logwatch for nginx"
    mv /usr/share/logwatch/default.conf/logfiles/http.conf /usr/share/logwatch/default.conf/logfiles/http.conf_org
    cat << EOF > /usr/share/logwatch/default.conf/logfiles/http.conf
LogFile = nginx/*access.log
LogFile = nginx/*access.log.1

Archive = nginx/*access.log.*.gz

# Expand the repeats (actually just removes them now)
*ExpandRepeats

# Keep only the lines in the proper date range...
*ApplyhttpDate

EOF
}

function setupUser {
    set +e
    /bin/egrep  -i "^${USERNAME}" /etc/passwd
    if [ $? -eq 0 ]; then
       echo "User $USERNAME already exists"
    else
       echo "Adding user $USERNAME"
       adduser $USERNAME
       usermod -a -G sudo $USERNAME
    fi
    set -e
}

function setupBash {
    
    echo "Setting up bash profile"

    rm /home/$USERNAME/.profile > /dev/null
    rm /home/$USERNAME/.bashrc > /dev/null
    
    
    cat << EOF > /home/$USERNAME/.profile
# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "\$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "\$HOME/.bashrc" ]; then
    . "\$HOME/.bashrc"
    fi
fi
EOF

    cat << EOF > /home/$USERNAME/.bashrc
###
# git settings
###
function parse_git_deleted {
 [[ \$(git status 2> /dev/null | grep deleted:) != "" ]] && echo -ne "\033[0;31m-\033[0m"
}

function parse_git_added {
 [[ \$(git status 2> /dev/null | grep "Untracked files:") != "" ]] && echo -ne "\033[0;34m+\033[0m"
}

function parse_git_modified {
 [[ \$(git status 2> /dev/null | grep modified:) != "" ]] && echo -ne "\033[0;33m*\033[0m"
}

function parse_git_dirty {
 # [[ \$(git status 2> /dev/null | tail -n1) != "nothing to commit (working directory clean)" ]] && echo "  "
 echo "\$(parse_git_added)\$(parse_git_modified)\$(parse_git_deleted)"
}

function parse_git_branch {
 git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e "s/* \(.*\)/ [\1 \$(parse_git_dirty)] /"
}

function eh {
    echo "Commands to take advantage of bash's Emacs Mode:"
    echo "  ctrl-a    Move cursor to beginning of line"
    echo "  ctrl-e    Move cursor to end of line"
    echo "  meta-b    Move cursor back one word"
    echo "  meta-f    Move cursor forward one word"
    echo "  ctrl-w    Cut the last word"
    echo "  ctrl-u    Cut everything before the cursor"
    echo "  ctrl-k    Cut everything after the cursor"
    echo "  ctrl-y    Paste the last thing to be cut"
    echo "  ctrl-_    Undo"
    echo ""
    echo "NOTE: ctrl- = hold control, meta- = hold meta (where meta is usually the alt or escape key)."
    echo ""
}


# If not running interactively, don't do anything
[ -z "\$PS1" ] && return

# History settings
HISTCONTROL=erasedups:ignorespace
export HISTSIZE=10000
export HISTIGNORE="ls:cd:history:kali"
shopt -s histappend

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# Load bash aliases if they exist
if [ -f ~/.bash_aliases ]; then
    source ~/.bash_aliases
fi

# Load local aliases if they exist
if [ -f ~/.local_bash_aliases ]; then
    source ~/.local_bash_aliases
fi

# Update PATH for local bin
export PATH=~/bin:\$PATH

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "\$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "\$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=\$(cat /etc/debian_chroot)
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
    . /etc/bash_completion
fi

# Extra environments
if [ -f ~/.java_environment ]; then
    source ~/.java_environment
fi

# Set Emacs mode in BASH
set -o emacs

export PS1='\[\033]0;\u@\h: \w\007\]\n\[\033[0;36m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$(parse_git_branch)\n\[\e[0;33m\][hist: \!] \\$\[\033[0m\] '

EOF

    cat << EOF > /home/$USERNAME/.bash_aliases
alias ..='cd ..'
alias ...='cd ../..'
alias ls='ls --color=auto'
alias lsd='ls -r --sort=time --color=auto'

alias home='ssh emil@home.emibre.com'

alias emacs='emacs -nw'

alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
EOF

    # Create bin directory for scripts
    mkdir -p /home/$USERNAME/bin

    echo "Installing deployWar script"
    cat << EOF > /home/$USERNAME/bin/deployWar
#!/bin/bash

webappDir="/var/lib/tomcat7/webapps"
war=\$1

die () {
    echo >&2 "\$@"
    exit 1
}

[ "\$#" -eq 1 ] || die "1 argument required, \$# provided"

if [ ! -f "\$war" ]
then
    die "\$war was not found"
fi

echo "Deploying \$war to \$webappDir"
sudo cp \$war \$webappDir
EOF
    
    echo "Installing undeployWar script"
    cat << EOF > /home/$USERNAME/bin/undeployWar
#!/bin/bash

webappDir="/var/lib/tomcat7/webapps"
war=\$1

die () {
    echo >&2 "\$@"
    exit 1
}

[ "\$#" -eq 1 ] || die "1 argument required, \$# provided"

if [ ! -f "\$webappDir/\$war" ]
then
    echo "Available war files are:"
    for i in "\$webappDir/*.war"
    do
        echo \$i
    done
    echo ""
    die "\$war was not found"
fi

echo "Undeploying \$war"
sudo rm \$webappDir/\$war
EOF

    # Fix ownership
    chown -R $USERNAME:$USERNAME /home/$USERNAME

    # Fix executables in bin
    chmod +x /home/$USERNAME/bin/*
     
}

function addCronJobWordPressBackup {
    echo "Adding cron job for Wordpress backup"
}

#####################################################################
# Configure
#####################################################################
installPackages
setupTimeZone
setupSSH
setupHostName
setupIPTables
setupFastCGI
setupWordPress
setupPostfix
setupFail2ban
setupTomcat
setupLogwatch
setupUser
setupBash
addCronJobWordPressBackup
