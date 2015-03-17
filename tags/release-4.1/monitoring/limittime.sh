#!/bin/bash

P_TIMEOUT=$1
shift 1

if [ "$#" -lt "1" ]; then
	echo "Usage:   `basename $0` timeout_in_seconds command" >&2
	echo "Example: `basename $0` 2 sleep 3 || echo timeout" >&2
	exit 1
fi

S_PARAMS="$@"
S_STARTEDPROCESS=

function f_watchcmd() {
	local P_TIMEOUT=$1
	local P_CMDPROC=$2

	sleep $P_TIMEOUT
	kill -9 -$P_CMDPROC
}

function f_runcmd() {
	local F_CURPROC=$$
	setsid $S_PARAMS < /dev/null > /dev/null 2>&1 &

	# get started process ID
	local F_STARTEDPROCESS=`pgrep -o -P $F_CURPROC | tr "\n" " "`

	if [ "$F_STARTEDPROCESS" = "" ]; then
		S_STARTEDPROCESS=1
	else
		S_STARTEDPROCESS=$F_STARTEDPROCESS
	fi
}

# execute command
f_runcmd
S_CMDPROC=$S_STARTEDPROCESS

if [ "$S_CMDPROC" = "1" ]; then
	echo unable to start $S_PARAMS. Exiting
	exit 1
fi

# execute wait
f_watchcmd $P_TIMEOUT $S_CMDPROC > /dev/null 2>&1 &
S_WATCHPROC=$!

# wait for primary process
wait $S_CMDPROC > /dev/null 2>&1
RET=$?

if [ "`pgrep -P $S_WATCHPROC`" != "" ]; then
	kill -9 $S_WATCHPROC
fi

if [ "$RET" = "137" ]; then
	echo process tree killed due to timeout=$P_TIMEOUT cmd=$S_PARAMS
	exit 1
fi

exit 0
