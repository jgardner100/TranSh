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
TMPENV="$TMPDIR/t1-file.$$"

. $HOME/refresh/bin/funcs.sh

test1() {
	typeset a="$1"
	typeset -i b="$2"
	typeset -r c="$3"


	typeset testvar 

	testvar="1"
	badvar="2"

	echo $a $b $c
}

typeset STRING 
typeset -i INTEGER 

testvar="1"

test1 
test1 oneparam
test1 twoparam there
test1 threeparam 1 there
test1 "hello (`date`)" 1 "there"
test1 way too many args

badname()

ENTRY=$( grep \^${USERNAME}: $HOME/refresh/pwd/$DSQUERY)

rm -f $TMPENV

exit 0
