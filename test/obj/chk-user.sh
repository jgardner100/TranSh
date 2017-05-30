#!/bin/bash

#
# chk-user.sh
#
# Author: John Gardner
# Date: 5th July 2010
#
# Nasty little hack to make sure that wrap_prd_maint user gets mapped to 
# dbo properly on amd_prd on FSGDEV11 so that cross db replicated transactions
# will work.
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
TMPENV="$TMPDIR/chk-user-file.$$"

. $HOME/refresh/bin/funcs.sh

check_alias() {
	typeset P_DBNAME="$1"
	typeset P_USERN="$2"


	do_isql "$P_DBNAME" "sp_helpuser $P_USERN"
	checkret "$?" "Can't run sp_helpuser for $P_USERN!"

	RES=$(echo $RES|tr -s "[:space:]" " "|cut -d" " -f4)

	display "$RES"
	if [ ! -z "$RES" ]; then
		echo "User exists, alias = $RES"
	else
		echo "User $P_USERN missing from database $P_DBNAME"
	fi
}

check_login() {
	typeset P_DBNAME="$1"
	typeset P_USERN="$2"


	do_isql "master" "select suid,name
				from syslogins
				where name = '$P_USERN'"
	checkret "$?" "Can't select login entry for $P_USERN!"

	RES=$(echo $RES|tr -s "[:space:]" " ")

	if [ -z "$RES" ]; then
		echo "No such user $P_USERN"
	else
		echo "login exists = $RES"
		check_alias $P_DBNAME $P_USERN
	fi

}

check_users() {


	typeset FILE_NAME

	typeset USERN


	FILE_NAME="$BACKUP_DIR/$DSQUERY-users-$DB.txt"

	cat $FILE_NAME | 	while read LINE
	do
		USERN=$(echo $LINE|cut -d, -f1)
		check_login $DB $USERN
		echo ""
	done
}
check_user_alias() {
	typeset P_DBNAME="$1"
	typeset P_USERN="$2"


	do_isql "$P_DBNAME" "sp_helpuser $P_USERN"
	checkret "$?" "Can't run sp_helpuser for $P_USERN!"

	RES=$(cat <<EOF|tail $TAIL_OPT +2
$RES
EOF
)

	RES=$(echo $RES|tr -s "[:space:]" " "|cut -d" " -f4)

	echo "User=$P_USERN, Alias=$RES"
}

check_aliases() {
	typeset P_DBNAME="$1"


	typeset FILE_NAME

	typeset USERN


	FILE_NAME="$BACKUP_DIR/$DSQUERY-aliases-$DB.txt"

	cat $FILE_NAME | 	while read LINE
	do
		USERN=$(echo $LINE|cut -d, -f1)
		check_user_alias $DB $USERN
	done
}

all_dbs() {


	typeset LIST


	if [ -z "$DBARG" ]; then
		LIST="$DB_LIST"
	else
		LIST="$DBARG"
	fi

	for DB in $LIST
	do
		echo "Database=$DB"

		check_users 

		check_aliases $DB
	done

}

usage() {
	typeset ARGV="$1"


	typeset NAME


	NAME=$(basename $ARGV)

	echo "$NAME: [-e env][-u user][-v][-d database] dataserver"
	echo ""
	echo "-d database = name of database to check (default = all)"
	echo "-v = verbose output"
	echo "-e = env to use (ie FSGDEV2-TST1)"
	echo "-u = database user to login as"
	echo ""

	exit 1
}

set -- `getopt u:e:vd: $*`;
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
        -d)           DBARG=$2; shift 2;;
        --)           shift; break;;
        esac
done

if [ "$#" -ne 1 ]; then
	usage $0
fi

setdb $1 $USE_USER

get_envfile $TMPENV

all_dbs 

rm -f $TMPENV

exit 0
