#!/bin/bash
#
# listuser.sh
#
# 	List users and hostnames of current connections to a database
#
# Author: John Gardner
# Date: 8 June 2010
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
TMPENV="$TMPDIR/listuser-file.$$"

. $HOME/refresh/bin/funcs.sh

get_users_tstamp() {


	do_isql "master" "
			select
				distinct 
					suser_name( suid)+','+
					convert(varchar(10),hostname)+','+
					convert(varchar(10),@@servername)+','+
					convert(varchar(18),getdate())
			from
				sysprocesses
			where
				suid != suser_id( 'perfmon_dba')
				and suid != suser_id( 'perfmon_dba')
				and suid != 0
				and hostname like 'AA%'
			order by
				hostname
	"
	checkret "$?" "Can't select hostnames from sysprocesses"

	display "$RES"
}

get_users() {


	#,convert(varchar(18),db_name(dbid))
	do_isql "master" "
			select
				distinct 
					suser_name( suid)
					,convert(varchar(18),hostname)
					,convert(varchar(18),@@servername)
			from
				sysprocesses
			where
				suid != suser_id( 'perfmon_dba')
				and suid != suser_id( 'perfmon_dba')
				and suid != 0
				and hostname like 'AA%'
			order by
				hostname
	"
	checkret "$?" "Can't select hostnames from sysprocesses"

	if [ -z "$NOHDR" ]; then
		echo
		echo "${DSQUERY}:"
		echo "==========="
		echo
		echo " User                           Hostname           Database "
		echo " -----------                    ---------          ---------"
	fi

	display "$RES"
}

usage() {

	typeset NAME


	NAME=$(basename $1)

	echo "usage: $NAME [-v][-n][-m] dataserver"
	echo ""
	echo " -v = Verbose output"
	echo " -n = No headers"
	echo " -m = Show timestamp"

	exit 1
}

set -- `getopt tvnmu:e: $*`;
if [ "$?" != 0 ]
then
        echo $USAGE
        exit 2
fi
for i in $*
do
        case $i in
        -t)           TESTMODE=$i; shift;;
        -v)           VERBOSE=$i; shift;;
        -n)           NOHDR=$i; shift;;
        -m)           SHOWTIME=$i; shift;;
        -u)           USE_USER=$2; shift 2;;
        -e)           USE_ENV=$2; shift 2;;
        --)           shift; break;;
        esac
done

if [ $# -eq 0 ]; then
	usage $0
fi

for DS in $*
do
	DATASERVER=$DS
	shift

	setdb "$DATASERVER" $USE_USER

	if [ -z "$SHOWTIME" ]; then
		get_users 
	else
		get_users_tstamp 
	fi
done

#HOST=`ping -s 10.138.2.63 128 1|grep from|cut -f4 -d' '`
