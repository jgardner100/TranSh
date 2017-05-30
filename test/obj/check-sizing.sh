#!/bin/bash
#
# check-sizing
#
# Check database sizes prior to refresh
#
# Author: John Gardner
# Date: who knows?
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
TMPENV="$TMPDIR/check-sizing-file.$$"

. $HOME/refresh/bin/funcs.sh

check_size() {
	typeset P_DATABASE="$1"


	do_verbose "Doing $P_DATABASE"

	do_verbose "do_isql master sp_helpdb $P_DATABASE"
	do_isql "master" "sp_helpdb $P_DATABASE"
	checkret "$?" "failed to get database size for $P_DATABASE" "nolog"

	display "$RES"
}

usage() {


	typeset NAME


	NAME=$(basename $1)

	echo "usage: $NAME [-v] dataserver"
	echo ""
	echo "-v = verbose output"

	exit 1
}

set -- `getopt e:u:v $*`;
if [ "$?" != 0 ]
then
        echo $USAGE
        exit 2
fi
for i in $*
do
        case $i in
        -e)           USE_ENV=$2; shift 2;;
        -u)           USE_USER=$2; shift 2;;
        -v)           VERBOSE=$i; shift;;
        --)           shift; break;;
        esac
done

if [ $# -lt 1 ]; then
	usage $0
fi

DBLIST="$*"
for DS in $DBLIST
do

	setdb "$DS" "$USE_USER"

	echo "${DSQUERY}:"

	get_envfile "$TMPENV"

	LIST=$(echo "$DB_LIST"| tr -s "[:space:]" "[\n*]"|sort)

	for DB in $LIST
	do
		check_size "$DB"
	done

	rm -f "$TMPFILE" "$TMPENV"

	echo ""
done

rm -f $TMPENV

exit 0
