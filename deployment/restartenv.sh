#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

. ./getopts.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo restartenv.sh: DC not set
	exit 1
fi

SRVNAME_LIST=$*

RESTART_SERVER_LIST=$SRVNAME_LIST
if [ "$RESTART_SERVER_LIST" = "" ]; then
	RESTART_SERVER_LIST="all"
fi

if [ "$GETOPT_NOCHATMSG" != "yes" ]; then
	./sendchatmsg.sh -dc $DC "[restartenv.sh] restarting $RESTART_SERVER_LIST..."
fi

./stopenv.sh -nomsg -dc $DC $SRVNAME_LIST
if [ $? -ne 0 ]; then
	echo "restartenv.sh: stopenv.sh failed. Exiting"
	exit 1
fi

./startenv.sh -nomsg -dc $DC $SRVNAME_LIST
if [ $? -ne 0 ]; then
	echo "restartenv.sh: startenv.sh failed. Exiting"
	exit 1
fi

if [ "$GETOPT_NOCHATMSG" != "yes" ]; then
	./sendchatmsg.sh -dc $DC "[restartenv.sh] done."
fi

echo restartenv.sh: SUCCESSFULLY DONE.
