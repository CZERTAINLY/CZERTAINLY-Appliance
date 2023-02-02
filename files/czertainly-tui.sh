#!/bin/bash

# inspiration from: https://linuxcommand.org/lc3_adv_dialog.php
#                   https://www.foxinfotech.in/2019/04/linux-dialog-examples.html


# Define the dialog exit status codes
: ${DIALOG_OK=0}
: ${DIALOG_CANCEL=1}
: ${DIALOG_HELP=2}
: ${DIALOG_EXTRA=3}
: ${DIALOG_ITEM_HELP=4}
: ${DIALOG_ESC=255}

applianceVersion='?.?.?'
if [ -f /etc/czertainly_appliance_version ]
then
    applianceVersion=`cat /etc/czertainly_appliance_version`
fi
applianceIP=`ip address show dev eth0 | grep -w inet | awk '{print $2}' | sed "s/\/.*//"`
umask 002

export CZERTAINLY_TUI="ACTIVE"

backTitle="CZERTAINLY Appliance ($applianceVersion; $applianceIP)"
mainMenu=(
    'hostname'     "Configure hostname"
    "network"      "Configure HTTP proxy"
    'ingressTLS'   "Configure ingress TLS certificates"
    'trustedCA'    "Configure custom trusted certificates"
    'database'     "Configure database"
    '3keyRepo'     "Configure 3Key.Company Docker repository access credentials"
    'install'      "Install CZERTAINLY"
#    'status'       "Show CZERTAINLY status"
    'advanced'     "Advanced options"
    'exit'         "Exit CZERTAINLY manager"
)
advancedMenu=(
#    'testNetwork'        'Verify network access',
#    'installPSQL'        'Install only postgress',
#    'verifyPSQL'         'Verify access to postgress database'
#    'installHelm'        'Install only helm utility'
#    'installRKE2'        "Install only RKE2 - Rancher\'s next-generation Kubernetes distribution"
#    'verifyRKE2'         'Verify kubernetes',
#    'installC'           'Install only CZERTAINLY'
    'removeC'            'Remove CZERTAINLY'
    'remove'             'Remove RKE2 & CZERTAINLY'
    'shell'              'Enter system shell'
    'reboot'             'Reboot system'
    'shutdown'           'Shutdown system'
    'exit'               "Exit advanced menu"
)
proxySettings='/etc/ansible/vars/proxy.yml'
dockerSettings='/etc/ansible/vars/docker.yml'
databaseSettings='/etc/ansible/vars/database.yml'
ingressSettings='/etc/ansible/vars/ingress.yml'
trustedCASettings='/etc/ansible/vars/trustedCA.yml'
rkeUninstall='/usr/local/bin/rke2-uninstall.sh'
kubectl='/var/lib/rancher/rke2/bin/kubectl'

maxRemoveWait=360

tmpF=`mktemp /tmp/czertainly-manager.XXXXXX`
#trap "rm $tmpF 2>/dev/null" 0 1 2 5 15

# Rows and COLS are exact terminal size
read Rows COLS < <(stty size)
# eRows and eRows are efective terminal size - subctracting some
# values to get nice output.
eRows=$[$Rows-3]
eCOLS=$[$COLS-8]

# Add spaces to left of string to make it centered on actual terminal
# size.
center_text () {
    len=`echo -n "$1" | wc -c`
    printf "%*s\n" $(( ($len + $COLS) / 2 )) "$1"
}

# Calculate size of menu.
#
# Needed size is counted as number of menu options with addition of 3
# lines on top and 4 on bottom. If needed size is higher than avaialbe
# efective terminal size than efective size of termial is used.
max_menu_rows() {
    array=("$@")

    needed=$[${#array[@]}/2+3+4]

    if [ $needed -gt $eRows ]
    then
	echo $eRows
    else
	echo $needed
    fi
}

allParametersRequired() {
    dialog --backtitle "$backTitleCentered" --title 'Error[!]' --msgbox "All parameters are required." 10 50
}

errorMessage() {
    dialog --backtitle "$backTitleCentered" --title 'Error[!]' --msgbox "$1" 10 50
}

infoMessage() {
    dialog --backtitle "$backTitleCentered" --title 'Info[!]' --msgbox "$1" 10 50
}

infoText() {
    temp=`mktemp /tmp/czertainly-manager.textbox.XXXXXX`
    echo "$1" > $temp
    dialog --backtitle "$backTitleCentered" --title 'Info' --textbox "$temp" $eRows $eCOLS
    rm $temp
}

confirm() {
    text=$1

    dialog --backtitle "$backTitleCentered" --title "Confirmation" --yesno "$text" 10 50
    return_value=$?

    if [ $return_value == $DIALOG_OK ]
    then
	return 0
    else
	return 1
    fi
}

removeALL() {
    p=$FUNCNAME

    clear -x
    if [ -e $rkeUninstall ]
    then
	logger "$p: calling $rkeUninstall"
	sudo $rkeUninstall
	echo ""
	echo "RKE2 & CZERTAINLY removed, press enter key to return to menu"
	read
    else
	echo "RKE2 not present ($rkeUninstall), press enter key to return to menu"
	read
    fi
}

removeCZERTAINLY() {
    p=$FUNCNAME

    clear -x
    if [ -e $kubectl ]
    then
	cmd="$kubectl delete ns czertainly"
	logger "$p: calling $cmd"
	sudo $cmd
	echo ""
	echo "CZERTAINLY removed. Waiting for kubernetes to complete cleaning."

	sudo /usr/bin/rm /root/install/docker-secret.yaml
	sudo /usr/bin/rm /root/install/czertainly-values.yaml
	sudo /usr/bin/rm /root/install/czertainly-values.local.yaml

	cleaned=0
	start=`date "+%s"`
	while true
	do
	    if `sudo $kubectl -n czertainly get all 2>&1 | grep 'No resources found' >/dev/null 2>&1`
	    then
		cleaned=0
		logger "$p: czertainly name space deleted"
		echo "DONE"
		break
	    else
		diff=$[`date "+%s"`-$start]
		if [ $diff -gt $maxRemoveWait ]
		then
		    msg="waiting take to long!"
		    logger "$p: $msg"
		    echo "$msg"
		    echo ""
		    sudo $kubectl -n czertainly get all
		    echo ""
		    echo "Kubernetes failled to remove czertaily namespace."
		    break
		else
		    logger "$p: waiting ${diff}s ..."
		    echo "waiting ${diff}s ..."
		    sleep 10
		fi
	    fi
	done
	echo ""
	echo "Press enter key to return to menu."
	read
    else
	echo "$kubectl is missing. Is RKE2 installed?"
	echo ""
	echo "Press enter key to return to menu."
	read
    fi
}

backTitleCentered=`center_text "$backTitle"`;

advanced() {
    p=$FUNCNAME
    # duplicate (make a backup copy of) file descriptor 1 on descriptor 3
    exec 3>&1

    advancedMenuRows=`max_menu_rows "${advancedMenu[@]}"`
    logger "$p: menuRows = $advancedMenuRows";
    result=$(dialog --backtitle "$backTitleCentered" \
		    --ok-label 'Select' \
		    --no-cancel \
		    --menu "advanced menu" $advancedMenuRows $eCOLS $advancedMenuRows \
		    "${advancedMenu[@]}" 2>&1 1>&3)
    # get dialog's exit status
    return_value=$?
    # close file descriptor 3
    exec 3>&-

    logger "$p: return_value=$return_value, result='$result'"

    if [ $return_value != $DIALOG_OK ]
    then
	logger "advanced_menu: not OK => terminating"
	exit 1
    fi

    case $result in
	'exit')
	    logger "$p: exit"
	    echo "exit"
	    return 1
	    ;;
	'remove')
	    if confirm "Remove RKE2 (kubernetes) including CZERTAINLY? Database will remain untouched."
	    then
		logger "$p: complete remove confirmed"
		removeALL
	    else
		logger "$p: complete remove canceled"
	    fi
	    ;;
	'removeC')
	    if confirm "Remove CZERTAINLY installation? Database will remain untouched."
	    then
		logger "$p: complete remove confirmed"
		removeCZERTAINLY
	    else
		logger "$p: complete remove canceled"
	    fi
	    ;;
	'shell')
	    clear -x
	    echo "to exit from shell and return into menu type 'exit'"
	    /bin/bash
	    echo "press enter key to return into menu"
	    read
	    ;;
	'reboot')
	    clear -x
	    echo "rebooting"
	    sudo /sbin/shutdown -r now
	    sleep 1000
	    ;;
	'shutdown')
	    clear -x
	    echo "stoping system"
	    sudo /sbin/shutdown -h now
	    sleep 1000;
	    ;;
	*)
	    dialog --backtitle "$backTitleCentered" --title " not implemented " --msgbox "Option \"$result\" is not implemented." 8 $eCOLS
	    logger "$p: result=$result is not implemented";
	    ;;
    esac

    return 0
};

network() {
    maxLen=120
    maxInputLen=$[$eCOLS-20]
    p=$FUNCNAME
    settings=$proxySettings

    httpProxy=`grep < $settings '^ *http: ' | sed "s/^ *http: *//"`
    httpsProxy=`grep < $settings '^ *https: ' | sed "s/^ *https: *//"`
    ftpProxy=`grep < $settings '^ *ftp: ' | sed "s/^ *ftp: *//"`
    ftpsProxy=`grep < $settings '^ *ftps: ' | sed "s/^ *ftps: *//"`
    noProxy=`grep < $settings -A 1000 '^ *dont_use_for:'| grep '^ * -' | sed "s/^ *- *//" | tr "\n" "," | sed "s/, *$//"`

    dialog --backtitle "$backTitleCentered" --title " HTTP proxy " \
	   --form "Provide parameters of proxy server required for Internet access" 15 $eCOLS 5 \
	   "HTTP_PROXY:"  1 2 "$httpProxy"  1 14 $maxInputLen $maxLen \
	   "HTTPS_PROXY:" 2 1 "$httpsProxy" 2 14 $maxInputLen $maxLen \
	   "FTP_PROXY:"   3 3 "$ftpProxy"   3 14 $maxInputLen $maxLen \
	   "FTPS_PROXY:"  4 2 "$ftpsProxy"  4 14 $maxInputLen $maxLen \
	   "NO_PROXY:"    5 4 "$noProxy"    5 14 $maxInputLen $maxLen \
	   2>$tmpF
    # get dialog's exit status
    return_value=$?

    if [ $return_value != $DIALOG_OK ]
    then
	logger "$p: dialog not OK => returing without any change"
	return 1
    fi

    cat $tmpF | sed "s/ //gm" | {
	read -r _httpProxy
	read -r _httpsProxy
	read -r _ftpProxy
	read -r _ftpsProxy
	read -r _noProxy

	lines=`cat $tmpF | sed "s/ //gm" | grep -v '^$' | wc -l`

	logger "$p: httpProxy  '$httpProxy' => '$_httpProxy'"
	logger "$p: httpsProxy '$httpsProxy' => '$_httpsProxy'"
	logger "$p: ftpProxy   '$ftpProxy' => '$_ftpProxy'"
	logger "$p: ftpsProxy  '$ftpsProxy' => '$_ftpsProxy'"
	logger "$p: noProxy    '$noProxy' => '$_noProxy'"

	newSettings=`mktemp /tmp/czertainly-manager.proxy.XXXXXX`

	if [ $lines -gt 0 ]
	then
	    echo "---
proxy:" > $newSettings
	    [ "$_httpProxy" != '' ] && echo "  http: $_httpProxy" >> $newSettings
	    [ "$_httpsProxy" != '' ] && echo "  https: $_httpsProxy" >> $newSettings
	    [ "$_ftpProxy" != '' ] && echo "  ftp: $_ftpProxy" >> $newSettings
	    [ "$_ftpsProxy" != '' ] && echo "  ftps: $_ftpsProxy" >> $newSettings
	    if [ "$_noProxy" != '' ]
	    then
		OFS=$IFS
		IFS=','
		echo "  dont_use_for:" >> $newSettings
		read -ra no <<< "$_noProxy"
		for i in "${no[@]}"; do
		    echo "    - $i" >> $newSettings
		done
		IFS=$OFS
	    fi

	    if `diff $newSettings $settings >/dev/null 2>&1`
	    then
		logger "$p: nothing changed"
		rm $newSettings
	    else
		cp $newSettings $settings
		rm $newSettings
		logger "$p: settings changed $settings rewritten"
	    fi
	else
	    logger "$p: all parameters are empty - zeroizing $settings"
	    cp /dev/null $settings
	fi
    }
}

database() {
    maxLen=120
    maxInputLen=$[$eCOLS-20]
    p=$FUNCNAME
    settings=$databaseSettings

    username=`grep < $settings '^ *username: ' | sed "s/^ *username: *//"`
    password=`grep < $settings '^ *password: ' | sed "s/^ *password: *//"`
    database=`grep < $settings '^ *database: ' | sed "s/^ *database: *//"`

    dialog --backtitle "$backTitleCentered" --title " local PostgreSQL " \
	   --form "Parameters of PostgreSQL running on appliance" 10 $eCOLS 3 \
	   "username:"  1 1 "$username" 1 14 $maxInputLen $maxLen \
	   "password:"  2 1 "$password" 2 14 $maxInputLen $maxLen \
	   "database:"  3 1 "$database" 3 14 $maxInputLen $maxLen \
	   2>$tmpF
    # get dialog's exit status
    return_value=$?

    if [ $return_value != $DIALOG_OK ]
    then
	logger "$p: dialog not OK => returing without any change"
	return 1
    fi

    cat $tmpF | sed "s/ //gm" | {
	read -r _username
	read -r _password
	read -r _database

	lines=`cat $tmpF | sed "s/ //gm" | grep -v '^$' | wc -l`

	logger "$p: username  '$username' => '$_username'"
	logger "$p: password  '$password' => '$_password'"
	logger "$p: database  '$database' => '$_database'"

	newSettings=`mktemp /tmp/czertainly-manager.database.XXXXXX`

	if [ $lines -eq 3 ]
	then
	    echo "---
postgres:" > $newSettings
	    [ "$_username" != '' ] && echo "  username: $_username" >> $newSettings
	    [ "$_password" != '' ] && echo "  password: $_password" >> $newSettings
	    [ "$_database" != '' ] && echo "  database: $_database" >> $newSettings

	    if `diff $newSettings $settings >/dev/null 2>&1`
	    then
		logger "$p: nothing changed"
		rm $newSettings
	    else
		cp $newSettings $settings
		rm $newSettings
		logger "$p: settings changed $settings rewritten"
	    fi
	else
	    logger "$p: some parameters are missing - refusing to continue"
	    allParametersRequired
	fi
    }
}

testCertificateKey() {
    cert=$1
    key=$2
    local p=$FUNCNAME

    if [ ! -e $cert ]
    then
	emsg="$cert doesn't exists"
	logger "$p: $emsg"
	echo $emsg
	return 1
    fi

    if [ ! -e $key ]
    then
	emsg="$key doesn't exists"
	logger "$p: $emsg"
	echo $emsg
	return 1
    fi

    if ! key_modulus=`openssl rsa -noout -modulus -in $key`
    then
	emsg="unable to get modulus of private key in $key"
	logger "$p: $emsg"
	echo $emsg
	return 1
    fi

    # with certificate it is more complicated, there might be more
    # than one folowing awk block prints modulus of all of them
    if awk -v cmd='openssl x509 -noout -modulus' '/BEGIN/{close(cmd)}; {print | cmd}' < $cert | grep "$key_modulus" > /dev/null
    then
	logger "$p: match"
	# modulus of the key found in modulus of certs in $cert
	return 0
    fi

    emsg="private key doesn't match provided certificate"
    logger "$p: $emsg"
    echo $emsg
    return 1
}

ingressTLS() {
    maxLen=120
    maxInputLen=$[$eCOLS-20]
    p=$FUNCNAME
    settings=$ingressSettings

    certificate=`grep < $settings '^ *certificate_file: ' | sed "s/^ *certificate_file: *//"`
    private_key=`grep < $settings '^ *private_key_file: ' | sed "s/^ *private_key_file: *//"`

    logger "$p: $settings";

    dialog --backtitle "$backTitleCentered" --title " TLS certificate " \
	   --form "Certificate & unencrypted private key for incoming HTTPS" 10 $eCOLS 3 \
	   "certificate:"  1 1 "$certificate" 1 14 $maxInputLen $maxLen \
	   "private key:"  2 1 "$private_key" 2 14 $maxInputLen $maxLen \
	   2>$tmpF
    # get dialog's exit status
    return_value=$?

    if [ $return_value != $DIALOG_OK ]
    then
	logger "$p: dialog not OK => returing without any change"
	return 1
    fi

    cat $tmpF | sed "s/ //gm" | {
	read -r _certificate
	read -r _private_key

	lines=`cat $tmpF | sed "s/ //gm" | grep -v '^$' | wc -l`

	logger "$p: certificate  '$certificate' => '$_certificate'"
	logger "$p: private_key  '$private_key' => '$_private_key'"

	newSettings=`mktemp /tmp/czertainly-manager.ingress.XXXXXX`

	if [ "$_certificate" != '' ] && [ "$_private_key" != '' ]
	then
	    if testRes=$(testCertificateKey "$_certificate" "$_private_key")
	    then
		echo "---
ingress:
  certificate_file: $_certificate
  private_key_file: $_private_key
" >> $newSettings

		if `diff $newSettings $settings >/dev/null 2>&1`
		then
		    logger "$p: nothing changed"
		    rm $newSettings
		else
		    cp $newSettings $settings
		    rm $newSettings
		    logger "$p: settings changed $settings rewritten"
		fi
	    else
		# testCertificateNotOK
		logger "$p: test not OK $testRes";
		errorMessage "$testRes"
	    fi
	else
	    logger "$p: all parameters are empty - zeroizing $settings"
	    cp /dev/null $settings
	fi
    }
}

testTrustedCAfile() {
    certs=$1
    local p=$FUNCNAME

    logger "$p: $certs";

    if [ ! -e $certs ]
    then
	emsg="unable to read $certs"
	logger "$p: $emsg"
	echo $emsg
	return 1
    fi

    cnt=`awk -v cmd='openssl x509 -noout -subject ' '/BEGIN/{close(cmd)}; {print | cmd}' < $certs | wc -l`

    if [ $cnt -gt 0 ]
    then
	logger "$p: found more than 0 certs ($cnt)"
	return 0
    fi

    emsg="unable to parse $certs";
    logger "$p: $emsg"
    echo $emsg
    return 1
}

trustedCA() {
    maxLen=120
    maxInputLen=$[$eCOLS-20]
    p=$FUNCNAME
    settings=$trustedCASettings

    trustedCA=`grep < $settings '^ *trustedCA_file: ' | sed "s/^ *trustedCA_file: *//"`

    dialog --backtitle "$backTitleCentered" --title " Trusted CAs " \
	   --form "Provide path to file with aditional trusted certificates" 10 $eCOLS 3 \
	   "trustedCAs:"  1 1 "$trustedCA" 1 14 $maxInputLen $maxLen \
	   2>$tmpF
    # get dialog's exit status
    return_value=$?

    if [ $return_value != $DIALOG_OK ]
    then
	logger "$p: dialog not OK => returing without any change"
	return 1
    fi

    cat $tmpF | sed "s/ //gm" | {
	read -r _trustedCA

	lines=`cat $tmpF | sed "s/ //gm" | grep -v '^$' | wc -l`

	logger "$p: trustedCA '$trustedCA' => '$_trustedCA'"

	newSettings=`mktemp /tmp/czertainly-manager.trustedCA.XXXXXX`

	if [ "$_trustedCA" != '' ]
	then
	    if testRes=$(testTrustedCAfile "$_trustedCA")
	    then
		echo "---
trustedCA_file: $_trustedCA
" >> $newSettings

		if `diff $newSettings $settings >/dev/null 2>&1`
		then
		    logger "$p: nothing changed"
		    rm $newSettings
		else
		    cp $newSettings $settings && rm $newSettings
		    logger "$p: settings changed $settings rewritten"
		fi
	    else
		# testCertificateNotOK
		logger "$p: test not OK $testRes";
		errorMessage "$testRes"
	    fi
	else
	    logger "$p: THE ONLY ONE parameter IS empty - zeroizing $settings"
	    cp /dev/null $settings
	fi
    }
}

changeHostname() {
    # https://wiki.debian.org/Hostname
    maxLen=120
    maxInputLen=$[$eCOLS-8]
    p=$FUNCNAME

    hostname=`hostname -f`

    dialog --backtitle "$backTitleCentered" --title " System hostname " \
	   --form "Provide fully qualifiled hostname" 10 $eCOLS 3 \
	   ""  1 1 "$hostname" 1 2 $maxInputLen $maxLen \
	   2>$tmpF
    # get dialog's exit status
    return_value=$?

    if [ $return_value != $DIALOG_OK ]
    then
	logger "$p: dialog not OK => returing without any change"
	return 1
    fi

    cat $tmpF | sed "s/ //gm" | {
	read -r _hostname

	lines=`cat $tmpF | sed "s/ //gm" | grep -v '^$' | wc -l`

	logger "$p: hostname '$hostname' => '$_hostname'"

	newSettings=`mktemp /tmp/czertainly-manager.trustedCA.XXXXXX`

	if [ "x$_hostname" != 'x' ] && [ "x$hostname" != "x$_hostname" ]
	then
	    if sudo /usr/local/bin/update-hostname.sh "$_hostname"
	    then
		infoMessage "After hostname change reboot is required. Press OK to reboot"
		clear -x
		echo "Rebooting..."
		sudo /sbin/shutdown -r now
		sleep 360
	    else
		logger "$p: update-hostname.sh failed"
		errorMessage "Hostname update failed."
	    fi
	else
	    logger "$p: hostname not changed"
	fi
    }
}

docker() {
    maxLen=120
    maxInputLen=$[$eCOLS-20-7]
    p=$FUNCNAME
    settings=$dockerSettings

    username=`grep < $settings '^ *username: ' | sed "s/^ *username: *//"`
    password=`grep < $settings '^ *password: ' | sed "s/^ *password: *//"`
    server=`grep < $settings '^ *server: ' | sed "s/^ *server: *//"`
    secret=`grep < $settings '^ *secret: ' | sed "s/^ *secret: *//"`
    email=`grep < $settings '^ *email: ' | sed "s/^ *email: *//"`
    version=`grep < $settings '^ *helm_chart_version: ' | sed "s/^ *helm_chart_version: *//"`

    dialog --backtitle "$backTitleCentered" --title " docker repository " \
	   --form "Parameters of Docker image repository" 10 $eCOLS 4 \
	   "server:"               1 13 "$server"   1 21 $maxInputLen $maxLen \
	   "CZERTAINLY version:"   2  1 "$version"  2 21 $maxInputLen $maxLen \
	   "username:"             3 11 "$username" 3 21 $maxInputLen $maxLen \
	   "password:"             4 11 "$password" 4 21 $maxInputLen $maxLen \
	   2>$tmpF
    # get dialog's exit status
    return_value=$?

    if [ $return_value != $DIALOG_OK ]
    then
	logger "$p: dialog not OK => returing without any change"
	return 1
    fi

    cat $tmpF | sed "s/ //gm" | {
	read -r _server
	read -r _version
	read -r _username
	read -r _password

	lines=`cat $tmpF | sed "s/ //gm" | grep -v '^$' | wc -l`

	logger "$p: username  '$username' => '$_username'"
	logger "$p: password  '$password' => '$_password'"
	logger "$p: server    '$server' => '$_server'"
	logger "$p: version   '$version' => '$_version'"

	newSettings=`mktemp /tmp/czertainly-manager.docker.XXXXXX`

	if [ $lines -eq 4 ]
	then
	    echo "---
docker:
  server: $_server
  helm_chart_version: $_version
  email: $email
  secret: $secret
  username: $_username
  password: $_password" >> $newSettings

	    if `diff $newSettings $settings >/dev/null 2>&1`
	    then
		logger "$p: nothing changed"
		rm $newSettings
	    else
		cp $newSettings $settings
		rm $newSettings
		logger "$p: settings changed $settings rewritten"
	    fi
	else
	    logger "$p: some parameters are missing - refusing to continue"
	    allParametersRequired
	fi
    }
}

execAnsible() {
    p=$FUNCNAME
    cmd=$1
    mode=$2

    logger "executing ansible: $cmd; in mode: $mode"
    clear -x
    echo "Executing Ansible:"
    echo "  $cmd"
    echo ""
    if [ "x$mode" == 'xfull-install' ]
    then
	echo "First installation takes about 10minutes, please be patient."
	echo ""
	echo ""
    fi

    $cmd
    result=$?

    if [ $result == 0 ]
    then
	echo "Ansible finished successfully, result code: $result"
    else
	echo "Ansible failed with error code: $result".
	echo ""
	echo "Error is very likely described in output above. If you need
to contact support please provide content of file /var/log/ansible.log"
	echo ""
    fi

    echo "press enter key to continue"
    read
}


main() {
    # duplicate (make a backup copy of) file descriptor 1 on descriptor 3
    exec 3>&1

    menuRows=`max_menu_rows "${mainMenu[@]}"`
    result=$(dialog --backtitle "$backTitleCentered" \
		    --ok-label 'Select' \
		    --no-cancel \
		    --menu "main menu" $menuRows $eCOLS $menuRows \
		    "${mainMenu[@]}" 2>&1 1>&3)
    # get dialog's exit status
    return_value=$?
    # close file descriptor 3
    exec 3>&-

    logger "main_menu: return_value=$return_value, result='$result'"

    if [ $return_value != $DIALOG_OK ]
    then
	logger "main_menu: not OK => terminating"
	exit 1
    fi

    case $result in
	'exit')
	    logger "main_menu: exit"
	    clear -x
	    exit 0
	    ;;
	'hostname')
	    changeHostname
	    ;;
	'network')
	    network
	    ;;
	'database')
	    database
	    ;;
	'3keyRepo')
	    docker
	    ;;
	'ingressTLS')
	    ingressTLS
	    ;;
	'trustedCA')
	    trustedCA
	    ;;
	'install')
	    execAnsible \
		"sudo /usr/bin/ansible-playbook /etc/ansible/playbooks/czertainly.yml" \
		"full-install"
	    ;;
	'advanced')
	    logger "main_menu: advanced";
	    while true;
	    do
		advanced
		aRet=$?
		logger "main_menu: advanced menu returned=$aRet"
		if [ $aRet == 1 ];
		then
		    logger "main_menu: exiting advanced menu";
		    break
		fi
	    done
	    ;;
	*)
	    dialog --backtitle "$backTitleCentered" --title " not implemented " --msgbox "Option \"$result\" is not implemented." 8 $eCOLS
	    logger "main_menu: result=$result is not implemented";
	    ;;
    esac
}

while true; do  main; done

