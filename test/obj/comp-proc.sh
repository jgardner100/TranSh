<<#!/bin/bash
#
# get-prot.my
#
# Get the full list of grants for objects
#
# Author: John Gardner
# Date: 1 Nov 2016
#

USE_FILE="Y"
TOTAL_COUNT="0"
OBJ_TYPE="U"

function cleanup {
	echo Stopping
	rm -f $TMPENV
	echo Done
	exit 0
}
trap cleanup SIGTERM SIGINT
trap "" SIGHUP
TMPDIR="$HOME/refresh/tmp"
TMPENV="$TMPDIR/comp-proc-file.$$"

. $HOME/refresh/bin/funcs.sh

#
# Send the output to a specified filename
#
to_file() {
	typeset P_FNAME="$1"
	typeset P_TEXT="$2"


	do_verbose "Got P_FNAME=$P_FNAME & P_TEXT=$P_TEXT"
	if [ \( ! -z "$USE_FILE" \) -a \( -z "$P_FNAME" \) ]; then
		echo "No Filename!"
		exit 1
	elif [ \( ! -z "$USE_FILE" \) -a \( ! -z "$P_FNAME" \) ]; then
		echo "$P_TEXT" >> $HOME/refresh/tmp/$P_FNAME
	else
		echo "$P_TEXT"
	fi
}

#
# Get the actual permissions for the object
#
get_prot_details() {
	typeset OBJECT="$1"
	typeset FNAME="$2"


	typeset CHECKSTR
	typeset OBJECT


	do_verbose "** do_isql $P_TARGETDB sp_helpermission '$OBJECT' **"
	CHECKSTR=$(echo "$OBJECT" | grep "^dbo")
	if [ ! -z "$CHECKSTR" ]; then
		echo "Got checkstr"
		OBJECT=$(echo $OBJECT|cut -d\. -f2)
	fi
	do_verbose "PROCL=$OBJECT"
	#do_isql "$P_TARGETDB" "sp_helpermission '$OBJECT'"
	#checkret "$?" "sp_helpermission failed for $OBJECT"
	do_isql "$P_TARGETDB" "sp_helprotect '$OBJECT'"
	checkret "$?" "sp_helprotect failed for $OBJECT"
	do_verbose "do_isql result is $RES"
	if [ "$?" -ne 0 ]; then
		checkret "1" "Can't select permissions for $OBJECT" "nolog"
	else

		if [ ! -z "$RES" ]; then
			echo "$RES" | 			while read LINE
			do
				to_file "${FNAME}.sql" "$LINE"
			done
		else
			echo "Empty perms for $OBJECT"
		fi
	fi
}

check() {
	typeset P_TARGETDS="$1"
	typeset P_DIR="$2"
	typeset P_WHAT="$3"
	typeset P_KEYWORD="$4"
	typeset P_TARGETDB="$5"


	typeset TXT
	typeset TEXT


	RES=$(tr -s "[:blank:]" <$HOME/refresh/tmp/a2.sql | awk '{print $3,$4,"on",$5,"to",$2}' >$HOME/refresh/tmp/a3.sql)
	RES=$(tr -s "[:blank:]" <$HOME/refresh/tmp/b2.sql | awk '{print $3,$4,"on",$5,"to",$2}' >$HOME/refresh/tmp/b3.sql)

	TXT=$(diff "$HOME/refresh/tmp/a3.sql" "$HOME/refresh/tmp/b3.sql"|grep "$P_DIR"|grep -v wrap_support_grp)

	if [ ! -z "$TXT" ]; then
		echo "$P_WHAT on $P_TARGETDS:"
		TEXT=$(diff "$HOME/refresh/tmp/a3.sql" "$HOME/refresh/tmp/b3.sql"|grep "$P_DIR"|sed "s/^$P_DIR //"|sed "s/^Grant /$P_KEYWORD /"|grep -v wrap_support_grp)

		if [ -z "$EXEC_SQL" ]; then
			display "$TEXT"
		else
			echo "Doing:"
			display "$TEXT"
			do_isql "$P_TARGETDB" "$TEXT"
			checkret "$?" "couldn't change permissions for $P_TARGETDS.$P_TARGETDB"
			echo "do_isql result is $RES"
		fi
	fi
}

#
# Check that the object exists in the database
#
check_exists() {
	typeset P_OBJECT="$1"
	typeset P_DSNAME="$2"


	do_isql "$P_TARGETDB" "select name from sysobjects where name = '$P_OBJECT'"
	checkret "$?" "Can't check for object $P_OBJECT"

	RES=$(echo $RES)

	if [ -z "$RES" ]; then
		echo "NO"
	fi

	echo "YES"
}

#
# Loop over each object in the databases and dump the perms
#
get_prot_list() {
	typeset P_TARGETDB="$1"
	typeset P_TYPE="$2"


	typeset PROCLIST
	typeset PROCL
	typeset CHECKSTR
	typeset EXISTS

	typeset -i COUNT


	setdb "$SOURCEDS" $USE_USER
	do_verbose "do_isql $P_TARGETDB select name from sysobjects where type = '$P_TYPE'"

	do_isql "$P_TARGETDB" "select count(*) from sysobjects where type = '$P_TYPE' and name not like 'rs_%'"
	checkret "$?" "Can't count proc names for $P_TARGETDB"
	TOTAL_COUNT=$(echo $RES)

	do_isql "$P_TARGETDB" "select name from sysobjects where type = '$P_TYPE' and name not like 'rs_%'"
	checkret "$?" "Can't select proc names for $P_TARGETDB"
	PROCLIST="$RES"
	do_verbose "PROCLIST=$PROCLIST"

	COUNT=0
	for PROCL in $PROCLIST
	do
		echo "$COUNT of $TOTAL_COUNT - $P_TARGETDB, $PROCL"

		rm -f "$HOME/refresh/tmp/a1.sql" "$HOME/refresh/tmp/a2.sql"
		touch "$HOME/refresh/tmp/a1.sql" "$HOME/refresh/tmp/a2.sql"

		rm -f "$HOME/refresh/tmp/b1.sql" "$HOME/refresh/tmp/b2.sql"
		touch "$HOME/refresh/tmp/b1.sql" "$HOME/refresh/tmp/b2.sql"

		setdb "$SOURCEDS" $USE_USER
		EXISTS=$(check_exists "$PROCL" "$SOURCEDS")
		if [ "$EXISTS" = "YES" ]; then
			get_prot_details "$PROCL" "b1"

			setdb "$TARGETDS" $USE_USER
			EXISTS=$(check_exists "$PROCL" "$TARGETDS")
			if [ "$EXISTS" = "YES" ]; then
				get_prot_details "$PROCL" "a1"

				sort "$HOME/refresh/tmp/a1.sql" > "$HOME/refresh/tmp/a2.sql"
				sort "$HOME/refresh/tmp/b1.sql" > "$HOME/refresh/tmp/b2.sql"

				check "$TARGETDS" "<" "Revoke" "revoke" "$P_TARGETDB"
				check "$TARGETDS" ">" "Missing" "grant" "$P_TARGETDB"
			else
				echo "No object $PROCL in $TARGETDS.$P_TARGETDB"
			fi
		else
			echo "No object $PROCL in $SOURCEDS.$P_TARGETDB"
		fi

		COUNT=$(expr $COUNT + 1)
	done
}

#
# Dump the cmd usage and exit
#
usage() {
	typeset ARGV="$1"


	typeset NAME


	NAME=$(basename $ARGV)
	echo "$NAME : [-e env][-u user][-f][-v][-t][-d database] source target"

	echo ""
	echo " -v = verbose, output extra messages"
	echo " -t = test run, don't actually run changes "
	echo " -d database = run for this database only "
	echo " -e = env to use (ie FSGDEV2-TST1)"
	echo " -f = output to files in $HOME/refresh/backups"
	echo " -o = object type [U,V,P] (default = U)"
	echo " -h = display this message"
	echo " -u = database user to login as"
	echo " -x = exec the sql to update the premissions"
	echo ""

	exit 1
}

set -- `getopt u:e:d:o:vtfx $*`;
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
        -d)           DB_NAME=$2; shift 2;;
        -o)           OBJ_TYPE=$2; shift 2;;
        -v)           VERBOSE=$i; shift;;
        -t)           TESTMODE=$i; shift;;
        -f)           USE_FILE=$i; shift;;
        -x)           EXEC_SQL=$i; shift;;
        --)           shift; break;;
        esac
done

if [ "$#" -ne 2 ]; then
	usage $0
fi

SOURCEDS="$1"
TARGETDS="$2"

echo "Doing object type of $OBJ_TYPE"

setdb "$TARGETDS" $USE_USER

if [ -z "$DB_NAME" ]; then

	get_envfile "$TMPENV"

	echo "do all databases on $DSNAME"
	for TARGET in $DB_LIST
	do
		get_prot_list "$TARGET" "$OBJ_TYPE"
	done

	rm -f "$TMPENV"

else
	get_prot_list "$DB_NAME" "$OBJ_TYPE"
fi

rm -f $TMPENV

exit 0
