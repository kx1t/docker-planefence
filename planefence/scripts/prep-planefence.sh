#!/usr/bin/with-contenv bash
#shellcheck shell=bash
# -----------------------------------------------------------------------------------
# Copyright 2020, 2021 Ramon F. Kolb - licensed under the terms and conditions
# of GPLv3. The terms and conditions of this license are included with the Github
# distribution of this package, and are also available here:
# https://github.com/kx1t/planefence4docker/
#
# Programmers note: when using sed for URLs or file names, make sure NOT to use '/'
# as command separator, but use something else instead, for example '|'
#
# -----------------------------------------------------------------------------------
#
PLANEFENCEDIR=/usr/share/planefence
APPNAME="planefence"

echo "[$APPNAME][$(date)] Running PlaneFence configuration - either the container is restarted or a config change was detected."
# Sometimes, variables are passed in through .env in the Docker-compose directory
# However, if there is a planefence.config file in the ..../persist directory
# (by default exposed to ~/.planefence) then export all of those variables as well
# note that the grep strips off any spaces at the beginning of a line, and any commented line
if [[ -f /usr/share/planefence/persist/planefence.config ]]
then
	set -o allexport
	source /usr/share/planefence/persist/planefence.config
	set +o allexport
else
	cp -n /usr/share/planefence/stage/planefence.config /usr/share/planefence/persist/planefence.config-RENAME-and-EDIT-me
fi
#
# -----------------------------------------------------------------------------------
#
# Move the jscript files from the staging directory into the html directory.
# this cannot be done at build time because the directory is exposed and it is
# overwritten by the host at start of runtime
cp -n /usr/share/planefence/stage/* /usr/share/planefence/html
rm -f /usr/share/planefence/html/planefence.config
[[ ! -f /usr/share/planefence/persist/planefence-ignore.txt ]] && mv -f /usr/share/planefence/html/planefence-ignore.txt /usr/share/planefence/persist/ || rm -f /usr/share/planefence/html/planefence-ignore.txt
#
# Copy the airlinecodes.txt file to the persist directory
cp -n /usr/share/planefence/airlinecodes.txt /usr/share/planefence/persist
#
#--------------------------------------------------------------------------------
#
# Now initialize Plane Alert. Note that this isn't in its own s6 runtime because it's
# only called synchronously from planefence (if enabled)
#
mkdir -p /usr/share/planefence/html/plane-alert
# Sync the plane-alert DB with a preference for newer versions on the persist volume:
cp -n /usr/share/plane-alert/plane-alert-db.txt /usr/share/planefence/persist
ln -sf /usr/share/planefence/persist/plane-alert-db.txt /usr/share/planefence/html/plane-alert/alertlist.txt
#
# LOOPTIME is the time between two runs of PlaneFence (in seconds)
if [[ "$PF_INTERVAL" != "" ]]
then
        export LOOPTIME=$PF_INTERVAL

else
        export LOOPTIME=120
fi
#
# PLANEFENCEDIR contains the directory where planefence.sh is location

#
# Make sure the /run directory exists
mkdir -p /run/planefence
# -----------------------------------------------------------------------------------
# Do one last check. If FEEDER_LAT= empty or 90.12345, then the user obviously hasn't touched the config file.
if [[ "x$FEEDER_LAT" == "x" ]] || [[ "$FEEDER_LAT" == "90.12345" ]]
then
		sleep 10s
		echo "----------------------------------------------------------"
		echo "!!! STOP !!!! You haven't configured FEEDER_LON and/or FEEDER_LAT for PlaneFence !!!!"
		echo "Planefence will not run unless you edit it configuration."
		echo "You can do this by pressing CTRL-c now and typing:"
		echo "sudo nano -l ~/.planefence/planefence.config"
		echo "Once done, restart the container and this message should disappear."
		echo "----------------------------------------------------------"
		while true
		do
				sleep 99999
		done
fi

#
# Set logging in planefence.conf:
#
if [[ "$PF_LOG" == "off" ]]
then
	export LOGFILE=/dev/null
	sed -i 's/\(^\s*VERBOSE=\).*/\1'""'/' /usr/share/planefence/planefence.conf
else
	[[ "x$PF_LOG" == "x" ]] && export LOGFILE="/tmp/planefence.log" || export LOGFILE="$PF_LOG"
fi
# echo pflog=$PF_LOG and logfile=$LOGFILE
sed -i 's|\(^\s*LOGFILE=\).*|\1'"$LOGFILE"'|' /usr/share/planefence/planefence.conf
#
# -----------------------------------------------------------------------------------
#
# read the environment variables and put them in the planefence.conf file:
[[ "x$FEEDER_LAT" != "x" ]] && sed -i 's/\(^\s*LAT=\).*/\1'"\"$FEEDER_LAT\""'/' /usr/share/planefence/planefence.conf || { echo "Error - \$FEEDER_LAT ($FEEDER_LAT) not defined"; while :; do sleep 2073600; done; }
[[ "x$FEEDER_LONG" != "x" ]] && sed -i 's/\(^\s*LON=\).*/\1'"\"$FEEDER_LONG\""'/' /usr/share/planefence/planefence.conf || { echo "Error - \$FEEDER_LONG not defined"; while :; do sleep 2073600; done; }
[[ "x$PF_MAXALT" != "x" ]] && sed -i 's/\(^\s*MAXALT=\).*/\1'"\"$PF_MAXALT\""'/' /usr/share/planefence/planefence.conf
[[ "x$PF_MAXDIST" != "x" ]] && sed -i 's/\(^\s*DIST=\).*/\1'"\"$PF_MAXDIST\""'/' /usr/share/planefence/planefence.conf
[[ "x$PF_NAME" != "x" ]] && sed -i 's/\(^\s*MY=\).*/\1'"\"$PF_NAME\""'/' /usr/share/planefence/planefence.conf || sed -i 's/\(^\s*MY=\).*/\1\"My\"/' /usr/share/planefence/planefence.conf
[[ "x$PF_TRACKSVC" != "x" ]] && sed -i 's|\(^\s*TRACKSERVICE=\).*|\1'"\"$PF_TRACKSVC\""'|' /usr/share/planefence/planefence.conf
[[ "x$PF_MAPURL" != "x" ]] && sed -i 's|\(^\s*MYURL=\).*|\1'"\"$PF_MAPURL\""'|' /usr/share/planefence/planefence.conf || sed -i 's|\(^\s*MYURL=\).*|\1|' /usr/share/planefence/planefence.conf
[[ "x$PF_NOISECAPT" != "x" ]] && sed -i 's|\(^\s*REMOTENOISE=\).*|\1'"\"$PF_NOISECAPT\""'|' /usr/share/planefence/planefence.conf || sed -i 's|\(^\s*REMOTENOISE=\).*|\1|' /usr/share/planefence/planefence.conf
[[ "x$PF_FUDGELOC" != "x" ]] && sed -i 's|\(^\s*FUDGELOC=\).*|\1'"\"$PF_FUDGELOC\""'|' /usr/share/planefence/planefence.conf || sed -i 's|\(^\s*FUDGELOC=\).*|\1|' /usr/share/planefence/planefence.conf
if [[ "x$PF_SOCK30003HOST" != "x" ]]
then
	a=$(sed 's|\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)|\1\_\2\_\3\_\4|g' <<< "$PF_SOCK30003HOST")
	sed -i 's|\(^\s*LOGFILEBASE=/run/socket30003/dump1090-\).*|\1'"$a"'-|' /usr/share/planefence/planefence.conf
	sed -i 's/127_0_0_1/'"$a"'/' /usr/share/planefence/planeheat.sh
	unset a
else
	sleep 10s
	echo "----------------------------------------------------------"
	echo "!!! STOP !!!! You haven't configured PF_SOCK30003HOST for PlaneFence !!!!"
	echo "Planefence will not run unless you edit it configuration."
	echo "You can do this by pressing CTRL-c now and typing:"
	echo "sudo nano -l ~/.planefence/planefence.config"
	echo "Once done, restart the container and this message should disappear."
	echo "----------------------------------------------------------"
	while true
	do
			sleep 99999
	done
fi
[[ "x$PF_IGNOREDUPES" != "x" ]] && sed -i 's|\(^\s*IGNOREDUPES=\).*|\1ON|' /usr/share/planefence/planefence.conf || sed -i 's|\(^\s*IGNOREDUPES=\).*|\1OFF|' /usr/share/planefence/planefence.conf
# -----------------------------------------------------------------------------------
#
# same for planeheat.sh
#
sed -i 's/\(^\s*LAT=\).*/\1'"\"$FEEDER_LAT\""'/' /usr/share/planefence/planeheat.sh
sed -i 's/\(^\s*LON=\).*/\1'"\"$FEEDER_LONG\""'/' /usr/share/planefence/planeheat.sh
[[ "x$PF_MAXALT" != "x" ]] && sed -i 's/\(^\s*MAXALT=\).*/\1'"\"$PF_MAXALT\""'/' /usr/share/planefence/planeheat.sh
[[ "x$PF_MAXDIST" != "x" ]] && sed -i 's/\(^\s*DIST=\).*/\1'"\"$PF_MAXDIST\""'/' /usr/share/planefence/planeheat.sh
# -----------------------------------------------------------------------------------
#

# One-time action for builds after 20210218-094500EST: we moved the backup of .twurlrc from /run/planefence to /usr/share/planefence/persist
# so /run/* can be TMPFS. As a result, if .twurlrc is still there, move it to its new location.
# This one-time action can be obsoleted once all users have moved over.
[[ -f /run/planefence/.twurlrc ]] && mv -n /run/planefence/.twurlrc /usr/share/planefence/persist
# Now update the .twurlrc in /root if there is a newer version in the persist directory
[[ -f /usr/share/planefence/persist/.twurlrc ]] && cp -u /usr/share/planefence/persist/.twurlrc /root
# If there's still nothing in the persist directory or it appears out of date, back up the .twurlrc from /root to there
[[ -f /root/.twurlrc ]] && cp -n /root/.twurlrc /usr/share/planefence/persist
#
# -----------------------------------------------------------------------------------
#
# enable or disable tweeting:
#
[[ "x$PF_TWEET" == "xOFF" ]] && sed -i 's/\(^\s*PLANETWEET=\).*/\1/' /usr/share/planefence/planefence.conf
if [[ "x$PF_TWEET" == "xON" ]]
then
	if [[ ! -f ~/.twurlrc ]]
	then
			echo "[$APPNAME][$(date)] Warning: PF_TWEET is set to ON in .env file, but the Twitter account is not configured."
			echo "[$APPNAME][$(date)] Sign up for a developer account at Twitter, create an app, and get a Consumer Key / Secret."
			echo "[$APPNAME][$(date)] Then run this from the host machine: \"docker exec -it planefence /root/config_tweeting.sh\""
			echo "[$APPNAME][$(date)] For more information on how to sign up for a Twitter Developer Account, see this link:"
			echo "[$APPNAME][$(date)] https://elfsight.com/blog/2020/03/how-to-get-twitter-api-key/"
			echo "[$APPNAME][$(date)] PlaneFence will continue to start without Twitter functionality."
			sed -i 's/\(^\s*PLANETWEET=\).*/\1/' /usr/share/planefence/planefence.conf
	else
			sed -i 's|\(^\s*PLANETWEET=\).*|\1'"$(sed -n '/profiles:/{n;p;}' /root/.twurlrc | tr -d '[:blank:][=:=]')"'|' /usr/share/planefence/planefence.conf
            [[ "x$PF_TWATTRIB" != "x" ]] && sed -i 's|\(^\s*ATTRIB=\).*|\1'"\"$PF_TWATTRIB\""'|' /usr/share/planefence/planefence.conf
        fi
fi
# -----------------------------------------------------------------------------------
#
# Change the heatmap height and width if they are defined in the .env parameter file:
[[ "x$PF_MAPHEIGHT" != "x" ]] && sed -i 's|\(^\s*HEATMAPHEIGHT=\).*|\1'"\"$PF_MAPHEIGHT\""'|' /usr/share/planefence/planefence.conf
[[ "x$PF_MAPWIDTH" != "x" ]] && sed -i 's|\(^\s*HEATMAPWIDTH=\).*|\1'"\"$PF_MAPWIDTH\""'|' /usr/share/planefence/planefence.conf
[[ "x$PF_MAPZOOM" != "x" ]] && sed -i 's|\(^\s*HEATMAPZOOM=\).*|\1'"\"$PF_MAPZOOM\""'|' /usr/share/planefence/planefence.conf
#
# Also do this for files in the past -- /usr/share/planefence/html/planefence-??????.html
for i in /usr/share/planefence/html/planefence-??????.html
do
	[[ "x$PF_MAPWIDTH" != "x" ]] && sed  -i 's|\(^\s*<div id=\"map\" style=\"width:.*;\)|<div id=\"map\" style=\"width:'"$PF_MAPWIDTH"';|' $i
	[[ "x$PF_MAPHEIGHT" != "x" ]] && sed -i 's|\(; height:[^\"]*\)|; height: '"$PF_MAPHEIGHT"'\"|' $i
	[[ "x$PF_MAPZOOM" != "x" ]] && sed -i 's|\(^\s*var map =.*], \)\(.*\)|\1'"$PF_MAPZOOM"');|' $i
done




# if it still doesn't exist, something went drastically wrong and we need to set $PF_PLANEALERT to OFF!
if [[ ! -f /usr/share/planefence/persist/plane-alert-db.txt ]] && [[ "$PF_PLANEALERT" == "ON" ]]
then
		echo "Cannot find or create the plane-alert-db.txt file. Disabling Plane-Alert."
		echo "Do this on the host to get a base file:"
		echo "curl -s https://raw.githubusercontent.com/kx1t/docker-planefence/plane-alert/plane-alert-db.txt >~/.planefence/plane-alert-db.txt"
		echo "and then restart this docker container"
		PF_PLANEALERT="OFF"
fi

# make sure $PLANEALERT is set to ON in the planefence.conf file, so it will be invoked:
[[ "$PF_PLANEALERT" == "ON" ]] && sed -i 's|\(^\s*PLANEALERT=\).*|\1'"\"ON\""'|' /usr/share/planefence/planefence.conf || sed -i 's|\(^\s*PLANEALERT=\).*|\1'"\"OFF\""'|' /usr/share/planefence/planefence.conf

# Now make sure that the file containing the twitter IDs is rewritten with 1 ID per line
[[ "x$PF_PA_TWID" != "x" ]] && tr , "\n" <<< "$PF_PA_TWID" > /usr/share/plane-alert/plane-alert.twitterid || rm -f /usr/share/plane-alert/plane-alert.twitterid
# and write the rest of the parameters into their place
[[ "x$PF_PA_TWID" != "x" ]] && sed -i 's|\(^\s*TWITTER=\).*|\1'"\"true\""'|' /usr/share/plane-alert/plane-alert.conf || sed -i 's|\(^\s*TWITTER=\).*|\1'"\"false\""'|' /usr/share/plane-alert/plane-alert.conf
[[ "x$PF_NAME" != "x" ]] && sed -i 's|\(^\s*NAME=\).*|\1'"\"$PF_NAME\""'|' /usr/share/plane-alert/plane-alert.conf || sed -i 's|\(^\s*NAME=\).*|\1My|' /usr/share/plane-alert/plane-alert.conf
[[ "x$PF_MAPURL" != "x" ]] && sed -i 's|\(^\s*ADSBLINK=\).*|\1'"\"$PF_MAPURL\""'|' /usr/share/plane-alert/plane-alert.conf
[[ "x$PF_MAPZOOM" != "x" ]] && sed -i 's|\(^\s*MAPZOOM=\).*|\1'"\"$PF_MAPZOOM\""'|' /usr/share/plane-alert/plane-alert.conf

# Write the sort-table.js into the web directory as we cannot create it during build:
cp -f /usr/share/planefence/stage/sort-table.js /usr/share/planefence/html/plane-alert
#
#--------------------------------------------------------------------------------
# Since the persist directory is mounted on the host as 'root', we want
# to make sure that the user can write to files without using sudo:
# trying to do this carefully so it only applies to the files, incl '.xxx' in that
# directory - no recursion - just in case some idiot maps the persist directory to the host's "/"
chmod -f a+rw /usr/share/planefence/persist /usr/share/planefence/persist/{.[!.]*,*}
#
#--------------------------------------------------------------------------------
# Last thing - save the date we processed the config to disk. That way, if ~/.planefence/planefence.conf is changed,
# we know that we need to re-run this prep routine!
date +%s > /run/planefence/last-config-change
