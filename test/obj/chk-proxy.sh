\#!/bin/bash

#
# chk-proxy.my
#
# Check where proxy tables point to.
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
TMPENV="$TMPDIR/chk-proxy-file.$$"

. $HOME/refresh/bin/funcs.sh

TMPFILE="$TMPDIR/proxy-out-$$.txt"
TMPPROXY="$TMPDIR/proxy-out-$$.sql"
TMPERR="$TMPDIR/proxy-err-$$.txt"

dump_sysstat() {
	typeset P_DBNAME="$1"
	typeset P_TABLE="$2"


	typeset STAT


	do_verbose "dump_sysstat() $P_DBNAME $P_TABLE"

	do_isql "$DBNAME" "select '#'+
				convert(varchar(4),(sysstat2&2048))+'#'
			from
				sysobjects 
			where 
				(sysstat2 & 1024) = 1024
				and type = 'U'
				and name = '$P_TABLE'
	"
	do_verbose "RES=$RES"

	STAT=$(echo "$RES"|cut -d# -f2)
	if [ "$STAT" = "2048" ]; then
		printf "Create Exists "
	else
		printf "Not Create Exists $STAT "
	fi
}

#
# Dump to a file the sql to create the proxy table
#
dump_tofile() {
	typeset T_DBNAME="$1"
	typeset T_TABLE="$2"


	echo $T_DBNAME/$T_TABLE

	ddlgen -U $DBUSER -I $SYBASE/interfaces -S $DSQUERY -P $DBPASSWD -D $T_DBNAME -TU -XOD -N $T_TABLE -O $TMPFILE -E $TMPERR
	checkret "$?" "ddl out failed for $T_DBNAME.$T_TABLE"

	grep " at " $TMPFILE

	cp $TMPFILE $BACKUP_DIR/$DSQUERY-proxy-$T_DBNAME-${T_TABLE}.sql

}

#
# Just dump where the proxy table points to
#
dump_proxy() {
	typeset P_DBNAME="$1"
	typeset P_TABLE="$2"


	do_verbose "dump_proxy() $P_DBNAME $P_TABLE"

	echo $P_DBNAME/$P_TABLE

	do_isql "$P_DBNAME" "select convert(varchar(60),'#'+char_value+'#') from sysattributes
			where class = 9 and attribute = 1 and
			object_cinfo = '$P_TABLE'
	"

	checkret "$?" "select proxy table details failed" "nolog"

	RES=$(cat <<EOS | cut -f2 -d# | head -1 | grep -v "^EOS"
$RES
EOS
)
	echo "	$RES"

	do_verbose "RES=$RES"
}

check_exists() {
	typeset P_DBNAME="$1"
	typeset P_TABLE="$2"


	do_isql "$P_DBNAME" "
                        select convert(varchar(60),'#'+name+'#') a
                                from sysobjects
                                where
                                        (sysstat2 & 1024) = 1024
                                and type = 'U'
                                and name = '$P_TABLE'
        "
	checkret "$?" "Can't select table!" "nolog"

	do_verbose "RES1=$RES"
	RES=$(cat <<EOS|cut -d# -f2|grep -v "^EOS"
$RES
EOS
)
	do_verbose "RES2=[$RES], P_TABLE=[$P_TABLE]"

	if [ "$RES" = "$P_TABLE" ]; then
		return 1
	else
		return 0
	fi
}

process_indb() {


	typeset -i RETVAL


	for DBNAME in $DB_LIST
	do

		#
		# Find all proxy tables in the database
		#
		do_isql "$DBNAME" "select ':'+name+':'
				from sysobjects 
				where 
					(sysstat2 & 1024) = 1024
				and type = 'U'
				order by name
		"
		RETVAL="$?"

		#
		# Note, need to skip failed access to databases (retval = 2)
		#
		if [ "$RETVAL" -ne 2 ]; then

			checkret "$RETVAL" "select table types failed" "nolog"

			if [ "$RETVAL" -eq 0 ]; then

				RES=$(cat <<EOS|cut -f2 -d:|grep -v "^EOS"
$RES
EOS
)

				for TABLE in $RES
				do
					if [ -z "$JUST_DUMP" ]; then
						dump_sysstat "$DBNAME" "$TABLE"
						dump_proxy "$DBNAME" "$TABLE"
					else
						dump_tofile "$DBNAME" "$TABLE"
					fi
				done
				if [ ! -z "$VERBOSE" ]; then
					display "$RES"
				fi
			fi

		fi
	done
}

process_incfg() {


	typeset ACTION
	typeset DBNAME
	typeset TABLE
	typeset UNAME


	get_param "$TMPENV" "proxy_action"
	ACTION="$PVAL"

	echo "Action = $ACTION"

	for ENTRY in $PROXY_LIST
	do
		DBNAME=$(echo $ENTRY|cut -d: -f1)
		TABLE=$(echo $ENTRY|cut -d: -f2)
		UNAME=$(echo $ENTRY|cut -d: -f3)

		echo check_exists $DBNAME $TABLE
		check_exists "$DBNAME" "$TABLE"
		if [ "$?" -ne 0 ]; then
			do_verbose "do ddl_proxy $DBNAME.$TABLE"
			dump_proxy "$DBNAME" "$TABLE"
		else
			echo
			echo "SKIP $DBNAME.$TABLE - IT DOESN'T EXIST!"
		fi

	done
}

usage() {
	typeset ARGV="$1"


	typeset NAME


	NAME=$(basename "$ARGV")

	echo "usage: $NAME [-v][-d] dataserver"
	echo ""
	echo " -v = verbose output"
	echo " -x = extra verbose output"
	echo " -d = dump sql for proxy tables"
	echo " -a = do all proxy tables in database"
	echo " -e = env to use (ie FSGDEV2-TST1)"
	echo " -u = database user to login as"

	exit 1

}

set -- `getopt e:u:vdax $*`;
if [ "$?" != 0 ]
then
        echo $USAGE
        exit 2
fi
for i in $*
do
        case $i in
        -e)           USE_ENV=$2; shift 2;;
        -u)           USE_USER=$2; shift 2;;
        -v)           VERBOSE=$i; shift;;
        -d)           JUST_DUMP=$i; shift;;
        -a)           DO_ALL=$i; shift;;
        -x)           VERBOSE=$i; shift;;
        --)           shift; break;;
        esac
done

if [ $# -ne 1 ]; then
	usage "$0"
fi

setdb "$1" $USE_USER

get_envfile "$TMPENV"

if [ ! -z "$DO_ALL" ]; then
	process_indb
else
	process_incfg
fi

rm -f "$TMPFILE" "$TMPPROXY" "$TMPERR"

rm -f $TMPENV

exit 0
