#!/bin/bash
#
# get-prot.my
#
# Get the full list of grants for objects
#
# Author: John Gardner
# Date: 1 Nov 2016
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
TMPENV="$TMPDIR/get-prot-file.$$"

. $HOME/refresh/bin/funcs.sh

#
# Get rid of the old file
#
clean_file() {
	typeset P_FNAME="$1"


	rm -f "$HOME/refresh/backups/$P_FNAME"
}

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
		echo "$P_TEXT" >> "$HOME/refresh/backups/$P_FNAME"
	else
		echo "$P_TEXT"
	fi
}

#
# Extract the sql for the permissions directly, avoid sp_helprotect, it truncates
#
get_permission2() {
	typeset P_TARGETDB="$1"
	typeset P_PROCL="$2"


	typeset TYPE
	typeset ACTION
	typeset COLUMNS
	typeset GRANTEE
	typeset ACTION_STR

	typeset TEXT


	do_verbose "PROCL=$P_PROCL"
	do_isql "$P_TARGETDB" "
                select ':'+convert(varchar(5),p.protecttype)+
			':'+convert(varchar(5),p.action)+
			':'+p.columns+
			':'+u.name+':'
               from sysusers u, sysobjects o, sysprotects p
               where o.name = '$P_PROCL'
                 and o.id   = p.id
                 and p.uid  = u.uid
                 and o.type in ('S','U','V','P')
        "
	checkret "$?" "select perms failed for |$P_PROCL|" "nolog"

	echo "$RES" | 	while read LINE
	do
		TYPE=$(echo $LINE|cut -d: -f2)
		ACTION=$(echo $LINE|cut -d: -f3)
		COLUMNS=$(echo $LINE|cut -d: -f4)
		GRANTEE=$(echo $LINE|cut -d: -f5)
		case $ACTION in
			"151")
				ACTION_STR="references"
				;;
			"193")
				ACTION_STR="select"
				;;
			"195")
				ACTION_STR="insert"
				;;
			"196")
				ACTION_STR="delete"
				;;
			"197")
				ACTION_STR="update"
				;;
			"224")
				ACTION_STR="execute"
				;;
			"282")
				ACTION_STR="delete statistics"
				;;
			"320")
				ACTION_STR="truncate table"
				;;
			"326")
				ACTION_STR="update statistics"
				;;
			*)
				echo "Unknown action $ACTION"
				return
				;;
		esac
		if [ "$TYPE" -eq 0 ]; then
			TEXT="grant $ACTION_STR on $P_PROCL to $GRANTEE with grant option"
		elif [ "$TYPE" -eq 1 ]; then
			TEXT="grant $ACTION_STR on $P_PROCL to $GRANTEE"
		else
			TEXT="revoke $ACTION_STR on $P_PROCL from $GRANTEE"
		fi
		to_file "${DSQUERY}-${P_TARGETDB}-prot.sql" "$TEXT"
	done
}

get_permission1() {
	typeset P_TARGETDB="$1"
	typeset P_PROCL="$2"


	do_verbose "PROCL=$P_PROCL"
	do_isql "$P_TARGETDB" "sp_helpermission '$P_PROCL'"
	checkret "$?" "sp_helpermission failed for $P_PROCL" "nolog"
	do_verbose "do_isql result is $RES"
	if [ "$?" -ne 0 ]; then
		checkret 1 "Can't select permissions for $P_PROCL" "nolog"
	else

		if [ ! -z "$RES" ]; then
			echo "$RES" | 			while read LINE
			do
				to_file "${DSQUERY}-${P_TARGETDB}-prot.sql" "$LINE"
			done
		fi
	fi
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


	clean_file "${DSQUERY}-${P_TARGETDB}-prot.sql"

	to_file "${DSQUERY}-${P_TARGETDB}-prot.sql" "Use $P_TARGETDB"
	to_file "${DSQUERY}-${P_TARGETDB}-prot.sql" "Go"
	to_file "${DSQUERY}-${P_TARGETDB}-prot.sql" ""

	do_verbose "do_isql $P_TARGETDB select name from sysobjects where type = '$P_TYPE'"
	do_isql "$P_TARGETDB" "select name from sysobjects where type = '$P_TYPE' order by name"
	checkret "$?" "Can't select proc names for $P_TARGETDB" "nolog"
	PROCLIST="$RES"
	do_verbose "PROCLIST=$PROCLIST"

	for PROCL in $PROCLIST
	do
		if [ ! -z "$USE_FILE" ]; then
			echo "$P_TARGETDB, $PROCL"
		fi

		to_file "${DSQUERY}-${P_TARGETDB}-prot.sql" "/* $PROCL */"
		do_verbose "** do_isql $P_TARGETDB sp_helprotect '$PROCL' **"
		CHECKSTR=$(echo "$PROCL" | grep "^dbo")
		if [ ! -z "$CHECKSTR" ]; then
			echo "Got checkstr"
			PROCL=$(echo $PROCL|cut -d\. -f2)
		fi

		get_permission2 "$P_TARGETDB" "$PROCL"

		to_file "${DSQUERY}-${P_TARGETDB}-prot.sql" "Go"
		to_file "${DSQUERY}-${P_TARGETDB}-prot.sql" ""
	done
}

#
# Dump the cmd usage and exit
#
usage() {
	typeset ARGV="$1"


	typeset NAME


	NAME=$(basename $ARGV)
	echo "$NAME : [-e env][-u user][-f][-v][-t][-d database] dataserver"

	echo ""
	echo " -v = verbose, output extra messages"
	echo " -t = test run, don't actually run changes "
	echo " -d database = run for this database only "
	echo " -e = env to use (ie FSGDEV2-TST1)"
	echo " -f = output to files in $HOME/refresh/backups"
	echo " -h = display this message"
	echo " -u = database user to login as"
	echo ""

	exit 1
}

set -- `getopt u:e:d:vtf $*`;
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
        -v)           VERBOSE=$i; shift;;
        -t)           TESTMODE=$i; shift;;
        -f)           USE_FILE=$i; shift;;
        --)           shift; break;;
        esac
done
if [ "$#" -ne 1 ]; then
	echo "argv count is $#"
	usage $0
fi

NAME=$(basename "$0")

TARGETDS="$1"

setdb "$TARGETDS" $USE_USER

if [ -z "$DB_NAME" ]; then

	get_envfile "$TMPENV"

	echo "do all databases on $DSNAME"
	for TARGET in $DB_LIST
	do
		get_prot_list "$TARGET" "V"
		get_prot_list "$TARGET" "U"
	done

	rm -f "$TMPENV"

else
	get_prot_list "$DB_NAME" "V"
	get_prot_list "$DB_NAME" "U"
fi

rm -f $TMPENV

exit 0
