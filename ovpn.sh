#!/bin/bash
#/bin/ovpn

ovpnConf=/etc/openvpn/ovpn.conf
version="1.0.7"

Has_sudo()
{
	if [ `whoami` != root ]; then
    echo "$USER please run this script with sudo or as root"
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
	elif id "nm-openvpn" &>/dev/null; then
		chown -Rf nm-openvpn:nm-openvpn /etc/openvpn
		chmod -Rf 750 /etc/openvpn
	else
		echo "ERROR - NO openvpn USER FOUND!!!"
		echo "PLEASE SET UP YOUR OWN PERMISSIONS FOR"
		echo "/etc/openvpn"
	fi
}

Change_variable()
{
	# Change_variable varToChange newVarContent VarType sourceFile
	varToChange=$1
	newVarContent=$2
	varType=$3
	sourceFile=$4
	if [[ ! -n $varToChange ]] || [[ ! -n $newVarContent ]]; then
		echo "Function Change_variable requires 2 parameters: varToChange newVarContent"
		exit
	elif [[ $varType == "array" ]]; then
		sed -i -e "s|$varToChange=.*|$varToChange=\($newVarContent\)|g" $sourceFile
	else
		sed -i -e "s|$varToChange=.*|$varToChange=$newVarContent|g" $sourceFile
	fi
}

Killswitch()
{
	Has_sudo
	source $ovpnConf
	onOrOff=$1

	if [[ $onOrOff == "on" ]]; then
			ufw default deny outgoing
			ufw default deny incoming
			VPN_IP=$(cat /etc/openvpn/client/$defaultVPNConnection.conf | grep "remote " | cut -d " " -f 2)
			VPN_PORT=$(cat /etc/openvpn/client/$defaultVPNConnection.conf | grep "remote " | cut -d " " -f 3)
			VPN_PORT_PROTO=$(cat /etc/openvpn/client/$defaultVPNConnection.conf | grep "proto" | cut -d " " -f 2)
			VPN_INTERFACE=$(ifconfig | grep -o "tun"[09])
			
			while [[ ! -n $VPN_INTERFACE ]]; do
				VPN_INTERFACE=$(ifconfig | grep -o "tun"[09])
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
			
			ovpn -r
			
			echo
			echo "KILL SWITCH ENGAGED!"
			echo "GETTING IP..."
			sleep 2
			dig +short myip.opendns.com @resolver1.opendns.com
			
		elif [ -x "$(command -v firewall-cmd)" ]; then 
			firewall-cmd --permanent --add-source=$VPN_IP
			firewall-cmd --reload
		else
			echo "FAILED TO ALLOW $VPN_IP! ERROR NO 'ufw' OR 'firewall-cmd' COMMAND FOUND!"
		fi
	elif [[ $onOrOff == "off" ]]; then
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
	if [ -f $ovpnConf ]; then
		source $ovpnConf
		let defaultVPNConnection=$defaultVPNConnection
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

		#if [[ ! $defaultVPNConnectionNumber == [1-$maxNumber] ]]; then
		if (($defaultVPNConnectionNumber >= 1 && $defaultVPNConnectionNumber <= $maxNumber)); then
			defaultVPNConnectionNumber=0
			let warning="ERROR Please select one of the numbers provided! - Or press CTRL+C to exit..."
		else
			rm -f $vpnListFile
			echo "defaultVPNConnection=$defaultVPNConnection" > $ovpnConf
			Fix_Permissions
			VPN_IP=$(cat /etc/openvpn/client/$defaultVPNConnection.conf | grep "remote " | cut -d " " -f 2)
			ufw allow out from any to $VPN_IP
			ufw allow in from any to $VPN_IP
			Start_vpn
			Enable_vpn
		fi
	done
}

Enable_vpn()
{
	Has_sudo
	source $ovpnConf
	systemctl enable openvpn-client@$defaultVPNConnection.service
}

Disable_vpn()
{
	Has_sudo
	source $ovpnConf
	systemctl disable openvpn-client@$defaultVPNConnection.service
}

Start_vpn()
{
	Has_sudo
	source $ovpnConf
	systemctl start openvpn-client@$defaultVPNConnection.service
}

Stop_vpn()
{
	Has_sudo
	source $ovpnConf
	systemctl stop openvpn-client@$defaultVPNConnection.service
}

Restart_vpn()
{
	Has_sudo
	source $ovpnConf
	systemctl restart openvpn-client@$defaultVPNConnection.service
	ufw reload
}

Status_vpn()
{
	Has_sudo
	source $ovpnConf
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
