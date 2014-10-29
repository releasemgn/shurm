#!/bin/bash

# Restart UAT

###########################################################
# execute
cd `dirname $0`
AUTO_DIR=`pwd`
cd /release-mgn
AUTO_DEPLOYMENT_HOME=`pwd`

. .bashrc
. .bash_profile

echo refreshuat.sh: started, processid=$$... > $AUTO_DIR/refreshuat.log

# clear old
cd $MYP_DEPLOYMENT_HOME/deployment/uat
./dropredist.sh	>> $AUTO_DIR/refreshuat.log

# restart env
cd $MYP_DEPLOYMENT_HOME/deployment/uat
./sendchatmsg.sh "[refreshuat.sh] start refresh env ..."
./stopenv.sh -nomsg >> $AUTO_DIR/refreshuat.log
./svnrestoreconfig.sh -nomsg >> $AUTO_DIR/refreshuat.log
./startenv.sh -nomsg >> $AUTO_DIR/refreshuat.log

# save configuration files in svn
./svnsaveconfig.sh >> $AUTO_DIR/refreshuat.log
./sendchatmsg.sh "[refreshuat.sh] refresh done."

echo refreshuat.sh: finished >> $AUTO_DIR/refreshuat.log
