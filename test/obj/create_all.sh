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
TMPENV="$TMPDIR/create_all-file.$$"

. $HOME/refresh/bin/funcs.sh


NAME_LIST="SDWRPDEV2:sd_wrap SDWRPDEV2:sd_super SDWRPDEV2:sd_main \
	SDWRPDEV2:sd_log FSGDEV11:wrap_prd FSGDEV11:amd_prd"

for NAME in $NAME_LIST
do
	DS_NAME=$(echo $NAME|cut -d: -f1)
	DB_NAME=$(echo $NAME|cut -d: -f2)

	echo $DS_NAME $DB_NAME

	setdb $DS_NAME

	do_isql "$DB_NAME" "sp_dropalias wrapfp_user"
	checkret "$?" "can't drop alias in $DB_NAME!"

	do_isql "$DB_NAME" "sp_adduser wrapfp_user"
	checkret "$?" "can't add user in $DB_NAME!"

	do_isql "$DB_NAME" "sp_changegroup wrapfp_grp,wrapfp_user"
	checkret "$?" "can't change group in $DB_NAME!"

	SQL=$(cat $HOME/src/perl/$DB_NAME.sql)
	do_isql "$DB_NAME" "$SQL"
	checkret "$?" "Can't grant permissions in $DB_NAME!"

done

rm -f $TMPENV

exit 0
