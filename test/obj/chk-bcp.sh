#!/bin/bash

#
# Header
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
TMPENV="$TMPDIR/chk-bcp-file.$$"

. $HOME/refresh/bin/funcs.sh

check_tables() {
	typeset P_TABLES="$1"
	typeset P_DSQUERY="$2"


	typeset DBNAME
	typeset TABNAME
	typeset RES

	typeset -i COUNT


	printf "%40s" "Name  "
	printf "%-10s" "File "
	printf "%-10s" "Table "
	echo

	for TABLE in $P_TABLES
	do
		DBNAME=$(echo $TABLE|cut -d. -f1)
		TABNAME=$(echo $TABLE|cut -d. -f2)

		printf "%40s" "$TABLE: "

		COUNT=$(wc -l ${BACKUP_DIR}/$P_DSQUERY-${TABNAME}.out|tr -s '[:space:]'|cut -d" " -f1)
		printf "%-10s" "$COUNT "

		do_isql "master" "select count(*) a from $DBNAME..$TABNAME"
		checkret "$?" "Can't select count from table $TABLE" "nolog"

		RES=$(echo $RES|cut -d ":" -f3 |tr -d '[:space:]')
		printf "%-10s" "$RES "

		echo
	done
}

usage() {
	typeset FULLNAME="$1"


	typeset NAME


	NAME=$(basename $FULLNAME)

	echo "usage: $NAME [-e env][-u user][-v][-t] dataserver"
	echo ""
	echo " -v = verbose output"
	echo " -t = test mode"
	echo " -e = env to use (ie FSGDEV2-TST1)"
	echo " -u = database user to login as"
	echo ""

	exit 1
}

set -- `getopt ve:u:t $*`;
if [ "$?" != 0 ]
then
        echo $USAGE
        exit 2
fi
for i in $*
do
        case $i in
        -v)           VERBOSE=$i; shift;;
        -e)           USE_ENV=$2; shift 2;;
        -u)           USE_USER=$2; shift 2;;
        -t)           TESTMODE=$i; shift;;
        --)           shift; break;;
        esac
done

if [ $# -ne 1 ]; then
	usage $0
fi

setdb "$1" "$USE_USER"

get_envfile "$TMPENV"

echo "Save Tables"
echo "---- ------"
check_tables "${SAVE_TABLE}" "$DSQUERY"

echo "Save Data"
echo "---- ----"
check_tables "${SAVE_DATA}" "$DSQUERY"

rm -f $TMPENV

exit 0
