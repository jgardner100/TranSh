#!/bin/bash
#
# ./chk-backup.my - Check that the backups are ready to load
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
TMPENV="$TMPDIR/chk-backup-file.$$"

. $HOME/refresh/bin/funcs.sh

#
# Verify a backup by looking at the dump header
#
# $1 = Database name dump would be loaded to (note, won't actually load dump)
# $2 = Directory where dumps are stored
# $3 = List of file names in single dump
#
verifydb() {
	typeset P_DATABASE="$1"
	typeset P_DIR="$2"
	typeset P_FILES="$3"


	do_verbose "checking database dump for $P_DATABASE"

	CMD=""

	for FILE in $P_FILES
	do
		if [ -z $CMD ]; then
			CMD="load database ${P_DATABASE} from '${P_DIR}/${FILE}' "
		else
			CMD="$CMD stripe on '${P_DIR}/${FILE}' "
		fi
	done
	CMD="$CMD with headeronly"

	do_isql "master" "$CMD"

	if [ "$RETVAL" -eq 0 ]; then
		echo "database dump is good for $P_DATABASE"

		cat <<EOF | grep "This is a database dump of database"
$RES
EOF


		return 0
	else
		echo "database dump failed verification for $P_DATABASE"
		display "$CMD"
		display "$RES"
		return 1
	fi
}

#
# find_backups()
#
# $1 = directory containing backups
# $2 = dsquery of sybase server to find backups for
#
find_backups() {
	typeset P_DIR="$1"
	typeset P_DSNAME="$2"
	typeset P_DBNAME="$3"

	if [ ! -d "$P_DIR" ]; then
		echo "No such dir: $P_DIR"
		FILES=""
	else
		FILES=$(cd $P_DIR; ls *${P_DBNAME}*${P_DSNAME}* 2>&1 |
			grep -v "No such file or directory"|sort)

		FILES=$(echo $FILES)

		do_verbose "Found backups files: $FILES"
	fi

}

usage() {

	NAME=$(basename $1)
	echo "usage: $NAME [-v] $NAME dataserver"
	echo " -v = verbose mode, extra output"
	exit 1
}

set -- `getopt v $*`;
if [ "$?" != 0 ]
then
        echo $USAGE
        exit 2
fi
for i in $*
do
        case $i in
        -v)           Verbose=$i; shift;;
        --)           shift; break;;
        esac
done

if [ $# -ne 1 ]; then
	usage $0
fi

setdb $1

do_verbose "Starting loads for $DSQUERY"

get_envfile $TMPENV

#SRC_DIR="/var/opt/sybase_dumps/DO_NOT_DELETE"
#int COUNT=0;
COUNT=0

for DB in $DB_LIST
do
	do_verbose "$COUNT: Checking backup for $DB"
	COUNT=$(expr $COUNT + 1)

	find_backups $DUMP_DIR $DSQUERY "$DB"

	if [ ! -z "$FILES" ]; then
		verifydb "$DB" "$DUMP_DIR" "$FILES"
	fi

done

do_verbose "loads complete"

rm -f $TMPENV

exit 0
