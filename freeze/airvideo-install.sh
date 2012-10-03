#!/bin/bash -eu

###
# air video install
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

source config.sh

echo "Installing media libraries"
apt-get install -qq -y faac libx264-dev libschroedinger-1.0-0 libgsm1 libspeex1 libva1 libvpx0 libmp3lame0 libsdl1.2debian libxvidcore4 > /dev/null

echo "Installing avahi-daemon"
apt-get install -qq -y avahi-daemon > /dev/null

mkdir -p airvideo.tmp > /dev/null
cd airvideo.tmp > /dev/null

echo "Downloading missing Ubuntu 11.10 packages..."
wget http://security.ubuntu.com/ubuntu/pool/main/liba/libav/libavutil50_0.6.4-0ubuntu0.11.04.1_amd64.deb > /dev/null
wget http://security.ubuntu.com/ubuntu/pool/universe/liba/libav-extra/libavutil-extra-50_0.6.4-1ubuntu1_amd64.deb > /dev/null
wget http://ubuntu.mirror.cambrium.nl/ubuntu/pool/main/s/schroedinger/libschroedinger-1.0-0_1.0.10-2_amd64.deb > /dev/null
wget http://security.ubuntu.com/ubuntu/pool/main/liba/libav/libavcodec52_0.6.4-0ubuntu0.11.04.1_amd64.deb > /dev/null
wget http://ubuntu.mirror.cambrium.nl/ubuntu/pool/multiverse/m/mpeg4ip/libmp4v2-0_1.6dfsg-0.2ubuntu9_amd64.deb > /dev/null
wget http://ubuntu.mirror.cambrium.nl/ubuntu/pool/multiverse/m/mpeg4ip/libmpeg4ip-0_1.6dfsg-0.2ubuntu9_amd64.deb > /dev/null
wget http://ubuntu.mirror.cambrium.nl/ubuntu/pool/multiverse/m/mpeg4ip/mpeg4ip-server_1.6dfsg-0.2ubuntu9_amd64.deb > /dev/null

echo "Installing missing Ubuntu 11.10 packages"
dpkg -i libavutil50_0.6.4-0ubuntu0.11.04.1_amd64.deb > /dev/null
dpkg -i libavutil-extra-50_0.6.4-1ubuntu1_amd64.deb > /dev/null
dpkg -i libavcodec52_0.6.4-0ubuntu0.11.04.1_amd64.deb > /dev/null
dpkg -i libschroedinger-1.0-0_1.0.10-2_amd64.deb > /dev/null
dpkg -i libmp4v2-0_1.6dfsg-0.2ubuntu9_amd64.deb > /dev/null
dpkg -i libmpeg4ip-0_1.6dfsg-0.2ubuntu9_amd64.deb > /dev/null
dpkg -i mpeg4ip-server_1.6dfsg-0.2ubuntu9_amd64.deb > /dev/null

echo "Downloading air video version of ffmpeg"
wget http://inmethod.com/air-video/download/ffmpeg-for-2.4.5-beta6.tar.bz2 > /dev/null

echo "Unpacking ffmpeg"
tar xvjf ffmpeg-for-2.4.5-beta6.tar.bz2 > /dev/null
cd ffmpeg > /dev/null

echo "Configuring ffmpeg"
./configure --enable-pthreads --disable-shared --enable-static --enable-gpl --enable-libx264 --enable-libmp3lame  > /dev/null

echo "Compiling ffmpeg"
make -j$THREADS_COMPILE > /dev/null

echo "Downloading alpha6 of air video server"
wget http://inmethod.com/air-video/download/linux/alpha6/AirVideoServerLinux.jar > /dev/null


echo "Installing to /opt/airvideoserver"
mkdir -p /opt/airvideoserver > /dev/null
cp ffmpeg /opt/airvideoserver/ > /dev/null
cp AirVideoServerLinux.jar /opt/airvideoserver/ > /dev/null

cat << EOF > /opt/airvideoserver/airvideoserver.properties
path.ffmpeg = /opt/airvideoserver/ffmpeg
path.mp4creator = /usr/bin/mp4creator
path.faac = /usr/bin/faac
password =
subtitles.encoding = windows-1250
subtitles.font = Verdana
folders = Movies:/home/$USERNAME/movies,Series:/home/$USERNAME/tv
EOF

echo "Installing avahi service"
cat << EOF > /etc/avahi/services/avs.service
<?xml version="1.0" standalone="no"?>
<!--*-nxml-*-->
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h</name>
  <service>
    <type>_device-info._tcp</type>
    <port>0</port>
    <txt-record>model=RackMac</txt-record>
  </service>
  <service>
    <type>_http._tcp</type>
    <port>80</port>
  </service>
  <service>
    <type>_ssh._tcp</type>
    <port>22</port>
  </service>
  <service>
    <type>_sftp-ssh._tcp</type>
    <port>22</port>
  </service>
  <service>
    <type>_airvideoserver._tcp</type>
    <port>45631</port>
  </service>
</service-group>
EOF
restart avahi-daemon


echo "Installing as an upstart service"
cat << EOF > /etc/init/avs.conf
start on runlevel [2345]
stop on shutdown
respawn
exec /usr/bin/java -jar /opt/airvideoserver/AirVideoServerLinux.jar /opt/airvideoserver/airvideoserver.properties
EOF
service avs start


echo "Cleaing up"
cd ..
cd ..
rm -rdf airvideo.tmp

echo "air video install complete"
