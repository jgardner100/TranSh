  
test=1

function cleanup {
	echo Stopping
	rm -f $TMPENV
	echo Done
	exit 0
}
trap cleanup SIGTERM SIGINT
trap "" SIGHUP
TMPDIR="$HOME/refresh/tmp"
TMPENV="$TMPDIR/t9-file.$$"

. $HOME/refresh/bin/funcs.sh


test1 "hi there" 1

rm -f $TMPENV

exit 0
