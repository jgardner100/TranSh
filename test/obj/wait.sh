#!/bin/bash
#
# wait.sh - Waits until all the loaddb commands have completed, then runs the 
#              refresh script in parallel for each dataserver.
#
# Author: John Gardner
# Date: 31 August 2010
#

NUM_PARALLEL=0
T_LIMIT=48

function cleanup {
	echo Stopping
	rm -f $TMPENV
	echo Done
	exit 0
}
trap cleanup SIGTERM SIGINT
trap "" SIGHUP
TMPDIR="$HOME/refresh/tmp"
TMPENV="$TMPDIR/wait-file.$$"

. $HOME/refresh/bin/funcs.sh

MAILTO="john.gardner@macquarie.com"
HOST="www-sybase.macbank:21234"

BASE_URL="http://$HOST/showlogfile?file=/dba/sybase/logs/loaddb"
TAIL_URL="loaddb_www.sh.log.current"
TAILNG_URL="loaddb_www.NGB.sh.log.current"
WGET_OPT="--no-check-certificate"
LOCKFILE="/tmp/wait.lock"

# Must have wget in our path
#
export PATH
PATH="$PATH:/usr/sfw/bin"

#
# After the refresh, run update stats for each dataserver in parallel (called from run_loop function)
#
run_update_stats() {
	typeset P_SERVER="$1"


	typeset MDATE


	MDATE=$(date +%T)
	echo "in update_stats run loop $P_SERVER ($MDATE)"
	do_verbose "in update_stats run loop $P_SERVER ($MDATE)"

	if [ -z "$TESTMODE" ]; then
		do_verbose "update_stats.sh $P_SERVER"
		update_stats.sh "$P_SERVER"
	else
		echo "Testmode - update_stats $P_SERVER"
		sleep 30
	fi

	MDATE=$(date +%T)
	echo "update_stats $P_SERVER complete ($MDATE)"
	do_verbose "update_stats $P_SERVER complete ($MDATE)"
}

#
# Run the actual refresh command (called from run_loop function)
#
run_refresh() {
	typeset P_SERVER="$1"


	typeset MDATE


	MDATE=$(date +%T)
	echo "in refresh run loop $P_SERVER ($MDATE)"
	do_verbose "in run loop refresh $P_SERVER ($MDATE)"

	if [ -z "$TESTMODE" ]; then
		if [ -z "$USE_ENV" ]; then
			do_verbose "refresh.sh -m $MAILTO $P_SERVER"
			refresh.sh -m "$MAILTO" "$P_SERVER"
		else
			do_verbose "refresh.sh -e $USE_ENV -m $MAILTO $P_SERVER"
			refresh.sh -e $USE_ENV -m "$MAILTO" "$P_SERVER"
		fi
	else
		if [ -z "$USE_ENV" ]; then
			echo "Testmode - refresh.sh -m $MAILTO $P_SERVER"
			sleep 30
		else
			echo "Testmode - refresh.sh -e $USE_ENV -m $MAILTO $P_SERVER"
			sleep 30
		fi
	fi

	MDATE=$(date +%T)
	echo "refresh run loop $P_SERVER complete ($MDATE)"
	do_verbose "run loop refresh $P_SERVER complete ($MDATE)"
}

#
# Subtract two datetime values to find the interval in hours
#
interval() {
	typeset P_TIME="$1"


	typeset DAY

	typeset TIME

	typeset P_TIME


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

	for DB in $DB_LIST
	do
		L_START=$(grep "Starting.*with" $TMPDIR/stat-$DB.txt|head -1|cut -d' ' -f1-6)
		L_START=$(echo $L_START)
		L_END=$(grep "Finished" $TMPDIR/stat-$DB.txt| grep "load_db_www.sh" |
			head -1|cut -d' ' -f1-6)

		DBMSG=$(grep "is restored successfully" $TMPDIR/stat-$DB.txt|
			head -1|cut -d: -f4)
		do_verbose "$DB: $L_START"
		if [ -z "$DBMSG" ]; then
			do_verbose "Database loading or failed"
			MSTATUS=0
		else
			do_verbose "Status: $DBMSG"
		fi

		HOURS=$(interval "$L_START")
		do_verbose "interval start=$L_START hours=$HOURS"

		if [ "$HOURS" -ge "$T_LIMIT" ]; then
			do_verbose "Refresh too old - $HOURS hours old"
			MSTATUS=0
		else
			do_verbose "Refresh is recent"
		fi

		do_verbose ""

		rm -f $TMPDIR/stat-$DB.txt
	done

	return $MSTATUS
}

#
# Checks the load time for each dataserver and returns true if all are
# ready.
#
wait_for_loads() {
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

#
# Check a lockfile to see if wait.sh is already running.
#
check_running() {


	typeset NAME

	typeset -i PID


	if [ -f "$LOCKFILE" ]; then
		echo "$LOCKFILE exists"
		PID=$(cat $LOCKFILE)
		NAME=$(ps -fp $PID|grep wait.sh)
		echo "NAME=$NAME"
		echo "PID=$PID"
		if [ -z "$NAME" ]; then
			echo "Process $PID dead - removing lock"
			rm -f $LOCKFILE
		else
			echo "$NAME still running."
			exit 1
		fi
	else
		echo "No lockfile."
	fi

	echo $$ >$LOCKFILE
}

#
# Run update_stats.sh for each dataserver listed
#
update_stats() {
	typeset P_SERVERS="$*"


	for DS in $P_SERVERS
	do
		echo "Update stats for $DS"
	done

}

usage() {
	typeset ARGV="$1"


	typeset NAME


	NAME=$(basename $ARGV)

	echo "usage: $NAME [-e env][-u user][-v][-t][-z][-g][-n count][-l filename][-m mailaddr] dataserver*"
	echo ""
	echo " -v = verbose output"
	echo " -t = test mode, don't actually run anything"
	echo " -z = don't wait for loads (used mainly for testing)"
	echo " -g = Handle as Nextgen loaddb"
	echo " -n = number of parallel refreshes to run (default=3)"
	echo " -l = logfile name to send some output to"
	echo " -m = Mail address to send results to"
	echo " -e = env to use (ie TST1)"
	echo " -u = database user to login as"
	echo ""

	exit 1
}

set -- `getopt ztvl:m:n:e:u:g $*`;
if [ "$?" != 0 ]
then
        echo $USAGE
        exit 2
fi
for i in $*
do
        case $i in
        -z)           NOWAIT=$i; shift;;
        -t)           TESTMODE=$i; shift;;
        -v)           VERBOSE=$i; shift;;
        -l)           DOLOG=$2; shift 2;;
        -m)           MAILTO=$2; shift 2;;
        -n)           NCPU=$2; shift 2;;
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

if [ -z "$NCPU" ]; then
	NUM_PARALLEL=3
else
	NUM_PARALLEL=$NCPU
fi

WGET_VERSION=$(wget --version|grep "GNU Wget")
if [ -z "$WGET_VERSION" ]; then
	echo "Must install /usr/sfw/bin/wget"
	exit 1
fi

check_running 

COUNT=0

while [ 1 ]
do

	if [ "$COUNT" -gt 144 ]; then
		echo "Timeout, COUNT=$COUNT"
		send_email "$MAILTO" "Refresh timed out" "wait.sh timed out for env $USE_ENV."
		exit 1
	fi

	do_verbose ""
	do_verbose ""

	COUNT=$(expr "$COUNT" + 1)
	echo "Cycle $COUNT"

	wait_for_loads "$SERVERS"
	if [ "$?" -ne 0 ]; then
		echo "Ready for refresh"

		#
		# Create the tables to hold the refresh results and status
		#
		if [ -z "$TESTMODE" ]; then
			do_verbose "Run create table script"
			$HOME/bin/create.sh
		else
			echo "Testmode - create table script"
		fi

		#
		# Run the actual refresh script in parallel
		#
		echo do_verbose "run_loop $NUM_PARALLEL run_refresh $SERVERS"
		run_loop "$NUM_PARALLEL" "run_refresh" "$SERVERS"

		#
		# Notify everyone with the refresh results
		#
		if [ -z "$TESTMODE" ]; then
			do_verbose "Send emails"
			if [ ! -z "$USE_ENV" ]; then
				#$HOME/bin/reportmail.sh -p -e $USE_ENV;
				send_email "$MAILTO" "Refresh Complete" "wait.sh complete for env $USE_ENV."
			else
				#$HOME/bin/reportmail.sh -p;
				send_email "$MAILTO" "Refresh Complete" "wait.sh complete."
			fi
		else
			#$HOME/bin/reportmail.sh;
			echo "Testmode - reportmail"
			do_verbose "reportmail.sh in test mode"
		fi

		#
		# Run update_stats.sh script in parallel for each dataserver
		#
		#		do_verbose("run_loop $NUM_PARALLEL run_update_stats $SERVERS");
		#		run_loop("$NUM_PARALLEL","run_update_stats","$SERVERS");

		rm -f $LOCKFILE
		exit 0
	else
		sleep 600
	fi

	do_verbose "All finished"
done

rm -f $TMPENV

exit 0
