\\\#!/bin/bash

#
# chk-rep.my
#
# Check replication template names
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
TMPENV="$TMPDIR/chk-rep-file.$$"

. $HOME/refresh/bin/funcs.sh

list_procs() {
	typeset P_DBNAME="$1"


	do_isql "$P_DBNAME" "
			select
				name
			from
				sysobjects o
			where
				type = 'P'
				and (sysstat & -32768) = -32768
				and (sysstat & 64) = 64
	"

	if [ "$RETVAL" -ne 2 ]; then
		checkret "$?" "select replicated proc names failed" "nolog"
	fi
}

list_dbs() {


	get_param "$ENVFILE" "DB_LIST"
	RES=$DB_LIST
}

do_dump() {
	typeset P_PROC="$1"


	typeset L_PROC
	typeset L_DBNAME


	L_PROC=$(echo $P_PROC|cut -d. -f2)
	L_DBNAME=$(echo $P_PROC|cut -d. -f1)

	if [ ! -z "$VERBOSE" ]; then
		echo "dumping db=$L_DBNAME proc=$L_PROC"
	fi

	ddlgen -U $DBUSER -I $SYBASE/interfaces -S $DSQUERY -P $DBPASSWD -D $L_DBNAME -TP -N $T_PROC -O $HOME/tmp/$L_DBNAME-$T_PROC-out.sql -E $HOME/tmp/err.txt

}

do_dump_hdr() {
	typeset P_PNAME="$1"


	typeset L_PNAME
	typeset L_DB
	typeset VAL


	L_PNAME=$(echo $P_PNAME|cut -d. -f2)
	L_DB=$(echo $P_PNAME|cut -d. -f1)

	do_isql "$T_DB" "
			SELECT c.text
			FROM sysobjects AS o
				INNER JOIN syscomments AS c
				ON o.id = c.id
			WHERE o.name = '$L_PNAME'
	"
	checkret "$?" "select proc text $L_PNAME failed" "nolog"

	VAL=$(cat <<EOF|grep -v "\-\-.*@"|grep "@rs_repdef.*varchar"
$RES
EOF
)
	VAL=$(echo $VAL|cut -d\" -f2)

	echo "	$VAL"
}

do_dump_list() {
	typeset P_TNAME="$1"


	echo "$P_TNAME"
}

do_datas() {
	typeset P_DATAS="$1"


	typeset CONFIGFILE


	setdb "$P_DATAS" $USE_USER

	CONFIGFILE="$HOME/${DSQUERY}.cfg"

	if [ -f "$CONFIGFILE" ]; then
		echo "Config file exists, using proclist"

		get_envfile "$ENVFILE"

		for TABLE in $REP_PROCS
		do
			do_dump_list $TABLE
		done
	else
		echo "No Config file, using sp_setproc"
	fi
}

usage() {
	typeset ARGV="$1"


	typeset NAME


	NAME=$(basename "$ARGV")

	echo "usage: $NAME [-v][-m mailaddr][-e env][-u user] dataserver"
	echo ""
	echo "-m = mail report to mailaddr"
	echo "-v = verbose output"
	echo "-d = dump proc sql"
	echo "-c = use configuration file"
	echo "-e = env to use (ie FSGDEV2-TST1)"
	echo "-u = database user to login as"

	exit 1
}

set -- `getopt m:vdce:u: $*`;
if [ "$?" != 0 ]
then
        echo $USAGE
        exit 2
fi
for i in $*
do
        case $i in
        -m)           MAILTO=$2; shift 2;;
        -v)           VERBOSE=$i; shift;;
        -d)           DODUMP=$i; shift;;
        -c)           USE_CONF=$i; shift;;
        -e)           USE_ENV=$2; shift 2;;
        -u)           USE_USER=$2; shift 2;;
        --)           shift; break;;
        esac
done

if [ \( "$#" -ne 1 \) -a \( "$#" -ne 2 \) ]; then
	usage $0
fi

setdb "$1" $USE_USER

if [ $# -eq 2 ]; then
	list_procs "$2"

	if [ "$RETVAL" -ne 2 ]; then
		for TABLE in $RES
		do
			echo "$2 : $TABLE"
			do_dump_hdr "$2.$TABLE"
		done
	fi
else

	get_envfile "$ENVFILE"

	if [ ! -z "$DODUMP" ]; then
		echo "Dumping sql"

		if [ ! -z "$USE_CONF" ]; then
			for TABLE in $REP_PROCS
			do
				do_dump "$TABLE"
			done
		else
			list_dbs
			DBLIST=$RES
			for DB in $DBLIST
			do
				list_procs "$DB"
				if [ "$RETVAL" -ne 2 ]; then
					for TABLE in $RES
					do
						echo "$DB : $TABLE"
						do_dump "$DB.$TABLE"
					done
				fi
			done
		fi
	else
		for DBNAME in $DB_LIST
		do
			echo "DB=$DBNAME"

			list_procs "$DBNAME"
			if [ "$RETVAL" -ne 2 ]; then
				for TABLE in $RES
				do
					echo "$DBNAME : $TABLE"
					do_dump_hdr "$DBNAME.$TABLE"
				done
			fi
		done
	fi
fi

rm -f $TMPENV

exit 0

exit 0
