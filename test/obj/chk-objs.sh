#!/bin/bash

#
# chk-procs.sh
#
# Author: John Gardner
# Date: 12 Oct 2016
#
# 	Compare the stored procs,views and permissions across two dataservers
# and report any differences.
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
TMPENV="$TMPDIR/chk-objs-file.$$"

. $HOME/refresh/bin/funcs.sh

check_proclist() {
	typeset P_DB="$1"
	typeset P_PROCS="$2"
	typeset P_TYPE="$3"


	setdb "$TARGET" "$USE_USER"

	do_isql "$P_DB" "select convert(varchar(40),name),type name 
				from sysobjects where type in ($P_TYPE) and name not in ($P_PROCS) order by name"
	checkret "$?" "Failed to select stored proc names in $P_DB" "nolog"

	display "$RES"
}

get_proclist() {
	typeset P_DB="$1"
	typeset P_TYPE="$2"


	do_isql "$P_DB" "select '\"'+name+'\",' from sysobjects where type in ($P_TYPE) order by name"
	checkret "$?" "Failed to select stored proc names in $P_DB with type $P_TYPE" "nolog"

	PROCLIST=$(echo $RES|sed 's/,$//')
}

usage() {
	typeset FULLNAME="$1"


	typeset NAME


	NAME=$(basename "$FULLNAME")

	echo "usage: $NAME [-a][-t][-v][-d] source-ds target-ds"
	echo ""
	echo " -a = all objects (procs, views) default is procs only"
	echo " -t = Testmode, no changes to be made"
	echo " -v = Verbose output"
	echo " -d = Database name"
	echo ""

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
SOURCE="$2"

FIND_COL=$(echo "$DATABASE"|grep ":"|wc -l)
if [ "$FIND_COL" -eq 0 ]; then
	SOURCE_DB=$DATABASE
	DEST_DB=$DATABASE
else
	DEST_DB=$(echo $DATABASE|cut -d":" -f1)
	SOURCE_DB=$(echo $DATABASE|cut -d":" -f2)
fi

if [ ! -z "$DOALL" ]; then
	TYPESTR="'P','V'"
else
	TYPESTR="'P'"
fi

setdb "$SOURCE" "$USE_USER"
echo get_proclist "$SOURCE $SOURCE_DB $TYPESTR"
get_proclist "$SOURCE_DB" "$TYPESTR"

setdb "$TARGET" "$USE_USER"
echo "check_proclist $TARGET $DEST_DB $TYPESTR"
check_proclist "$DEST_DB" "$PROCLIST" "$TYPESTR"

rm -f $TMPENV

exit 0
