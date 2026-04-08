#!/bin/bash
function echoY
{
    FLAG=$1
    shift
    echo -e "\033[38;5;148m$FLAG\033[39m$@"
}

function echoG
{
    FLAG=$1
    shift
    echo -e "\033[38;5;71m$FLAG\033[39m$@"
}

function echoR
{
    FLAG=$1
    shift
    echo -e "\033[38;5;203m$FLAG\033[39m$@"
}

function check_root
{
    local INST_USER=`id -u`
    if [ $INST_USER != 0 ] ; then
        echoR "Sorry, only the root user can install."
        echo
        exit 1
    fi
}

function newClient() {

	CLIENTEXISTS=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt  | grep "^V" | grep -c -E "/CN=$CLIENT\$")
	if [[ $CLIENTEXISTS == '1' ]]; then
		echoR ""
		echoR "The specified client CN was already found in easy-rsa, please choose another name."
		exit
	else
		cd /etc/openvpn/server/easy-rsa/ || return
			EASYRSA_CERT_EXPIRE=3650 ./easyrsa build-client-full "$CLIENT" nopass
		echoY "Client $CLIENT added."
	fi

		homeDir="/certs"

	# Generates the custom client.ovpn
	cp /etc/openvpn/client-template.txt "$homeDir/$CLIENT.ovpn"
	{
		echo "<ca>"
		cat "/etc/openvpn/server/easy-rsa/pki/ca.crt"
		echo "</ca>"

		echo "<cert>"
		sed -ne '/BEGIN CERTIFICATE/,$ p' /etc/openvpn/server/easy-rsa/pki/issued/"$CLIENT".crt
		echo "</cert>"

		echo "<key>"
		cat "/etc/openvpn/server/easy-rsa/pki/private/$CLIENT.key"
		echo "</key>"
    echo "<tls-crypt>"
	  sed -ne '/BEGIN OpenVPN Static key/,$ p' /etc/openvpn/server/tc.key
	  echo "</tls-crypt>"
	} >>"$homeDir/$CLIENT.ovpn"

	echoG ""
	echoG "The configuration file has been written to $homeDir/$CLIENT.ovpn."
	echoG "Download the .ovpn file and import it in your OpenVPN client."

	exit 0
}

function check_value_follow
{
    FOLLOWPARAM=$1
    local PARAM=$1
    local KEYWORD=$2

    #test if first letter is - or not.
    if [ "x$1" = "x-n" ] || [ "x$1" = "x-e" ] || [ "x$1" = "x-E" ] ; then
        FOLLOWPARAM=
    else
        local PARAMCHAR=`echo $1 | awk '{print substr($0,1,1)}'`
        if [ "x$PARAMCHAR" = "x-" ] ; then
            FOLLOWPARAM=
        fi
    fi

    if [ "x$FOLLOWPARAM" = "x" ] ; then
        if [ "x$KEYWORD" != "x" ] ; then
            echoR "Error: '$PARAM' is not a valid '$KEYWORD', please check and try again."
            usage
            exit 1
        fi
    fi
}

function usage
{
    echoG " --vpnuser USERNAME             " "To set the vpn name to be used by OpenVPN Server."
}

while [ "$1" == "" ] ; do
    case $1 in
        * )                         usage
                                    exit 0
                                    ;;
    esac
    shift
done

while [ "$1" != "" ] ; do
    case $1 in

             --vpnuser )            check_value_follow "$2" "Vpn name of user"
                                    shift
                                    CLIENT=$1
                                    ;;

        * )                         usage
                                    exit 0
                                    ;;
    esac
    shift
done
check_root
newClient
