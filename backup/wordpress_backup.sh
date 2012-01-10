#!/bin/bash

# Based on a script at http://itpoetry.wordpress.com/2008/02/07/bash-script-to-export-and-backup-some-data/

# Info: Bash script to download the export file for WordPress blogs and
#       accompanying media files.
#
#       The export XML file contains "posts, pages, comments, custom fields, 
#       categories, and tags." Though it does not contain media uploaded. This 
#       script will try to grab those too (but it may not be 100% reliable).

# Usage: ./scriptname [prefix]
#        prefix (optional)
#            the directory to store the xml file and the other media files.
#            default is the current directory (.)

# Author: Andrew Harvey (http://andrewharvey4.wordpress.com/)
# Date: 07 Dec 2009

# Copyright: http://creativecommons.org/publicdomain/zero/1.0/
#
# The person who associated a work with this document has dedicated the work to
# the Commons by waiving all of his or her rights to the work worldwide under 
# copyright law and all related or neighboring legal rights he or she had in the
# work, to the extent allowable by law.
#
# Works under CC0 do not require attribution. When citing the work, you should 
# not imply endorsement by the author.
#
# Additions and deviations from original script by Emil Breding, freely available at:
# https://github.com/emilb/scriptlets
#
# The devation from original script is a simplification for when hosting your own WP-blog
# at your own domain. 
# Date: 10 jan 2011

#if you leave these empty, the script will try to get them interactively
wpuser='' #WordPress user name
wppwd='' #WordPress password
wphostname='' #WordPress host

timestamp=`date +%Y%m%d%H%M`; #for our export file

#check for prefix in arguments
case $# in
1) prefix=$1;;
*) prefix='./';;
esac

#check to add / after directory if ommited
if [ -f $prefix ]; then
	echo "$prefix is not a directory (did you forget the trailing / ?)"
	exit 1
fi

mkdir -p $prefix

echo "Saving files in $prefix"

#if we don't have the variables defined, ask the user
#hacky way to do an if...
[ "$wpuser" == "" ] && echo "Please enter your WordPress user name:" && read wpuser;
[ "$wppwd" == "" ] && echo "Please enter your WordPress user password:" && read wppwd;
[ "$wphostname" == "" ] && echo "Please enter your WordPress host name:" && read wphostname;

echo "Exporting WordPress blog: $wphostname by $wpuser";

mkdir -p temp
cookies="temp/cookies.txt";
touch $cookies

echo "Logging in to $wphost";

echo "Getting the cookies check cookie...";
#set the cookie that we must accept to prove we can store cookies
curl --cookie-jar "$cookies"\
     --output /dev/null \
     "http://${wphostname}/wp-login.php"

echo "Setting the authentication cookies...";
#get the session cookies (ie. login)
#post data:
#log	username
#pwd	password
#redirect_to	http://${wphostname}/wp-admin/
#rememberme	forever
#testcookie	1
#wp-submit	Log In
#will try to take us to the /wp-admin/ page. but we don't need to.
#can't use wget (it won't save cookies with a path not in the path of the 
#requested resource)
curl --cookie-jar "$cookies" \
     --output "temp/login.html" \
     --max-redirs 0 \
	 --data "log=${wpuser}&pwd=${wppwd}&rememberme=forever&redirect_to=http%3A%2F%2F${wphostname}%2Fwp-admin%2F&testcookie=1&wp-submit=Log%20In" \
     "http://${wphostname}/wp-login.php"

#we're using https so don't worry, leaving it in seems to cause wget not to use the cookie
cat "$cookies" | sed 's/#HttpOnly_//' > temp/cookies2.txt
mv temp/cookies2.txt "$cookies"

target=${wphostname}.${timestamp}.xml
target_full="${prefix}${target}"

echo "Downloading export to $target";
wget --secure-protocol=auto \
     --keep-session-cookies \
     --load-cookies "$cookies" \
   	 --output-document="$target_full" \
 	 --max-redirect=0\
	 "http://${wphostname}/wp-admin/export.php?download=true&submit=Download%20Export%20File"

#may fail this test and things are still okay if things get changed at emibre.com
#just comment this out if you wan't to go ahead anyway
if grep --quiet '<!-- generator="WordPress' "$target_full"; then #successfully saved export file
	echo "Sucessfully Exported Blog"
else #failed
	echo "Exported file does not look correct."
	exit 2
fi

echo "Downloading media files... (may take a while)"
#download any uploaded media files (I only check for ones that have .ext where .ext is allowed)
#these may change over time, and certain addon products allow more.
egrep -oe "http://${wphostname}[^\"]*\.((jpg)|(jpeg)|(png)|(gif)|(pdf)|(doc)|(ppt)|(odt)|(pptx)|(docx))" "$target_full" | sort | uniq > temp/files.txt

#two methods to scrape the media url's. both methods seem to yeild the same result
#grep -oe "http://${wpblog}\.files\.wordpress\.com.*" "$target" | sed s/\".*// | sed s/\<.*//| sort | uniq
#egrep -oe "http://${wpblog}\.files\.wordpress\.com[^\"]*\.((jpg)|(jpeg)|(png)|(gif)|(pdf)|(doc)|(ppt)|(odt)|(pptx)|(docx))" "$target" | sort | uniq

#now download all those files (doesn't redownload if existing file is no older than one on server)
wget --input-file="temp/files.txt" \
     --force-directories \
     --directory-prefix="${prefix}${wphostname}_files" \
     --timestamping \
     --quiet
     
#in place of above could try --input-file="$target" with the XML rather than
#using a list of scraped url's...

#clean up
rm -Rf temp/