#!/bin/bash
#/bin/ovpn

ovpnConf=/etc/openvpn/ovpn.conf
version="1.0.8"

Has_sudo()
{
	if [ `whoami` != root ]; then
    echo "$USER, please run ovpn with sudo or as root"
    return 1
    exit
  else
		return 0
	fi
}

Backup()
{
	Has_sudo
	backupDir=/etc/openvpn
	fileName=ovpn-manager-backup.tar
	tar cf $PWD/$fileName $backupDir
	echo "Backup is $PWD/$fileName"
	
}

Restore()
{
	Has_sudo
	if [ ! -f $1 ]; then
		echo "ERROR- $1 IS NOT A FILE. TRY AGAIN!"
		exit
	fi
	
	importTar=$1
	tar xf $importTar -C /
	Fix_Permissions
	ovpn -e -s
	echo "Complete!"
}

Fix_Permissions()
{
	Has_sudo
	echo "SETTING UP PERMISSIONS FOR /etc/openvpn..."
	if id "openvpn" &>/dev/null; then
		chown -Rf openvpn:openvpn /etc/openvpn
		chmod -Rf 750 /etc/openvpn
		echo "...DONE!"
	elif id "nm-openvpn" &>/dev/null; then
		chown -Rf nm-openvpn:nm-openvpn /etc/openvpn
		chmod -Rf 750 /etc/openvpn
		echo "...DONE!"
	else
		echo "ERROR - NO openvpn USER FOUND!!!"
		echo "PLEASE SET UP YOUR OWN PERMISSIONS FOR"
		echo "/etc/openvpn"
	fi
}

Clean_Number()
{
	string=$1
	iteration=1
	stringCount=$(echo $string | wc -c)
	stringCount=$(($stringCount - 1))
	cleanedNumber=
	while [ $iteration -le $stringCount ]; do
		character=$(echo $string | cut -c $iteration)

		if [[ $character == [0-9] ]]; then
			cleanedNumber=$cleanedNumber$character
		fi
		let iteration=$(($iteration + 1))
	done

	echo $cleanedNumber
}

Clean_Letters()
{
	string="$1"
	iteration=1
	stringCount=$(echo $string | wc -c)
	stringCount=$(($stringCount - 1))
	letters="aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ"
	cleanedLetters=
	while [ $iteration -le $stringCount ]; do
		character=$(echo "$string" | cut -c $iteration)

		if [[ $letters == *"$character"* ]]; then
			cleanedLetters=$cleanedLetters$character
		fi
		let iteration=$(($iteration + 1))
	done

	echo $cleanedLetters
}

Change_variable()
{
	# Change_variable varToChange newVarContent VarType sourceFile ## Note varToChange does not have a $
	varToChange=$1
	newVarContent=$2
	varType=$3
	sourceFile=$4
	varIsPresent=$(grep -o "$varToChange" $sourceFile)
	
	if [[ "$varToChange" == "$varIsPresent" ]]; then
		let varIsPresent=true
	else
		let varIsPresent=false
	fi
	
	if [[ ! -n $varToChange ]] || [[ ! -n $newVarContent ]]; then
		echo "Function Change_variable requires 2 parameters: varToChange newVarContent"
		exit
	elif [[ $varType == "array" ]]; then
		sed -i -e "s|$varToChange=.*|$varToChange=\($newVarContent\)|g" $sourceFile
	else
		if $verIsPresent; then
			echo "$varToChange=$newVarContent" >> $sourceFile
		else
			sed -i -e "s|$varToChange=.*|$varToChange=$newVarContent|g" $sourceFile
		fi
	fi
}

Killswitch()
{
	Has_sudo
	source $ovpnConf
	onOrOff=$1

	if [[ $onOrOff == "on" ]]; then
			Change_variable killSwitchEnabled true bool $ovpnConf
			ufw default deny outgoing
			ufw default deny incoming
			vpnConfFile=/etc/openvpn/client/$defaultVPNConnection.conf
			VPN_IP=$(awk '/remote / {print $2}' $vpnConfFile)
			VPN_PORT=$(awk '/remote / {print $3}' $vpnConfFile)
			VPN_PORT=$(Clean_Number $VPN_PORT)
			VPN_PORT_PROTO=$(awk '/proto/ {print $2}' $vpnConfFile)
			VPN_PORT_PROTO=$(Clean_Letters "$VPN_PORT_PROTO")
			VPN_INTERFACE=$(ifconfig | grep -o "tun"[0-9])
			
			while [[ ! -n $VPN_INTERFACE ]]; do
				VPN_INTERFACE=$(ifconfig | grep -o "tun"[0-9])
				sleep .5
			done

		if [ -x "$(command -v ufw)" ]; then
			networkInterfaces=$(ip link show | grep ": <" | cut -d ":" -f 2 | sed "s| ||g")
			networkInterfaces=($networkInterfaces)
			for interface in "${networkInterfaces[@]}"; do
				if [[ $interface == "lo" ]] || [[ $interface == "tun"* ]]; then
					echo "Skipping restart for interface $interface"
				else
					echo "STOPPING ALL CONNECTIONS ON INTERFACE $interface..."
					ip link set $interface down
					ip link set $interface up
					echo "DONE!"
				fi
			done
			sleep 2
			
			echo "VPN_IP=$VPN_IP"
			echo "VPN_PORT=$VPN_PORT"
			echo "VPN_PORT_PROTO=$VPN_PORT_PROTO"
			echo "VPN_INTERFACE=$VPN_INTERFACE"
			ufw allow out on $VPN_INTERFACE from any to any
			ufw allow in on $VPN_INTERFACE from any to any
			
			ufw allow out to $VPN_IP port $VPN_PORT proto $VPN_PORT_PROTO
			
			#ufw allow out from any to $VPN_IP
			#ufw allow in from any to $VPN_IP
			
			ufw allow out from any to 10.0.0.0/24
			ufw allow out from any to 172.16.0.0/24
			ufw allow out from any to 192.168.0.0/24
			ufw allow out from any to 192.168.1.0/24
			ufw allow in from any to 10.0.0.0/24
			ufw allow in from any to 172.16.0.0/24
			ufw allow in from any to 192.168.0.0/24
			ufw allow in from any to 192.168.1.0/24
			
			ufw reload
			
			#ovpn -r
			systemctl restart openvpn-client@$defaultVPNConnection.service
			
			echo
			echo "KILL SWITCH ENGAGED!"
			echo "GETTING IP..."
			sleep 2
			dig +short myip.opendns.com @resolver1.opendns.com
			echo
			
		elif [ -x "$(command -v firewall-cmd)" ]; then 
			firewall-cmd --permanent --add-source=$VPN_IP
			firewall-cmd --reload
		else
			echo "FAILED TO ALLOW $VPN_IP! ERROR NO 'ufw' OR 'firewall-cmd' COMMAND FOUND!"
		fi
	elif [[ $onOrOff == "off" ]]; then
		Change_variable killSwitchEnabled false bool $ovpnConf
		ufw default allow outgoing
		ufw default allow incoming
		ufw reload
	fi
}

Import_ovpn()
{
	Has_sudo
	ovpnFile=
	warning=""
	if [ -f $1 ]; then
		ovpnFile=$1
	else
		ovpnFile=
	fi
	
	while [ ! -f $ovpnFile ]; do
		clear
		echo "$warning"
		read -p "Please enter the absolute path to your .ovpn file" ovpnFile
		if [ -f $ovpnFile ]; then
			let warning="ERROR- INPUTTED PATH DOES NOT LEAD TO A FILE - CTRL+C TO EXIT"
		fi
	done
	
	newOvpnFile=$(echo "$ovpnFile" | rev | cut -d "/" -f 1 | cut -d "." -f 2 | rev)
	cp -fv "$ovpnFile" /etc/openvpn/client/$newOvpnFile.conf
	Fix_Permissions
}

Change_Server()
{
	Has_sudo
	defaultVPNConnection=
	killSwitchEnabled=
	if [ -f $ovpnConf ]; then
		source $ovpnConf
		let defaultVPNConnection=$defaultVPNConnection
		let killSwitchEnabled=$killSwitchEnabled
		Stop_vpn
		Disable_vpn
	fi
	
	vpnList=$(ls -1 /etc/openvpn/client/)
	echo "$vpnList" > /tmp/vpnlist.txt
	sed -i -e "s|.conf||g" /tmp/vpnlist.txt
	vpnListFile=/tmp/vpnlist.txt
	maxNumber=$(echo "$vpnList" | wc -l)
	defaultVPNConnectionNumber=0
	warning=""
	
	while (( $defaultVPNConnectionNumber > $maxNumber )) || (( $defaultVPNConnectionNumber < 1 )); do
		clear
		echo "Current OpenVPN connection:"
		echo "$defaultVPNConnection"
		echo $warning
		echo "Available OpenVPN connection(s):"
		cat -n $vpnListFile
		echo "Please enter the number corresponding with"
		read -p "the version you want to install [1-$maxNumber] : " defaultVPNConnectionNumber
		defaultVPNConnection=$(cat $vpnListFile | head -n $defaultVPNConnectionNumber | tail -n 1)

		if (($defaultVPNConnectionNumber >= 1 && $defaultVPNConnectionNumber <= $maxNumber)); then
			rm -f $vpnListFile
			echo "defaultVPNConnection=$defaultVPNConnection" > $ovpnConf
			echo "killSwitchEnabled=$killSwitchEnabled" >> $ovpnConf
			Fix_Permissions

			vpnConfFile=/etc/openvpn/client/$defaultVPNConnection.conf
			VPN_IP=$(awk '/remote / {print $2}' $vpnConfFile)
			VPN_PORT=$(awk '/remote / {print $3}' $vpnConfFile)
			VPN_PORT=$(Clean_Number $VPN_PORT)
			VPN_PORT_PROTO=$(awk '/proto/ {print $2}' $vpnConfFile)
			VPN_PORT_PROTO=$(Clean_Letters "$VPN_PORT_PROTO")
			ufw allow out from any to $VPN_IP
			ufw allow in from any to $VPN_IP
			ufw allow out to $VPN_IP port $VPN_PORT proto $VPN_PORT_PROTO
			Enable_vpn
			Start_vpn
			
		else
			defaultVPNConnectionNumber=0
			let warning="ERROR Please select one of the numbers provided! - Or press CTRL+C to exit..."
		fi
	done
}

Enable_vpn()
{
	Has_sudo
	source $ovpnConf
	echo "Enabling OpenVPN..."
	systemctl enable openvpn-client@$defaultVPNConnection.service
	echo "...OpenVPN Enabled on start-up"
}

Disable_vpn()
{
	Has_sudo
	source $ovpnConf
	echo "Disabling OpenVPN..."
	systemctl disable openvpn-client@$defaultVPNConnection.service
	if $killSwitchEnabled; then
		echo 'CAUTION - Kill Switch is ENABLED, on next reboot, please run: "sudo ovpn -k off"'
	fi
	echo "...OpenVPN Disabled on start-up"
}

Start_vpn()
{
	Has_sudo
	source $ovpnConf
	echo "Starting OpenVPN..."
	systemctl start openvpn-client@$defaultVPNConnection.service
	if $killSwitchEnabled; then
		Killswitch on
	fi
	echo "...OpenVPN has started"
}

Stop_vpn()
{
	Has_sudo
	source $ovpnConf
	echo "Stopping OpenVPN..."
	systemctl stop openvpn-client@$defaultVPNConnection.service
	if $killSwitchEnabled; then
		Killswitch off
		Change_variable killSwitchEnabled true bool $ovpnConf
	fi
	echo "...OpenVPN has stopped"
}

Restart_vpn()
{
	Has_sudo
	source $ovpnConf
	echo "Restarting OpenVPN..."
	systemctl restart openvpn-client@$defaultVPNConnection.service
	ufw reload
	if $killSwitchEnabled; then
		Killswitch on
	fi
	echo "...OpenVPN has restarted"
}

Status_vpn()
{
	Has_sudo
	source $ovpnConf
	echo "OVPN - Manager:"
	echo "---------------"
	if $killSwitchEnabled; then
		echo
		echo "Kill Switch : ENABLED"
		echo
		echo "---------------"
	else
		echo
		echo "Kill Switch : DISABLED"
		echo
		echo "---------------"
	fi
	systemctl status openvpn-client@$defaultVPNConnection.service
}

Help()
{
	echo "
OpenVPN Manager v$version
-Created by Smiley McSmiles & XeN

Syntax: ovpn -[COMMAND] [OPTION]
COMMANDS:
-s Start OpenVPN
-S Stop OpenVPN
-t Status of OpenVPN
-e Enable OpenVPN
-d Disable OpenVPN
-r Restart OpenVPN
-c Change OpenVPN Connection
-i Import OpenVPN .ovpn file
-k [on/off] Enable or Disable the Killswitch
-f Fix OpenVPN permissions
-v Print OpenVPN Manager's Version
-b Backup OpenVPN Manager Configurations
-rb [backup.tar] Restore OpenVPN Manager Configurations
-h Display this help menu
"
}

# MAIN

if [[ -n "$1" ]]; then
	while [[ -n "$1" ]]; do
		case "$1" in
			-s) Start_vpn ;;
			-S) Stop_vpn ;;
			-t) Status_vpn ;;
			-e) Enable_vpn ;;
			-d) Disable_vpn ;;
			-r) Restart_vpn ;;
			-c) Change_Server ;;
			-i) if [ -f $2 ]; then
						Import_ovpn $2
						shift
					else
						Import_ovpn
					fi ;;
			-k) if [ ! -n $2 ]; then
						echo "Please input 'on' or 'off' for kill switch command"
					else
						Killswitch $2
					fi
					shift;;
			-f) Fix_Permissions ;;
			-b) Backup ;;
			-rb) Restore ;;
			-h) Help  ;;
			*) echo "Option $1 not recognized" 
				Help ;;
		esac
		shift
	done
else
	echo "No commands found."
	Help
	exit
fi

# END MAIN
