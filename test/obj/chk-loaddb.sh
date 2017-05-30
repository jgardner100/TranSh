#!/bin/bash
#
# chk-loaddb.sh - Check whether loaddb is working or not.
#
# Author: John Gardner
# Date: 24 Feb 2017
#

function cleanup {
	echo Stopping
	rm -f $TMPENV
	echo Done
	exit 0
}
trap cleanup SIGTERM SIGINT
trap "" SIGHUP
TMPDIR="$HOME/refresh/tmp"
TMPENV="$TMPDIR/chk-loaddb-file.$$"

. $HOME/refresh/bin/funcs.sh

T_LIMIT=48
MAILTO="john.gardner@macquarie.com"
HOST="www-sybase.macbank:21234"

BASE_URL="http://$HOST/showlogfile?file=/dba/sybase/logs/loaddb"
TAIL_URL="loaddb_www.sh.log.current"
TAILNG_URL="loaddb_www.NGB.sh.log.current"
WGET_OPT="--no-check-certificate"
FAIL_LIST=""

# Must have wget in our path
#
export PATH
PATH="$PATH:/usr/sfw/bin"

#
# Subtract two datetime values to find the interval in hours
#
interval() {
	typeset P_TIME="$1"


	typeset DAY
	typeset TIME


	DAY=$(echo $P_TIME|cut -d" " -f2-3)
	TIME=$(echo $P_TIME|cut -d" " -f4)

	P_TIME="$DAY `date +%Y` $TIME"

	do_isql "master" "select datediff( hh,
					convert( datetime, '$P_TIME'),
					getdate()
			)"
	checkret "$?" "Can't check time difference with $P_TIME" "stderr"

	echo $RES
}

#
# Uses wget to fetch the logfile from loaddb for each database
# and work out how long ago each database was loaded and return true if
# all were loaded in the last 48 hours.
#
check_loadtime() {


	typeset -i MSTATUS=1 
	typeset -i HOURS

	typeset URL
	typeset DBMSG
	typeset L_START
	typeset L_END


	#
	# Grab all the web pages
	#
	for DB in $DB_LIST
	do
		if [ -z "$NEXTGEN" ]; then
			URL="${BASE_URL}/${DSQUERY}/${DB}.${TAIL_URL}"
		else
			URL="${BASE_URL}/${DSQUERY}/${DB}.${TAILNG_URL}"
		fi
		do_verbose "wget $WGET_OPT -o /tmp/out -v $URL -O $TMPDIR/stat-$DB.txt"
		wget $WGET_OPT -o /tmp/out -v $URL -O $TMPDIR/stat-$DB.txt
	done

	#
	# Proces each page for the status
	#
	for DB in $DB_LIST
	do
		L_START=$(grep "Starting.*with" $TMPDIR/stat-$DB.txt|head -1|cut -d' ' -f1-6)
		L_START=$(echo $L_START)
		L_END=$(grep "Finished" $TMPDIR/stat-$DB.txt| grep "load_db_www.sh" |
			head -1|cut -d' ' -f1-6)

		FILETHERE=$(grep "FILE DOES NOT EXIST OR PERMISSION DENIED" $TMPDIR/stat-$DB.txt|head -1)
		if [ ! -z "$FILETHERE" ]; then
			echo "No logfile for $DB"
			FAIL_LIST=$(echo "$FAIL_LIST ${DSQUERY}.${DB}")
			MSTATUS=0
		else

			if [ -z "$NEXTGEN" ]; then
				DBMSG=$(grep "Successfully loaded database" $TMPDIR/stat-$DB.txt|
					head -1|cut -d: -f4)
			else
				DBMSG=$(grep "is restored successfully" $TMPDIR/stat-$DB.txt|
					head -1|cut -d: -f4)
			fi

			do_verbose "$DB: $L_START"
			if [ -z "$DBMSG" ]; then
				do_verbose "Database loading or failed"
				FAIL_LIST=$(echo "$FAIL_LIST ${DSQUERY}.${DB}")
				MSTATUS=0
			else
				do_verbose "Status: $DBMSG"
			fi

			HOURS=$(interval "$L_START")
			do_verbose "interval start=$L_START hours=$HOURS"

			if [ "$HOURS" -ge "$T_LIMIT" -o "$HOURS" -lt 0 ]; then
				do_verbose "Refresh too old - $HOURS hours old"
				FAIL_LIST=$(echo "$FAIL_LIST ${DSQUERY}.${DB}")
				MSTATUS=0
			else
				do_verbose "Refresh is recent"
			fi

			do_verbose ""

			rm -f $TMPDIR/stat-$DB.txt
		fi
	done

	return $MSTATUS
}

#
# Checks the load time for each dataserver and returns true if all are
# ready.
#
check_loads() {
	typeset P_SERVERS="$1"


	echo "Waiting for loads - $P_SERVERS `date +%T`"

	typeset -i STATUS=1 

	for DS in $P_SERVERS
	do
		do_verbose "Checking for $DS"

		setdb $DS $USE_USER

		get_envfile $TMPENV

		check_loadtime 
		RET="$?"

		if [ "$RET" -ne 0 ]; then
			do_verbose "`date`: $DS ready"
		else
			do_verbose "`date`: $DS not ready"
			STATUS=0
		fi

		rm -f $TMPENV
	done

	if [ \( "$STATUS" -ne 0 \) -o \( ! -z "$NOWAIT" \) ]; then
		echo "All dataservers ready"
		RET=1
	else
		RET=0
	fi

	return $RET
}

usage() {
	typeset ARGV="$1"


	typeset NAME


	NAME=$(basename $ARGV)

	echo "usage: $NAME [-e env][-u user][-v][-t][-z][-g][-n count][-l filename][-m mailaddr] dataserver*"
	echo ""
	echo " -v = verbose output"
	echo " -g = Handle as Nextgen loaddb"
	echo " -l = logfile name to send some output to"
	echo " -m = Mail address to send results to"
	echo " -e = env to use (ie TST1)"
	echo " -u = database user to login as"
	echo ""

	exit 1
}

set -- `getopt vl:m:e:u:g $*`;
if [ "$?" != 0 ]
then
        echo $USAGE
        exit 2
fi
for i in $*
do
        case $i in
        -v)           VERBOSE=$i; shift;;
        -l)           DOLOG=$2; shift 2;;
        -m)           MAILTO=$2; shift 2;;
        -e)           USE_ENV=$2; shift 2;;
        -u)           USE_USER=$2; shift 2;;
        -g)           NEXTGEN=$i; shift;;
        --)           shift; break;;
        esac
done

if [ $# -lt 1 ]; then
	usage $0
fi

SERVERS="$*"

WGET_VERSION=$(wget --version|grep "GNU Wget")
if [ -z "$WGET_VERSION" ]; then
	echo "Must install /usr/sfw/bin/wget"
	exit 1
fi

check_loads "$SERVERS"
if [ "$?" -ne 0 ]; then
	echo "Refresh is current"

	if [ -z "$TESTMODE" ]; then
		do_verbose "Send emails"
		send_email "$MAILTO" "$SERVERS Refresh Complete" "Refresh of $SERVERS completed successfully."
	else
		echo "Testmode - reportmail"
		do_verbose "reportmail.sh in test mode"
	fi
else
	echo "Refresh has problems"
	if [ -z "$TESTMODE" ]; then
		do_verbose "Send emails"
		send_email "$MAILTO" "$SERVERS Refresh Failed" "Refresh of $SERVERS failed. $FAIL_LIST"
	else
		echo "Testmode - reportmail"
		do_verbose "reportmail.sh in test mode"
	fi
fi

rm -f $TMPENV

exit 0
