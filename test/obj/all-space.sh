#!/bin/bash

#
# all-space.sh - Check the space used by each table in a database
#
# Author: John Gardner
# Date: 1 June 2010
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
TMPENV="$TMPDIR/all-space-file.$$"

. $HOME/refresh/bin/funcs.sh

all_tables() {
	typeset P_DB="$1"


	typeset TABLES


	do_isql "$P_DB" "select name from sysobjects where type = 'U'"
	TABLES="$RES"

	for TABLE in $TABLES
	do
		echo "$TABLE"
		do_isql "$P_DB" "sp_spaceused $TABLE"
		display "$RES"
	done
}

usage() {


	typeset NAME


	NAME=$(basename $1)
	echo "usage: $NAME [-e env][-u user][-v][-d db] dataserver"
	echo ""
	echo " -v = verbose output"
	echo " -e = env to use (ie FSGDEV2-TST1)"
	echo " -u = database user to login as"
	echo " -d = database to do this for"
	echo ""

	exit 1
}

set -- `getopt u:e:d:v $*`;
if [ "$?" != 0 ]
then
        echo $USAGE
        exit 2
fi
for i in $*
do
        case $i in
        -u)           USE_USER=$2; shift 2;;
        -e)           USE_ENV=$2; shift 2;;
        -d)           DBARG=$2; shift 2;;
        -v)           VERSION=$i; shift;;
        --)           shift; break;;
        esac
done

if [ $# -ne 1 ]; then
	usage $0
fi

setdb "$1" $USE_USER

get_envfile "$TMPENV"

if [ ! -z "$DBARG" ]; then
	all_tables "$DBARG"
else
	for DB in $DB_LIST
	do
		all_tables "$DB"
	done
fi

rm -f $TMPENV

exit 0
