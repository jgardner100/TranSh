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
TMPENV="$TMPDIR/bcpcopy-file.$$"

. $HOME/refresh/bin/funcs.sh

TMPDIR="/var/tmp/t2"
SIZE=250000

bcp_out() {
	typeset P_DB="$1"
	typeset P_TABNAME="$2"


	do_verbose "bcp $P_DB..$P_TABNAME out $P_TABNAME -c -t | -U$DBUSER -S$DSQUERY"
	bcp "$P_DB..$P_TABNAME" out "$P_TABNAME" -c -t "|" -U $DBUSER -S $DSQUERY <<EOF
$DBPASSWD
EOF


}

bcp_in() {
	typeset P_DB="$1"
	typeset P_TABNAME="$2"


	split -l "$SIZE" "$P_TABNAME" x

	for PIECE in xa*
	do
		echo $PIECE

		do_isql "$DBARG" "dump tran $DBARG with truncate_only"
		checkret "$?" "Can't dump transaction log!" "nolog"

		do_verbose "bcp $P_DB..$P_TABNAME in $PIECE -c -t | -U$DBUSER -S$DSQUERY"
		bcp "$P_DB..$P_TABNAME" "in" $PIECE -c -t "|" -U $DBUSER -S $DSQUERY <<EOF
$DBPASSWD
EOF

	done
}

usage() {
	typeset FULLNAME="$1"


	typeset NAME


	NAME=$(basename $FULLNAME)

	echo "usage: $NAME [-e env][-u user][-t][-v] -n table-name -d database source-ds target-ds"
	echo ""
	echo " -t = test mode, don't actually bcp the data in"
	echo " -v = verbose mode - extra output"
	echo " -d database = single database to run against"
	echo " -n table-name = name of the table to copy across"
	echo " -e = env to use (ie FSGDEV2-TST1)"
	echo " -u = database user to login as"
	echo ""

	exit 1
}

set -- `getopt u:e:vtn:d: $*`;
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
        -n)           NAMEARG=$2; shift 2;;
        -d)           DBARG=$2; shift 2;;
        --)           shift; break;;
        esac
done

if [ \( $# -ne 2 \) -o \( -z "$DBARG" \) -o \( -z "$NAMEARG" \) ]; then
	usage $0
fi

SOURCE="$1"
TARGET="$2"

setdb "$SOURCE" "$USE_USER"

do_verbose "Doing $NAMEARG"

if [ ! -d "$TMPDIR" ]; then
	mkdir -p "$TMPDIR"
fi
cd $TMPDIR

do_verbose "bcp_out $DBARG $NAMEARG"
bcp_out "$DBARG" "$NAMEARG"

if [ ! -f "$NAMEARG" ]; then
	echo "NO such file $NAMEARG"
	exit 1
fi

setdb $TARGET

if [ -z "$TESTMODE" ]; then
	do_verbose "Starting load"
	do_verbose "bcp_in $DSQUERY $DBARG $NAMEARG"
	bcp_in "$DSQUERY" "$DBARG" "$NAMEARG"
else
	echo "Running in testmode, no changes to be made"
	echo ""
	echo "bcp_in $DSQUERY $DBARG $NAMEARG"
fi

rm -f $TMPDIR/xa*

rm -f $TMPENV

exit 0
