#!/bin/bash
#
# chk-gap.sh
#
# Check the gap between composer and wrap shadow
#
# Author: John Gardner
# Date:
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
TMPENV="$TMPDIR/chk-gap-file.$$"

. $HOME/refresh/bin/funcs.sh

get_val() {
	typeset P_DSNAME="$1"
	typeset P_DBNAME="$2"
	typeset P_QUERY="$3"


	setdb "$P_DSNAME"

	do_isql "$P_DBNAME" "$P_QUERY"

	display "$RES"
}

usage() {


	NAME=$(basename $1)
	echo "usage: $NAME [-v][-d] composer wrap"
	echo ""
	echo "-v = verbose output"
	echo "-e = env to use (ie FSGDEV2-TST1)"
	echo "-u = database user to login as"
	exit 1
}

set -- `getopt e:u:v $*`;
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
        --)           shift; break;;
        esac
done

if [ $# -ne 2 ]; then
	usage $0
fi

COMP="$1"
WRAP="$2"

setdb "$1" $USE_USER
get_envfile "$TMPENV"

echo "Super=$SUPERDB"

VAL_COMP=$(get_val $COMP "$SUPERDB" "select key_sequence \
			from key_sequence \
			where table_name = 'portfolio_split' \
			and code_key = 'ext_ref_id'")
VAL_COMP=$(echo $VAL_COMP)
echo "Composer = $VAL_COMP"

VAL_WRAP=$(get_val $WRAP "sd_super" "select request_num from sd_next_request_num")
VAL_WRAP=$(echo $VAL_WRAP)
echo "Wrap     = $VAL_WRAP"

VAL=$(expr $VAL_COMP - $VAL_WRAP)
echo "Gap = $VAL"

rm -f $TMPENV

exit 0
