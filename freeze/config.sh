###
# Shared configuration
###

export USERNAME=emil
export HOSTNAME=newzindexer

export FFMPEG_VERSION=0.9.1
export SPHINX_VERSION=2.0.4-release
export PERCONA_VERSION=5.5
export THREADS_COMPILE=`cat /proc/cpuinfo | grep processor | wc -l`

# no limit: -1, otherwise 256MB
export PHP_MEMORY_LIMIT=-1

# Available timezone settings: http://uk.php.net/manual/en/timezones.php
export PHP_DATE_TIMEZONE="Europe\/Stockholm"

# Value in seconds, 120 recommended
export PHP_MAX_EXECUTION_TIME=180

# Maximum ram usage for memcached (MB)
export MEMCACHED_MAX_MEMORY=512

export UBUNTU_VERSION=`lsb_release -s -r`
echo "Ubuntu ver: $UBUNTU_VERSION"