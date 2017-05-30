#!/bin/bash

#
# chk-procs.sh
#
# Author: John Gardner
# Date: 5 Jan 2011
#
# 	Compare the stored procs across two dataservers and report any
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
TMPENV="$TMPDIR/chk-procsrc-file.$$"

. $HOME/refresh/bin/funcs.sh


TMPFILE1="$TMPDIR/proc1.$$"
TMPFILE2="$TMPDIR/proc2.$$"

get_ddl() {
	typeset P_DB="$1"
	typeset P_PROCS="$2"


	for PROCN in $P_PROCS
	do
		echo $PROCN
		setdb "$SOURCE" $USE_USER
		do_ddl "$P_DB" "P" "$PROCN" "$TMPFILE1"
		do_filter "$TMPFILE1" "create proc"

		setdb "$TARGET" $USE_USER
		do_ddl "$P_DB" "P" "$PROCN" "$TMPFILE2"
		do_filter "$TMPFILE2" "create proc"

		diff "$TMPFILE1" "$TMPFILE2"
	done
}

get_proclist() {
	typeset P_DB="$1"


	do_isql "$P_DB" "select name from sysobjects where type = 'P'"
	checkret "$?" "Failed to select stored proc names in $P_DB" "nolog"

	PROCLIST="$RES"
}

usage() {
	typeset ARGV="$1"


	typeset NAME


	NAME=$(basename "$ARGV")

	echo "usage: $NAME [-t][-v][-d dbname] source-ds target-ds"
	echo ""
	echo " -t = Testmode, no changes to be made"
	echo " -v = Verbose output"
	echo " -d = Database name"

	exit 1
}

set -- `getopt tvd:e:u: $*`;
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
        -d)           DATABASE=$2; shift 2;;
        -e)           USE_ENV=$2; shift 2;;
        -u)           USE_USER=$2; shift 2;;
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

SOURCE="$1"
TARGET="$2"

setdb "$SOURCE" $USE_USER
get_proclist "$DATABASE"

setdb "$TARGET" $USE_USER
get_ddl "$DATABASE" "$PROCLIST"

rm -f "$TMPFILE1" "$TMPFILE2"

rm -f $TMPENV

exit 0
