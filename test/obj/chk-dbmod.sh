#!/bin/bash

#
# chk-dbmod.my
#
# Check all procs and views for prod references
#
# Author: John Gardner
# Date: 1 Feb 2017
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
TMPENV="$TMPDIR/chk-dbmod-file.$$"

. $HOME/refresh/bin/funcs.sh

ISQL_EXTRA=" -b"

show_dbmod() {
	typeset P_DBNAME="$1"


	typeset RES


	do_isql "$P_DBNAME" "select distinct object_name(id) from syscomments where text like '%wrap_prd%' or text like '%amd_prd%' or text like '%WRPPROD%' or text like 'FSGPROD%'"
	checkret "$?" " SQL failed!" "nolog"

	RES=$(echo $RES | cut -d":" -f2-)
	echo "The procs/views below in $P_DBNAME still contain references to PROD dbs"
	echo "************************************************"
	echo $RES
}

usage() {
	typeset FULLNAME="$1"


	typeset NAME


	NAME=$(basename $FULLNAME)

	echo "$NAME : [-a][-v][-e env][-u user] dataserver"
	echo ""
	echo "-v = verbose output"
	echo "-e = env to use (ie FSGDEV2-TST1)"
	echo "-u = database user to login as"
	echo "-a = check all databases"
	echo ""

	exit 1
}

set -- `getopt au:e:v $*`;
if [ "$?" != 0 ]
then
        echo $USAGE
        exit 2
fi
for i in $*
do
        case $i in
        -a)           ALL_DB=$i; shift;;
        -u)           USE_USER=$2; shift 2;;
        -e)           USE_ENV=$2; shift 2;;
        -v)           VERBOSE=$i; shift;;
        --)           shift; break;;
        esac
done

if [ $# -ne 1 ]; then
	usage $0
fi

DATASERVER="$1"

setdb "$DATASERVER" "$USE_USER"

get_envfile "$TMPENV"
get_param "$TMPENV" "DB_LIST"
for DATABASE in $DB_LIST
do
	show_dbmod $DATABASE
done

rm -f $TMPENV

exit 0
