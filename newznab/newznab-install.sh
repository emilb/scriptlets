#!/bin/bash -eu

###
# newznab install
# 
# newznab id: 6A21FB32-24ED-472E-8976-B6138091C39B
# tmdb: 8244ac6bb3c73d30e5ca63b16bf06791
# tomatoes: 7h2wsd8hrjsxp8p5hz328vce
#
# mysql> select name from groups where active = 1;
# +-----------------------------------------+
# | name                                    |
# +-----------------------------------------+
# | alt.binaries.dvdr                       |
# | alt.binaries.multimedia                 |
# | alt.binaries.movies.divx                |
# | alt.binaries.movies.xvid                |
# | alt.binaries.hdtv.x264                  |
# | alt.binaries.games.xbox360              |
# | alt.binaries.x264                       |
# | alt.binaries.moovee                     |
# | alt.binaries.inner-sanctum              |
# | alt.binaries.teevee                     |
# | alt.binaries.warez                      |
# | alt.binaries.mp3                        |
# | alt.binaries.mac                        |
# | alt.binaries.e-book                     |
# | alt.binaries.warez.ibm-pc.0-day         |
# | alt.binaries.tvseries                   |
# | alt.binaries.erotica                    |
# | alt.binaries.games                      |
# | alt.binaries.e-book.technical           |
# | alt.binaries.erotica.divx               |
# | alt.binaries.sounds.lossless            |
# | alt.binaries.e-book.flood               |
# | alt.binaries.movies.erotica             |
# | alt.binaries.multimedia.erotica.amateur |
# | alt.binaries.sounds.mp3                 |
# | alt.binaries.mp3.audiobooks             |
# | alt.binaries.sounds.mp3.full_albums     |
# | alt.binaries.multimedia.sitcoms         |
# | alt.binaries.sound.mp3                  |
# | alt.binaries.dvd.movies                 |
# | alt.binaries.ebook                      |
# | alt.binaries.mp3.full_albums            |
# | alt.binaries.uzenet                     |
# | alt.binaries.mom                        |
# | alt.binaries.multimedia.tv              |
# | alt.binaries.sound.audiobooks           |
# | alt.binaries.music.flac                 |
# | alt.binaries.boneless                   |
# | alt.binaries.hdtv                       |
# | alt.binaries.movies                     |
# | alt.binaries.worms                      |
# | alt.binaries.0day.stuffz                |
# | alt.binaries.xbox360.gamez              |
# | alt.binaries.wb                         |
# | alt.binaries.sounds.flac                |
# | alt.binaries.drummers                   |
# +-----------------------------------------+
# 46 rows in set (0.01 sec)
#
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

source config.sh


# Mediainfo
echo "Checking if mediainfo is installed..."
#if dpkg-query -W -f='${Status} ${Version}\n' mediainfo 2>/dev/null 1>/dev/null; then
if which mediainfo 2>/dev/null 1>/dev/null; then
    echo "mediainfo already installed"
else
    echo "mediainfo NOT installed, installing now"
    echo "Downloading mediainfo"

# Old version, better to download and compile latest
#    apt-get -qq -y install python-software-properties > /dev/null
#    add-apt-repository ppa:shiki/mediainfo
#    apt-get update > /dev/null
#    apt-get -qq -y install mediainfo > /dev/null

    wget http://ovh.dl.sourceforge.net/sourceforge/mediainfo/MediaInfo_CLI_0.7.56_GNU_FromSource.tar.bz2
    bzip2 -d MediaInfo_CLI_0.7.56_GNU_FromSource.tar.bz2
    tar xvf MediaInfo_CLI_0.7.56_GNU_FromSource.tar
    cd MediaInfo_CLI_GNU_FromSource
    sh CLI_Compile.sh
    cd MediaInfo/Project/GNU/CLI
    make install
fi

#Percona (only for Ubuntu 11.10)
if [ $UBUNTU_VERSION = '11.10' ]; then
    echo "Checking if Percona is installed..."
    if dpkg-query -W -f='${Status} ${Version}\n' percona-server-server-$PERCONA_VERSION 2>/dev/null 1>/dev/null; then
        echo "Percona already installed"
    else
        echo "Percona NOT installed, installing now"
        echo "Installing Percona"
        gpg --keyserver  hkp://keys.gnupg.net --recv-keys 1C4CBDCDCD2EFD2A
        gpg -a --export CD2EFD2A | apt-key add -

        sh -c "echo  \"\n#Percona\" >> /etc/apt/sources.list"
        sh -c "echo  \"deb http://repo.percona.com/apt lenny main\" >> /etc/apt/sources.list"
        sh -c "echo  \"deb-src http://repo.percona.com/apt lenny main\" >> /etc/apt/sources.list"

        apt-get update > /dev/null
        apt-get -qq -y install percona-server-client-$PERCONA_VERSION percona-server-server-$PERCONA_VERSION libmysqlclient-dev       
    fi  
elif [ $UBUNTU_VERSION = '12.04' ]; then
    apt-get -qq -y install mysql-client-5.5 mysql-server-5.5 libmysqlclient-dev
else
    echo "This script is not prepared for Ubuntu version $UBUNTU_VERSION"
    exit -1
fi



function installFFMpeg {

    if which ffmpeg 2>/dev/null 1>/dev/null; then
        echo "ffmpeg already installed"
    else
        wget http://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.gz
        wget ftp://ftp.videolan.org/pub/videolan/x264/snapshots/last_stable_x264.tar.bz2

        mkdir -p x264
        tar --strip-components=1 -jxf last_stable_x264.tar.bz2 -C x264
        cd x264
        ./configure --enable-static
        make -j$THREADS_COMPILE
        checkinstall --pkgname=x264 --pkgversion="3:$(./version.sh | awk -F'[" ]' '/POINT/{print $4$5}')" --backup=no --deldoc=yes --fstrans=no --default

        cd ../
        tar xvfz ffmpeg-$FFMPEG_VERSION.tar.gz
        cd ffmpeg-$FFMPEG_VERSION/
        ./configure --enable-gpl --enable-libfaac --enable-libmp3lame --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-libtheora --enable-libvorbis --enable-libx264 --enable-nonfree --enable-postproc --enable-version3 --enable-x11grab --enable-libdirac --enable-libxvid
        make -j$THREADS_COMPILE
        checkinstall --pkgname=ffmpeg --pkgversion="5:$FFMPEG_VERSION" --backup=no --deldoc=yes --fstrans=no --default
        hash x264 ffmpeg ffplay ffprobe
    fi
}

function installSphinx {
    wget http://sphinxsearch.com/files/sphinx-$SPHINX_VERSION.tar.gz
    tar xvfz sphinx-$SPHINX_VERSION.tar.gz
    cd sphinx-$SPHINX_VERSION

    wget http://snowball.tartarus.org/dist/libstemmer_c.tgz
    tar --strip-components=1 -zxf libstemmer_c.tgz -C libstemmer_c

    ./configure --prefix=/usr/local --with-libstemmer
    make -j$THREADS_COMPILE

    checkinstall --pkgname=sphinx --pkgversion="$SPHINX_VERSION" --backup=no --deldoc=yes --fstrans=no --default
}

function setupApache {
    # Create virtual host
    cat << EOF > /etc/apache2/sites-available/newznab
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    ServerName $HOSTNAME

    DocumentRoot /var/www/newznab/www
    ErrorLog /var/log/apache2/error.log
    LogLevel warn
</VirtualHost>

EOF

    a2dissite default
    a2ensite newznab
    a2enmod rewrite
    service apache2 restart
}

function setupNewznab {
    echo "Creating newznab_screen_local.sh"
    cat /var/www/newznab/misc/update_scripts/nix_scripts/newznab_screen.sh | sed 's/export NEWZNAB_PATH=.*/export NEWZNAB_PATH="\/var\/www\/newznab\/misc\/update_scripts"/' > /var/www/newznab/misc/update_scripts/nix_scripts/newznab_screen_local.sh
    chown $USERNAME:$USERNAME /var/www/newznab/misc/update_scripts/nix_scripts/newznab_screen_local.sh

    echo "Creating screen cron job for newznab_screen_local"
    cat << EOF > /home/$USERNAME/bin/newznab_screen.sh
#!/bin/sh

# Check that the process isn't running already
processCount=\`ps auxw | grep newznab_screen_local.sh | grep -v grep | wc -l | awk '{gsub(/^ +| +$/,"")}1'\`;
if [ \$processCount -gt 1 ]
then
    exit 0;
fi
 
# Check that script file exists
if [ ! -f /var/www/newznab/misc/update_scripts/nix_scripts/newznab_screen_local.sh ]
then
        echo "Could not find /var/www/newznab/misc/update_scripts/nix_scripts/newznab_screen_local.sh to run";
        exit 1;
fi

/usr/bin/screen -d -m -S newznab /bin/sh /var/www/newznab/misc/update_scripts/nix_scripts/newznab_screen_local.sh
EOF

    chown $USERNAME:$USERNAME /home/$USERNAME/bin/newznab_screen.sh
    chmod +x /home/$USERNAME/bin/newznab_screen.sh
    
    echo "Installing cron starter for newnab"
    echo "* * * * *      $USERNAME       /home/$USERNAME/bin/newznab_screen.sh" | tee -a /etc/crontab
}

function setupSphinx {
    echo "Creating cron script for nnindexer"
    cat << EOF > /home/$USERNAME/bin/nnindexer.sh
#!/bin/sh

# Check that the process isn't running already
processCount=\`ps auxw | grep searchd | grep -v grep | grep -v sh | wc -l | awk '{gsub(/^ +| +$/,"")}1'\`;
if [ \$processCount -gt 0 ]
then
    exit 0;
fi
 
# Check that script file exists
if [ ! -f /var/www/newznab/misc/sphinx/nnindexer.php ]
then
        echo "Could not find /var/www/newznab/misc/sphinx/nnindexer.php to run";
        exit 1;
fi

/usr/bin/php5 /var/www/newznab/misc/sphinx/nnindexer.php daemon
EOF

    chown $USERNAME:$USERNAME /home/$USERNAME/bin/nnindexer.sh
    chmod +x /home/$USERNAME/bin/nnindexer.sh

    echo "Goto http://$HOSTNAME/install and setup your configuration. Enable sphinx to continue"
    read -p "Press [Enter] key to start sphinx..."

    /var/www/newznab/misc/sphinx/nnindexer.php generate

    /var/www/newznab/misc/sphinx/nnindexer.php daemon
    /var/www/newznab/misc/sphinx/nnindexer.php index full all
    /var/www/newznab/misc/sphinx/nnindexer.php index delta all
    /var/www/newznab/misc/sphinx/nnindexer.php daemon --stop

    chown -R $USERNAME:$USERNAME /var/www/newznab
    
    echo "Installing cron starter for nnindexer"
    echo "* * * * *      $USERNAME       /home/$USERNAME/bin/nnindexer.sh" | tee -a /etc/crontab
}

function installNewznab {
    mkdir -p /var/www/newznab
    chmod 777 /var/www/newznab

    svn co svn://svn.newznab.com/nn/branches/nnplus /var/www/newznab

    chmod 777 /var/www/newznab/www/lib/smarty/templates_c
    chmod 777 /var/www/newznab/www/covers/movies
    chmod 777 /var/www/newznab/www/covers/anime
    chmod 777 /var/www/newznab/www/covers/music
    chmod 777 /var/www/newznab/www
    chmod 777 /var/www/newznab/www/install
    chmod 777 /var/www/newznab/nzbfiles/

    chown -R $USERNAME:$USERNAME /var/www/newznab
}

function setupPHP {
    FILENAME=$1

    cp $FILENAME "$FILENAME"_org

    if ( grep 'register_globals = Off' $FILENAME ); then
        echo "register_globals already off!"
    else
        echo "Setting register_globals = Off"
        cat $FILENAME | sed 's/register_globals.*/register_globals = Off/' > "$FILENAME"_1
        mv "$FILENAME"_1 $FILENAME
    fi

    echo "Setting max_execution_time = $PHP_MAX_EXECUTION_TIME"
    cat $FILENAME | sed "s/max_execution_time =.*/max_execution_time = $PHP_MAX_EXECUTION_TIME/" > "$FILENAME"_1
    mv "$FILENAME"_1 $FILENAME

    echo "Setting memory_limit = $PHP_MEMORY_LIMIT"
    cat $FILENAME | sed "s/memory_limit =.*/memory_limit = $PHP_MEMORY_LIMIT/" > "$FILENAME"_1
    mv "$FILENAME"_1 $FILENAME

    echo "Setting date.timezone = $PHP_DATE_TIMEZONE"
    cat $FILENAME | sed "s/.*date\.timezone =.*/date\.timezone = $PHP_DATE_TIMEZONE/" > "$FILENAME"_1
    mv "$FILENAME"_1 $FILENAME
}

function setupMemcached {
    FILENAME="/etc/memcached.conf"

    cp $FILENAME "$FILENAME"_org

    echo "Setting memory for memcached = $MEMCACHED_MAX_MEMORY"
    cat $FILENAME | sed "s/-m.*/-m $MEMCACHED_MAX_MEMORY/" > "$FILENAME"_1
    mv "$FILENAME"_1 $FILENAME

    service memcached restart
}

installFFMpeg
installSphinx
setupPHP /etc/php5/cli/php.ini
setupPHP /etc/php5/apache2/php.ini
setupMemcached
installNewznab
setupNewznab
setupApache
setupSphinx


echo "newznab install complete"