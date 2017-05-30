#!/bin/bash
#
# create.sh - create the tables used to record all database refresh details
#
# Author: John Gardner
# Date: 10 Dec 2010
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
TMPENV="$TMPDIR/create-file.$$"

. $HOME/refresh/bin/funcs.sh

check_exists() {
	typeset P_TABLE="$1"


	typeset NAME


	do_isql "wrapetc_prd" "
			select name from sysobjects where name='$P_TABLE'
	"
	checkret "$?" "Can't check status of $P_TABLE"
	NAME=$(echo $RES|tr -d [:space:])
	if [ ! -z "$NAME" ]; then
		echo "table $NAME exists"
		exit 1
	else
		echo "no such table"
	fi
}

do_drop() {
	typeset P_TABLE="$1"


	do_isql "wrapetc_prd" "drop table $P_TABLE"
	checkret "$?" "Failed to drop table $P_TABLE"
	display "$RES"
}

do_create() {
	typeset P_TABLE="$1"
	typeset P_CREATE="$2"


	do_isql "wrapetc_prd" "$P_CREATE"
	checkret "$?" "Can't create table $P_TABLE"
	display "$RES"
}

create_table() {
	typeset P_TABLE="$1"
	typeset P_CREATE="$2"


	check_exists "$P_TABLE"
	do_create "$P_TABLE" "$P_CREATE"
}

usage() {
	typeset ARGV="$1"


	typeset NAME


	NAME=$(basename $1)

	echo "usage: $NAME [-d]"
	echo ""
	echo " -d = drop tables"

	exit 1
}

set -- `getopt cdv $*`;
if [ "$?" != 0 ]
then
        echo $USAGE
        exit 2
fi
for i in $*
do
        case $i in
        -c)           CHECK=$i; shift;;
        -d)           DROP=$i; shift;;
        -v)           VERBOSE=$i; shift;;
        --)           shift; break;;
        esac
done

if [ $# -ne 0 ]; then
	usage $0
fi

setdb FSGDEV11

if [ ! -z "$DROP" ]; then
	do_drop "refresh_status"
	do_drop "refresh_log"
	do_drop "refresh_error"

	exit 0
elif [ ! -z "$CHECK" ]; then

	check_exists "refresh_status"
	check_exists "refresh_log"
	check_exists "refresh_error"

	exit 0
fi

create_table "refresh_status" "

	create table refresh_status (
		dsquery varchar(30)
	        ,status varchar(30)
	        ,start datetime
	        ,stop datetime null
	)

"

create_table "refresh_log" "

	create table refresh_log (
		dsquery varchar(30)
		,process varchar(30)
		,status varchar(30)
		,start datetime
		,stop datetime null
	)
"

create_table "refresh_error" "

	create table refresh_error (
		dsquery varchar(30)
		,process varchar(30)
		,ts_stamp datetime
		,message varchar(255) null
	)
"

rm -f $TMPENV

exit 0
