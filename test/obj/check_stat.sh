#!/bin/bash

#
# chk-stat.sh - Display the status of the replication agents in each database
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
TMPENV="$TMPDIR/check_stat-file.$$"

. $HOME/refresh/bin/funcs.sh

check_rep() {
	typeset P_DB="$1"


	do_isql "$P_DB" "$P_DB..sp_help_rep_agent $P_DB,process"
	checkret "$?" "Can't get rep server status for $P_DB!" "nolog"

	display "$RES"
}

check_ds() {
	typeset P_DS="$1"


	setdb "$P_DS"

	get_envfile "$TMPENV"

	for DB in $REP_AGENT
	do
		echo $DB
		check_rep "$DB"
	done

	rm -f $TMPENV
}

usage() {


	typeset NAME


	NAME=$(basename $1)
	echo "usage: $NAME [-v][-m email-addr] dataserver"
	echo ""
	echo " -v = verbose output"
	echo " -m = address to email report to"

	exit 1

}

set -- `getopt vm: $*`;
if [ "$?" != 0 ]
then
        echo $USAGE
        exit 2
fi
for i in $*
do
        case $i in
        -v)           VERBOSE=$i; shift;;
        -m)           MAILARG=$2; shift 2;;
        --)           shift; break;;
        esac
done

if [ $# -lt 1 ]; then
	usage $0
fi

for DS in "$*"
do
	echo "Checking $DS"
	check_ds "$DS"
done

rm -f $TMPENV

exit 0
