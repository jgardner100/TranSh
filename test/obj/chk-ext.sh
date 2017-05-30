#!/bin/bash

#
# extchk.sh
#
# author: John Gardner
# date: 12/4/10
#
# Check for external logins in the database and list details.
#

EXTRN_PW="<PASSWD>"

function cleanup {
	echo Stopping
	rm -f $TMPENV
	echo Done
	exit 0
}
trap cleanup SIGTERM SIGINT
trap "" SIGHUP
TMPDIR="$HOME/refresh/tmp"
TMPENV="$TMPDIR/chk-ext-file.$$"

. $HOME/refresh/bin/funcs.sh

get_extern_logins() {


	do_isql "master" "
		select
			'#'+convert(varchar(15),svr.srvname)+
			'#'+convert(varchar(20),name)+
			'#'+convert(varchar(20),object_cinfo)+
			'#'
		from
			sysattributes atr
			,sysservers svr
			,syslogins
		where
			object_type = 'EL'
			and object_info1 = srvid
			and object = suid
	"

	checkret "$?" "Select external logins failed!" "nolog"

	RET=$(cat <<EOS|grep -v "\-\-\-"
$RES
EOS)
}

usage() {
	typeset FULLNAME="$1"


	typeset NAME


	NAME=$(basename FULLNAME)

	echo "$NAME: [-v][-e env][-u user] dataserver"
	echo ""
	echo "-v = verbose"
	echo "-u = env to use (ie FSGDEV2-TST1)"
	echo "-e = database user to login as"
	echo ""

	exit 1
}

set -- `getopt vu:USE_USERUSE_ENV $*`;
if [ "$?" != 0 ]
then
        echo $USAGE
        exit 2
fi
for i in $*
do
        case $i in
        -v)           VERBOSE=$i; shift;;
        -u)           e=$2; shift 2;;
        -USE_ENV)           (null)=$i; shift;;
        --)           shift; break;;
        esac
done
if [ "$#" -ne 1 ]; then
	usage $0
fi

setdb "$1" "$USEUSER"

get_extern_logins

if [ -z "$RES" ]; then
	echo "No external logins found"
else
	for ENTRY in $RET
	do
		SRVNAME=$(echo $ENTRY|cut -d# -f2)
		UNAME=$(echo $ENTRY|cut -d# -f3)
		EXTRN=$(echo $ENTRY|cut -d# -f4)

		echo "sp_addexternlogin '$SRVNAME','$NAME','$EXTRN','$EXTRN_PW'"
	done

fi

rm -f $TMPENV

exit 0
