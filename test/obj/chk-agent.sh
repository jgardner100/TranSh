#!/bin/bash

#
# chk-agent.my - Check that a rep agent is running
#
# Author: John Gardner
# Date:
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
TMPENV="$TMPDIR/chk-agent-file.$$"

. $HOME/refresh/bin/funcs.sh

check_agent() {
	typeset P_DBNAME="$1"


	echo "Checking rep agent for $P_DBNAME"

	do_isql "$P_DBNAME" "$P_DBNAME..sp_help_rep_agent $P_DBNAME,'process'"
	if [ "$?" -ne 0 ]; then
		echo "No replication agent"
	else
		display "$RES"
	fi
}

check_alldb() {


	get_envfile "$TMPENV"
	get_param "$TMPENV" "DB_LIST"

	for NAME in $PVAL
	do
		echo $NAME
		check_agent "$NAME"
	done

	rm -f "$TMPENV"
}

usage() {

	typeset NAME


	NAME=$(basename $1)
	echo "usage: $NAME [-e env][-u user] dataserver"
	echo "-e = env to use (ie FSGDEV2-TST1)"
	echo "-u = database user to login as"
	exit 1
}

set -- `getopt u:e:v $*`;
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
        -v)           VERBOSE=$i; shift;;
        --)           shift; break;;
        esac
done

if [ $# -lt 1 ]; then
	usage $0
fi

for DS in $*
do

	setdb $DS $USE_USER
	check_alldb 

done

rm -f $TMPENV

exit 0
