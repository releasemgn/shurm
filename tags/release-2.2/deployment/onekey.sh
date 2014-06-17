#!/bin/bash
# Copyright 2011-2014 vsavchik@gmail.com

P_CMD=$1
P_HOSTLOGIN=$2
P_KEYFILENEXT=$3
P_KEYACCESS=$4

if [ "$P_CMD" != "set" ] && [ "$P_CMD" != "add" ] && [ "$P_CMD" != "change" ] && [ "$P_CMD" != "delete" ]; then
	echo "onekey.sh: invalid command $P_CMD. Exiting"
	exit 1
fi

if [ "$P_KEYFILENEXT" = "" ]; then
	P_KEYFILENEXT=~/.ssh/id_dsa
fi

# replace with public key data
if [[ ! "$P_KEYFILENEXT" =~ \.pub$ ]]; then
	P_KEYFILENEXTPUB=$P_KEYFILENEXT.pub
	P_KEYFILENEXTPRV=$P_KEYFILENEXT
else
	P_KEYFILENEXTPUB=$P_KEYFILENEXT
	P_KEYFILENEXTPRV=${P_KEYACCESS%.pub}
fi

if [ ! -f "$P_KEYFILENEXTPRV" ] || [ ! -f "$P_KEYFILENEXTPUB" ]; then
	echo "onekey.sh: invalid public key file $P_KEYFILENEXT (should have private and public key files). Exiting"
	exit 1
fi

function f_execute_all() {
	# access using private key
	F_ACCESSOPTION=
	F_ACCESSMSG=
	if [ "$P_KEYACCESS" != "" ]; then
		if [[ "$P_KEYACCESS" =~ \.pub$ ]]; then
			P_KEYACCESS=${P_KEYACCESS%.pub}
		fi
	
		if [ ! -f "$P_KEYACCESS" ]; then
			echo "onekey.sh: invalid private key file $P_KEYACCESS. Exiting"
			exit 1
		fi

		F_ACCESSOPTION="-i $P_KEYACCESS"
		F_ACCESSMSG=" using access key $P_KEYACCESS"
	fi

	F_KEYOWNER=`cat $P_KEYFILENEXTPUB | cut -d " " -f3`
	F_KEYDATA=`cat $P_KEYFILENEXTPUB`

	# change
	F_AUTHFILE=.ssh/authorized_keys

	# handle user
	local F_HOSTLOGIN=$P_HOSTLOGIN
	if [ "$GETOPT_HOSTUSER" != "" ]; then
		F_HOSTLOGIN=${GETOPT_HOSTUSER}@${P_HOSTLOGIN#*@}
	elif [ "$GETOPT_ROOTUSER" = "yes" ]; then
		F_HOSTLOGIN=root@${P_HOSTLOGIN#*@}
	fi

	if [ "$P_CMD" = "change" ] || [ "$P_CMD" = "add" ]; then
		echo "$F_HOSTLOGIN: change key to $P_KEYFILENEXTPUB ($F_KEYOWNER) on $F_HOSTLOGIN$F_ACCESSMSG ..."
		ssh -n $F_ACCESSOPTION $F_HOSTLOGIN "if [ ! -f $F_AUTHFILE ]; then mkdir -p .ssh; chmod 700 .ssh; echo \"\" > $F_AUTHFILE; chmod 600 $F_AUTHFILE; fi; cat $F_AUTHFILE | grep -v $F_KEYOWNER\$ > $F_AUTHFILE.2; echo \"$F_KEYDATA\" >> $F_AUTHFILE.2; cp $F_AUTHFILE.2 $F_AUTHFILE; rm -rf $F_AUTHFILE.2;"
		if [ "$?" != "0" ]; then
			echo "onekey.sh: error executing key replacement. Exiting"
			exit 1
		fi

	elif [ "$P_CMD" = "set" ]; then
		echo "$F_HOSTLOGIN: set the only key to $P_KEYFILENEXTPUB ($F_KEYOWNER) on $F_HOSTLOGIN$F_ACCESSMSG ..."
		ssh -n $F_ACCESSOPTION $F_HOSTLOGIN "if [ ! -f $F_AUTHFILE ]; then mkdir -p .ssh; chmod 700 .ssh; echo \"\" > $F_AUTHFILE; chmod 600 $F_AUTHFILE; fi; echo \"$F_KEYDATA\" > $F_AUTHFILE"
		if [ "$?" != "0" ]; then
			echo "onekey.sh: error executing key set. Exiting"
			exit 1
		fi

	elif [ "$P_CMD" = "delete" ]; then
		echo "$F_HOSTLOGIN: delete key $P_KEYFILENEXTPUB ($F_KEYOWNER) on $F_HOSTLOGIN$F_ACCESSMSG ..."
		ssh -n $F_ACCESSOPTION $F_HOSTLOGIN "if [ ! -f $F_AUTHFILE ]; then mkdir -p .ssh; chmod 700 .ssh; echo \"\" > $F_AUTHFILE; chmod 600 $F_AUTHFILE; fi; cat $F_AUTHFILE | grep -v $F_KEYOWNER\$ > $F_AUTHFILE.2; cp $F_AUTHFILE.2 $F_AUTHFILE; rm -rf $F_AUTHFILE.2;"
		if [ "$?" != "0" ]; then
			echo "onekey.sh: error executing key delete. Exiting"
			exit 1
		fi
	fi

	if [ "$P_CMD" = "change" ] || [ "$P_CMD" = "set" ]; then
		# check
		ssh -n -i $P_KEYFILENEXTPRV -o PasswordAuthentication=no $F_HOSTLOGIN "echo change successfully completed"
		if [ "$?" != "0" ]; then
			echo "onekey.sh: error executing new key check. Exiting"
			exit 1
		fi
		echo "$F_HOSTLOGIN: new key successfully verified."
	fi
}

f_execute_all
