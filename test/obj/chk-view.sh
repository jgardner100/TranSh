#!/bin/bash

#
# chk-procs.sh
#
# Author: John Gardner
# Date: 30 Jan 2017
#
# 	Check an object exists.
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
TMPENV="$TMPDIR/chk-view-file.$$"

. $HOME/refresh/bin/funcs.sh

check_obj() {
	typeset P_DB="$1"
	typeset P_NAME="$2"


	typeset NOW


	do_isql "$P_DB" "select convert(varchar(40),name),type,crdate,getdate() name 
				from sysobjects where name like '$P_NAME'"
	checkret "$?" "Failed to select stored proc names in $P_DB" "nolog"

	RETVAL=$(echo $RES)

	if [ ! -z "$RETVAL" ]; then
		display "$RES"
	else
		NOW=$(date)
		echo "$P_NAME is missing at $NOW"
	fi
}

usage() {
	typeset FULLNAME="$1"


	typeset NAME


	NAME=$(basename "$FULLNAME")

	echo "usage: $NAME [-a][-t][-v][-d] target object_name" echo ""
	echo " -a = all objects (procs, views) default is procs only"
	echo " -t = Testmode, no changes to be made"
	echo " -v = Verbose output"
	echo " -d = Database name"

	exit 1
}

set -- `getopt ave:u:d:t $*`;
if [ "$?" != 0 ]
then
        echo $USAGE
        exit 2
fi
for i in $*
do
        case $i in
        -a)           DOALL=$i; shift;;
        -v)           VERBOSE=$i; shift;;
        -e)           USE_ENV=$2; shift 2;;
        -u)           USE_USER=$2; shift 2;;
        -d)           DATABASE=$2; shift 2;;
        -t)           TESTMODE=$i; shift;;
        --)           shift; break;;
        esac
done

if [ $# -ne 2 ]; then
	usage $0
fi

if [ -z "$DATABASE" ]; then
	echo ""
	echo "Must supply database name"
	echo ""
	usage $0
fi

TARGET="$1"
OBJ_NAME="$2"
setdb "$TARGET" "$USE_USER"

check_obj "$DATABASE" "$OBJ_NAME"

rm -f $TMPENV

exit 0

exit 0
