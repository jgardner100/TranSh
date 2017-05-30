#!/bin/bash


#
# chk-procs.sh
#
# Author: John Gardner
# Date: 12 Oct 2016
#
# 	Compare the stored procs,views and permissions across two dataservers and report any
# differences.
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
TMPENV="$TMPDIR/chk-stats-file.$$"

. $HOME/refresh/bin/funcs.sh

list_stats_dates() {
	typeset P_DB="$1"


	do_isql "$P_DB" "SELECT MAX(moddate),s.id,convert(varchar(30),o.name)
				FROM sysstatistics s,sysobjects o
				WHERE s.id=o.id
				GROUP BY s.id,o.name
				ORDER BY o.name
	"
	checkret "$?" "Failed to select stored proc names in $P_DB" "nolog"

	display "$RES"
}

usage() {
	typeset ARGV="$1"


	typeset NAME


	NAME=$(basename "$ARGV")

	echo "usage: $NAME [-a][-t][-v][-d dbname] dataserver"
	echo ""
	echo " -a = all objects (procs, views) default is procs only"
	echo " -t = Testmode, no changes to be made"
	echo " -v = Verbose output"
	echo " -d = Database name"
	echo " -e = env to use (ie FSGDEV2-TST1)"
	echo " -u = database user to login as"

	exit 1
}

set -- `getopt atvd:u:e: $*`;
if [ "$?" != 0 ]
then
        echo $USAGE
        exit 2
fi
for i in $*
do
        case $i in
        -a)           DOALL=$i; shift;;
        -t)           TESTMODE=$i; shift;;
        -v)           VERBOSE=$i; shift;;
        -d)           DATABASE=$2; shift 2;;
        -u)           USE_USER=$2; shift 2;;
        -e)           USE_ENV=$2; shift 2;;
        --)           shift; break;;
        esac
done

if [ $# -ne 1 ]; then
	usage "$0"
fi

if [ -z "$DATABASE" ]; then
	echo ""
	echo "Must supply database name"
	echo ""
	usage "$0"
fi

TARGET="$1"

setdb "$TARGET" $USE_USER

list_stats_dates "$DATABASE"

rm -f $TMPENV

exit 0

exit 0
