#!/bin/bash


function cleanup {
	echo Stopping
	rm -f $TMPENV
	echo Done
	exit 0
}
trap cleanup SIGTERM SIGINT
trap "" SIGHUP
TMPDIR="$HOME/refresh/tmp"
TMPENV="$TMPDIR/dousers-file.$$"

. $HOME/refresh/bin/funcs.sh

save_aliases() {
	typeset P_DB="$1"


	typeset FILE_NAME


	do_isql "$P_DB" "
		select 
			convert(varchar(30),l.name)
			+','+convert(varchar(30),u.name)
		from sysalternates a, sysusers u, master..syslogins l
		where
		u.suid = a.altsuid
		and l.suid = a.suid"
	checkret "$?" "Can't select aliases list!" "nolog"

	FILE_NAME="$BACKUP_DIR/$DSQUERY-aliases-$P_DB.txt"
	if [ \( -f "$FILE_NAME" \) -a \( ! -z "$P_DB" \) ]; then
		rm -f $FILE_NAME
	fi
	outfile "$FILE_NAME" "$RES" "loop"

	echo "saved aliases to $FILE_NAME"

}

drop_aliases() {
	typeset P_DB="$1"


	do_isql "$P_DB" "
		select 
			convert(varchar(30),l.name)
		from sysalternates a, sysusers u, master..syslogins l
		where
		u.suid = a.altsuid
		and l.suid = a.suid
		and l.name not in ('eip_refresh','syb_dba')"
	checkret "$?" "Can't select aliases list!" "nolog"

	for NAME in $RES
	do
		if [ ! $NAME = "wrapsupp" ]; then

			echo "drop $NAME"
			echo do_isql "$P_DB" "sp_dropalias '$NAME'"

			do_isql "$P_DB" "sp_dropalias '$NAME'"
			checkret "$?" "Can't drop user $NAME!" "nolog"

		else
			echo "Skipping $NAME"
		fi

	done

	echo "dropped aliases"

}

save_groups() {
	typeset P_DB="$1"


	typeset FILE_NAME

	typeset RES


	do_isql "$P_DB" '
		select Group_name = name from sysusers G
		where ((G.uid between @@mingroupid and @@maxgroupid) or G.uid=0)
		and not exists (select "*" from sysroles R where G.uid = R.lrid)
		order by name'
	checkret "$?" "Can't select group list!" "nolog"

	FILE_NAME="$BACKUP_DIR/$DSQUERY-groups-$P_DB.txt"
	if [ \( -f "$FILE_NAME" \) -a \( ! -z "$P_DB" \) ]; then
		rm -f $FILE_NAME
	fi
	RES=$(echo  $RES| cut -d":" -f2)
	outfile "$FILE_NAME" "$RES" "loop"

	echo "saved groups to $FILE_NAME"
}

save_users() {
	typeset P_DB="$1"


	typeset FILE_NAME

	typeset RES


	echo "in save_users() for $P_DB"

	do_isql "$P_DB" "
                        SELECT
                                convert( varchar(60),u.name
                                        +','+convert(varchar(30),u.uid)
                                        +','+g.name
                                )
                        FROM
                                sysusers u, sysusers g
                        WHERE
                                u.suid > 0
                                AND u.name != 'dbo'
                                AND u.gid *= g.uid
                        ORDER BY
                                u.uid
        "
	checkret "$?" "Failed to select users for database $P_DB" "nolog"

	FILE_NAME="$BACKUP_DIR/$DSQUERY-users-$P_DB.txt"
	if [ \( -f "$FILE_NAME" \) -a \( ! -z "$P_DB" \) ]; then
		rm -f $FILE_NAME
	fi
	do_verbose "DEBUG: $RES"
	RES=$(echo $RES| cut -d":" -f2-)
	do_verbose "DEBUG: $RES"
	outfile "$FILE_NAME" "$RES" "loop"
	echo "saved users to $FILE_NAME"
}

#
# For all the users in a db, drop them
#
drop_users() {
	typeset P_DB="$1"


	do_isql "$P_DB" "
                        select name
                        from sysusers
                        where suid > 0
                        and name != 'dbo'
			and name not in ('sa','probe','operator',
					'eip_refresh', 'syb_dba',
					'$DBUSER'
			)
        "
	checkret "$?" "Can't select userlist" "nolog"

	for NAME in $RES
	do
		echo "drop $NAME"
		if [ ! -z "$TESTMODE" ]; then
			echo do_isql "$P_DB" "sp_dropuser '$NAME'"
		else
			do_isql "$P_DB" "sp_dropuser '$NAME'"
			checkret "$?" "Can't drop user $NAME!" "nolog"
		fi
	done
}

#
# Loop over a file and do adduser for each line
#
load_file() {
	typeset P_DB="$1"


	typeset FILE_NAME
	typeset USERN
	typeset GROUP


	FILE_NAME="$BACKUP_DIR/$DSQUERY-users-$P_DB.txt"

	cat $FILE_NAME | 	while read LINE
	do
		USERN=$(echo $LINE|cut -d, -f1)
		GROUP=$(echo $LINE|cut -d, -f3)
		echo $P_DB $USERN $GROUP

		if [ "$GROUP" = "public" ]; then
			do_isql "$P_DB" "sp_adduser $USERN"
			checkret "$?" "Can't add $USERN!" "nolog"
		else
			do_isql "$P_DB" "sp_adduser $USERN,$USERN,$GROUP"
			checkret "$?" "Can't add $USERN $GROUP!" "nolog"
		fi
	done

}

load_users() {
	typeset P_DB="$1"


	echo "in load_users()"

	do_isql "master" "
			select name from syslogins
			where name not in ('sa','probe','operator',
					'eip_refresh', 'syb_dba', 'wrapsupp'
			)
			and name not like '%RSSD%'
			and name not like '%maint%'
			order by name
	"
	checkret "$?" "Can't select users" "nolog"

	for USER in $RES
	do
		if [ ! -z "$TESTMODE" ]; then

			echo do_isql "$P_DB" " sp_addalias '$USER','dbo' "
		else
			do_verbose " sp_addalias '$USER','dbo' "

			do_isql "$P_DB" " sp_addalias '$USER','dbo' "

			do_verbose "$RES"
		fi

	done
}

#
# $1 = direction to copy
#
all_dbs() {
	typeset P_DIR="$1"


	typeset LIST


	if [ -z "$DBARG" ]; then
		LIST="$DB_LIST"
	else
		LIST="$DBARG"
	fi

	for DB in $LIST
	do
		echo $DB

		case $DIR in
			out|OUT)
				echo copy out
				save_users $DB
				save_groups $DB
				save_aliases $DB
				;;
			drop|DROP)
				#drop_users( $DB);
				drop_aliases $DB
				;;
			file|FILE)
				echo "copy file in"
				drop_users $DB
				load_file $DB
				;;
			"in"|"IN")
				echo "copy in"
				#drop_users( $DB);
				load_users $DB
				;;
			*)
				usage
				;;
		esac
	done
}

usage() {
	typeset FULLNAME="$1"

	typeset NAME


	NAME=$(basename "$FULLNAME")

	echo "usage: $NAME [-e env][-u user][-v][-d database] dataserver direction"
	echo ""
	echo " -v = verbose output"
	echo " -d = name of database, otherwise default to all"
	echo " -e = env to use (ie FSGDEV2-TST1)"
	echo " -u = database user to login as"
	echo ""
	echo " where direction can be in|out|file"
	echo ""

	exit 1
}

set -- `getopt u:e:vtd: $*`;
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
        -t)           TESTMODE=$i; shift;;
        -d)           DBARG=$2; shift 2;;
        --)           shift; break;;
        esac
done

if [ $# -ne 2 ]; then
	usage $0
fi

setdb "$1" "$USE_USER"
DIR="$2"

get_envfile "$TMPENV"

all_dbs "$DIR"

rm -f $TMPENV

exit 0
