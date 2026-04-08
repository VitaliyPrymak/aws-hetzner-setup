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

function revokeClient() {
	cd /etc/openvpn/server/easy-rsa/ || return
	./easyrsa --batch revoke "$CLIENT"
	EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl
	rm -f "/certs/$CLIENT.ovpn"
	rm -f /etc/openvpn/crl.pem
	cp /etc/openvpn/server/easy-rsa/pki/crl.pem /etc/openvpn/server/crl.pem
	chmod 644 /etc/openvpn/server/crl.pem
	sed -i "/^$CLIENT,.*/d" /etc/openvpn/ipp.txt
	echoR ""
	echoR "Certificate for client $CLIENT revoked."
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

             --vpnuser )            check_value_follow "$2" "Vpn name of user too bee delete"
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
tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2
revokeClient
