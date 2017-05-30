#!/bin/bash

#
# chk-rtci.sh - CHeck where the RTCI interface is pointing to
#
# Author: John Gardner
# Date: 1 April 2010
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
TMPENV="$TMPDIR/chk-rpc-file.$$"

. $HOME/refresh/bin/funcs.sh

show_rpc() {
	typeset P_DBNAME="$1"
	typeset P_TABLE="$2"


	do_isql "$P_DBNAME" "sp_helpobjectdef $P_TABLE"
	checkret "$?" "sp_helpobjectdef $P_TABLE failed!" "nolog"
	display "$RES"
}

doall() {
	typeset P_TABLE="$1"


	typeset L_DB


	for L_DB in $DB_LIST
	do
		echo $L_DB

		show_rpc "$L_DB" "$P_TABLE"

	done
}

usage() {
	typeset ARGV="$1"


	typeset NAME


	NAME=$(basename "$ARGV")

	echo "$NAME: [-a][-v][-e env][-u user] dataserver"
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
        -a)           DOALL=$i; shift;;
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

setdb "$DATASERVER" $USE_USER

get_envfile "$TMPENV"

if [ ! -z "$DOALL" ]; then

	for RPC_TARGET in $RPC_LIST
	do
		DBNAME=$(echo $RPC_TARGET|cut -d: -f1)
		TARGET=$(echo $RPC_TARGET|cut -d: -f2)

		doall "$TARGET"
	done

elif [ ! -z "$RPC_LIST" ]; then
	echo "rpc_list = $RPC_LIST"

	for RPC_TARGET in $RPC_LIST
	do
		DBNAME=$(echo $RPC_TARGET|cut -d: -f1)
		TARGET=$(echo $RPC_TARGET|cut -d: -f2)

		show_rpc "$DBNAME" "$TARGET"
	done
else
	echo "\$RPC_LIST not set"

	doall 
fi

rm -f $TMPENV

exit 0
