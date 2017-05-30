#!/bin/bash

#
# copy-objs.sh - Copy out or in a list of tables and stored procedures to save them across the refresh.
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
TMPENV="$TMPDIR/copy-objs-file.$$"

. $HOME/refresh/bin/funcs.sh

BCPOPTS="-c -t |"

chk_err() {
	typeset FILE="$1"


	typeset ERR
	typeset ERR1
	typeset ERR3
	typeset ERR4
	typeset ERR5
	typeset ERR6
	typeset ERR7
	typeset ERR8

	typeset -i RETVAL


	if [ ! -f "$FILE" ]; then
		echo "No such file $FILE"
		return 1
	fi

	ERR1=$(cat $FILE|grep "Msg ")
	ERR3=$(cat $FILE|grep "DB-LIBRARY error ")
	ERR4=$(cat $FILE|grep "CT-LIBRARY error ")
	ERR5=$(cat $FILE|grep "CSLIB Message")
	ERR6=$(cat $FILE|grep "password incorrect for user")
	ERR7=$(cat $FILE|grep "is not a valid user in database")
	ERR8=$(cat $FILE|grep "Unrecoverable I/O or volume error")

	if [ -z "$ERR1" -a -z "$ERR2" -a -z "$ERR3" -a -z "$ERR4" \
                        -a -z "$ERR5" -a -z "$ERR6" -a -z "$ERR7" \
			-a -z "$ERR8" ]; then
		ERR="$ERR1 $ERR2 $ERR3 $ERR4 $ERR5 $ERR6 $ERR7 $ERR8"
		RETVAL=0
	else
		RETVAL=1
	fi

	#RES=$(cat $FILE|grep -v "rows sent to SQL Server");
	#RES=$(grep -v "rows sent to SQL Server" $FILE);
	return $RETVAL
}

exp_out() {
	typeset TABLES="$1"


	typeset DB
	typeset NAME
	typeset FILE

	typeset OPTS="-U$DBUSER -S$DSQUERY $BCPOPTS" 

	do_verbose "Tables=$TABLES"

	for TABLE in $TABLES
	do
		DB=$(echo $TABLE|cut -d. -f1)
		NAME=$(echo $TABLE|cut -d. -f2)

		FILE="$BACKUP_DIR/$DSQUERY-$NAME.out"

		echo "Doing table $TABLE to $FILE"
		exp "userid=${DBUSER}/${DBPASSWD}@${SID}" "tables=${TABLE}" "file=${FILE}" "rows=y" "grants=y" "indexes=y"
	done
}

bcp_out() {
	typeset TABLES="$1"


	typeset DB
	typeset NAME
	typeset FILE

	typeset OPTS="-U$DBUSER -S$DSQUERY $BCPOPTS" 

	do_verbose "Tables=$TABLES"

	for TABLE in $TABLES
	do
		DB=$(echo $TABLE|cut -d. -f1)
		NAME=$(echo $TABLE|cut -d. -f2)

		FILE="$BACKUP_DIR/$DSQUERY-$NAME.out"

		do_verbose "$DB.dbo.$NAME: $FILE"
		do_verbose bcp "$DB.dbo.$NAME" out $FILE $OPTS
		bcp "$DB.dbo.$NAME" out $FILE $OPTS >$ERRFILE <<EOF
$DBPASSWD
EOF


		chk_err $FILE
		if [ "$?" -ne 0 ]; then
			echo "Err: Bcp out failed! $ERR"
			log_error "bcp" "Bcp out failed $DB.$NAME"
		else
			tail $TAIL_OPT -10 $ERRFILE | 			grep "rows copied"
		fi

		rm -f $ERRFILE
	done
}

truncate_all() {
	typeset TABLES="$1"


	typeset DB
	typeset NAME


	for TABLE in $TABLES
	do

		DB=$(echo $TABLE|cut -d. -f1)
		NAME=$(echo $TABLE|cut -d. -f2)

		do_isql "$DB" "truncate table $NAME"
		checkret "$?" "truncate table $DB.$NAME failed!"
		display "truncate table $DB.$NAME $RES"

	done
}

exp_in() {
	typeset TABLES="$1"


	typeset DB
	typeset NAME
	typeset FILE

	typeset OPTS="-U$DBUSER -S$DSQUERY $BCPOPTS" 

	for TABLE in $TABLES
	do
		DB=$(echo $TABLE|cut -d. -f1)
		NAME=$(echo $TABLE|cut -d. -f2)

		FILE="$BACKUP_DIR/$DSQUERY-$NAME.out"

		imp "userid=${DBUSER}/${DBPASSWD}@${SID}" "tables=${TABLE}" "file=${FILE}" "rows=n" "ignore=n"
	done
}

bcp_in() {
	typeset TABLES="$1"


	typeset DB
	typeset NAME
	typeset FILE
	typeset RES

	typeset OPTS="-U$DBUSER -S$DSQUERY $BCPOPTS" 

	for TABLE in $TABLES
	do
		DB=$(echo $TABLE|cut -d. -f1)
		NAME=$(echo $TABLE|cut -d. -f2)

		do_verbose "$DB.dbo.$NAME"

		split -l 100000 $BACKUP_DIR/$DSQUERY-$NAME.out $BACKUP_DIR/x

		do_isql "$DB" "dump tran $DB with truncate_only"
		checkret "$?" "dump tran $DB failed!"

		for FILE in $BACKUP_DIR/x*
		do
			do_isql "$DB" "dump tran $DB with truncate_only"
			checkret "$?" "dump tran $DB failed!"

			do_verbose bcp "$DB.dbo.$NAME" "in" $FILE $OPTS
			bcp "$DB.dbo.$NAME" "in" $FILE $OPTS >$ERRFILE <<EOF
$DBPASSWD
EOF


			chk_err $ERRFILE
			if [ "$?" -ne 0 ]; then
				echo "Err: Bcp in failed!"
				RES=$(grep -v "rows sent to SQL Server" $ERRFILE)
				echo "$RES"
				log_error "bcp" "Bcp in failed $DB.$NAME"
			else
				tail $TAIL_OPT -10 $ERRFILE | 				grep "rows copied"
			fi

			rm -f $FILE $ERRFILE

		done

		do_isql "$DB" "dump tran $DB with truncate_only"
		checkret "$?" "dump tran $DB failed!"

	done
}

ddl_out() {
	typeset TYPE="$1"
	typeset LIST="$2"


	typeset OBJ
	typeset DB
	typeset NAME


	for OBJ in $LIST
	do
		DB=$(echo $OBJ|cut -d. -f1)
		NAME=$(echo $OBJ|cut -d. -f2)

		do_verbose "dumping sql for $NAME in $DB, type = $TYPE"

		do_ddl $DB $TYPE $NAME "$BACKUP_DIR/${DSQUERY}-${NAME}-out.sql"
		checkret "$?" "ddl out failed for $DB.$NAME"
	done
}

ddl_in() {
	typeset TYPE="$1"
	typeset LIST="$2"


	typeset OBJ
	typeset DB
	typeset NAME
	typeset SQL


	for OBJ in $LIST
	do
		DB=$(echo $OBJ|cut -d. -f1)
		NAME=$(echo $OBJ|cut -d. -f2)

		SQL=$(cat <$BACKUP_DIR/${DSQUERY}-${NAME}-out.sql)

		do_isql "$DB" "$SQL"
		checkret "$?" "Can't exec sql for $DB..$NAME!"

		display "$RES"

		do_verbose "loading sql for $NAME in $DB"
	done
}

usage() {


	typeset NAME


	NAME=$(basename $1)

	echo "usage: $NAME [-e env][-u user][-v] dataserver direction"
	echo ""
	echo " -v = verbose output"
	echo " -e = env to use (ie FSGDEV2-TST1)"
	echo " -u = database user to login as"
	echo ""

	exit 1
}

set -- `getopt vd:e:u: $*`;
if [ "$?" != 0 ]
then
        echo $USAGE
        exit 2
fi
for i in $*
do
        case $i in
        -v)           VERBOSE=$i; shift;;
        -d)           DBARG=$2; shift 2;;
        -e)           USE_ENV=$2; shift 2;;
        -u)           USE_USER=$2; shift 2;;
        --)           shift; break;;
        esac
done

if [ $# -ne 2 ]; then
	usage $0
fi

setdb "$1" $USE_USER
DIR="$2"

get_envfile "$TMPENV"

case $DIR in
	"out")
		if [ "$DBTYPE" = "ORACLE" ]; then
			do_verbose "Bcp Out data = ${SAVE_DATA}"
			exp_out "${SAVE_DATA}"
		else
			do_verbose "Bcp Out tables"
			ddl_out "U" "${SAVE_TABLE}"

			do_verbose "Bcp Out data = $SAVE_DATA"
			bcp_out "${SAVE_DATA}"

			do_verbose "Bcp Out procs ${SAVE_PROCS}"
			ddl_out "P" "${SAVE_PROCS}"
		fi
		;;
	"in")
		if [ "$DBTYPE" = "ORACLE" ]; then
			do_verbose "Bcp In data for ${SAVE_DATA}"
			exp_in "${SAVE_DATA}"
		else
			do_verbose "Bcp In tables"
			ddl_in "U" "${SAVE_TABLE}"

			do_verbose "Bcp In data"
			truncate_all "${SAVE_DATA}"
			bcp_in "${SAVE_DATA}"

			do_verbose "Bcp In procs"
			ddl_in "P" "${SAVE_PROCS}"
		fi
		;;
	*)
		echo "Bad direction $DIR"
		usage
		;;
esac

rm -f $TMPENV

exit 0
