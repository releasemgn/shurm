P_SERVICE=$1
P_LOGFILE=$2
P_LOGRECORD="$3"
P_WAITTIME=$4

K=0
F_WAIT_DATE1=`date '+%s'`
F_WAIT_DATE2
while [ "$K" -lt $P_WAITTIME ]; do
        sleep 1

        SVCSTATUS="`/sbin/service $P_SERVICE status | grep already`"
        if [ "$SVCSTATUS" = "" ]; then
                echo STATUS=STOPPED
                exit 0
        fi;


	if [ -f $P_LOGFILE ]; then
        	GREPDATA=`grep "$P_LOGRECORD" $P_LOGFILE*`
	        if [ "$GREPDATA" != "" ]; then
        	        echo STATUS=OK
                	exit 1
	        fi;
	fi

	F_WAIT_DATE2=`date '+%s'`
       	KWAIT=$(expr $F_WAIT_DATE2 - $F_WAIT_DATE1)
done

echo STATUS=FAILED
