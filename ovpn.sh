#!/bin/bash
#/bin/ovpn

ovpnConf=/etc/openvpn/ovpn.conf
version="1.1.6"

Has_sudo()
{
	if [ `whoami` != root ]; then
    return 1
    exit
  else
		return 0
	fi
}

Countdown()
{
	_time=$1
	while [ $_time -gt 0 ]; do
		printf "\r $_time seconds"
		_time=$(($_time - 1))
		sleep 1
	done
	printf "\n Done!"
	printf "\n"
}

Backup()
{
	if ! Has_sudo; then
		echo "$USER, please run ovpn with sudo or as root"
		exit
	fi

	backupDir=/etc/openvpn
	fileName=ovpn-manager-backup.tar
	tar cf $PWD/$fileName $backupDir
	echo "Backup is $PWD/$fileName"
	
}

Restore()
{
	if ! Has_sudo; then
		echo "$USER, please run ovpn with sudo or as root"
		exit
	fi

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

Log()
{
	# Example : 'Log "ERROR | ERROR MESSAGE"'
	_errorMessage=$1
	_date="[ $(date) ] |"
	_logFile=/var/log/ovpn.log
	_logFileLines=

	if [ -f $_logFile ]; then
		_logFileLines=$(wc -l $_logFile | cut -d " " -f 1)
	fi

	echo "$_date $_errorMessage" >> $_logFile
	echo "$_errorMessage"
	chown -f root:root $_logFile
	chmod -f 770 $_logFile

	if [ $_logFileLines -ge 1000 ]; then
		sed -i '1d' $_logFile
	fi
}

Set_Service()
{
	# Example :  'Set_Service enable|disable|start|stop|restart|status <servcie>'
	_operation=$1
	_service=$2
	_serviceStorageDir=
	_serviceActiveDir=
	_isSystemd=false
	_isRunit=false

	if [ -x "$(command -v sv)" ]; then
		_isRunit=true
		if [[ $_service == *".service" ]]; then
			_service=$(echo $_service | cut -d "." -f 1)
		fi
		if [[ $_service == *"@"* ]]; then
			_service=$(echo $_service | cut -d "@" -f 1)
		fi
	elif [ -x "$(command -v systemctl)" ]; then
		_isSystemd=true
	else
		Log "ERROR | NO INIT SYSTEM FOUND, EXITING!"
		exit
	fi

	if [ -d /etc/sv ]; then # Void Linux - Runit
		_serviceStorageDir=/etc/sv
		_serviceActiveDir=/var/service/
	elif [ -d /etc/runit/sv ]; then # Artix Linux - Runit
		_serviceStorageDir=/etc/runit/sv
		_serviceActiveDir=/run/runit/service
	fi

	case "$_operation" in
		enable)
			if $_isRunit; then
				unlink $_serviceActiveDir/$_service
				rm -f $_serviceStorageDir/$_service/down
				ln -s $_serviceStorageDir/$_service $_serviceActiveDir/
			elif $_isSystemd; then
				systemctl enable $_service
			fi ;;
		disable)
			if $_isRunit; then
				touch $_serviceActiveDir/$_service/down
			elif $_isSystemd; then
				systemctl disable $_service
			fi ;;
		start)
			if $_isRunit; then
				sv up $_service
			elif $_isSystemd; then
				systemctl start $_service
			fi ;;
		stop)
			if $_isRunit; then
				sv down $_service
			elif $_isSystemd; then
				systemctl stop $_service
			fi ;;
		restart)
			if $_isRunit; then
				sv down $_service
				sv up $_service
			elif $_isSystemd; then
				systemctl restart $_service
			fi ;;
		status)
			if $_isRunit; then
				sv check $_service
				tail /var/log/openvpn.log
				tail /var/log/ovpn.log
			elif $_isSystemd; then
				systemctl status $_service
			fi ;;
	esac
}

Fix_Permissions()
{
	if ! Has_sudo; then
		echo "$USER, please run ovpn with sudo or as root"
		exit
	fi

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
		Log "ERROR | NO openvpn USER FOUND"
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
		varIsPresent=true
	else
		varIsPresent=false
	fi
	
	if [[ ! -n $varToChange ]] || [[ ! -n $newVarContent ]]; then
		echo "Function Change_variable requires 2 parameters: varToChange newVarContent"
		exit
	elif [[ $varType == "array" ]]; then
		sed -i -e "s|$varToChange=.*|$varToChange=\($newVarContent\)|g" $sourceFile
	else
		if $varIsPresent; then
			sed -i -e "s|$varToChange=.*|$varToChange=$newVarContent|g" $sourceFile
		else
			echo "$varToChange=$newVarContent" >> $sourceFile
		fi
	fi
}

Killswitch()
{
	if ! Has_sudo; then
		echo "$USER, please run ovpn with sudo or as root"
		exit
	fi

	onOrOff=$1

	if [[ $onOrOff == "on" ]]; then
		echo "Enabling Kill Switch..."
		Set_Service enable killswitch.service
		Set_Service start killswitch.service
		echo "...DONE!"
	elif [[ $onOrOff == "off" ]]; then
		echo "Disabling Kill Switch..."
		Set_Service disable killswitch.service
		Set_Service stop killswitch.service
		Change_variable killSwitchEnabled false bool $ovpnConf
		echo "...DONE!"
	fi
}

Killswitch_Enable()
{
	if ! Has_sudo; then
		echo "$USER, please run ovpn with sudo or as root"
		exit
	fi

	source $ovpnConf
	echo "Enabling Kill Switch..."
	Change_variable killSwitchEnabled true bool $ovpnConf
	Set_Service enable ufw
	Set_Service start ufw
	ufw enable
	ufw default deny outgoing
	ufw default deny incoming
	vpnConfFile=/etc/openvpn/client/$defaultVPNConnection.conf
	VPN_IP=$(awk '/remote / {print $2}' $vpnConfFile)
	VPN_PORT=$(awk '/remote / {print $3}' $vpnConfFile)
	VPN_PORT=$(Clean_Number $VPN_PORT)
	VPN_PORT_PROTO=$(awk '/proto/ {print $2}' $vpnConfFile)
	VPN_PORT_PROTO=$(Clean_Letters "$VPN_PORT_PROTO")
	VPN_INTERFACE=$(ifconfig | grep -o "tun"[0-9])
	echo "Looking for tun interface..."
	echo 'WARNING - If this hangs forever, OpenVPN may not be started...'
	
	_iteration=1
	while [[ ! -n $VPN_INTERFACE ]]; do
		VPN_INTERFACE=$(ifconfig | grep -o "tun"[0-9])
		sleep 2
		echo "...Connection attempt [$_iteration/10]"
		_iteration=$(($_iteration + 1))
		if [ $_iteration -ge 10 ]; then
			Log "WARNING | Restarting OpenVPN in 5 seconds | KILLSWITCH"
			sleep 5
			ovpn -r
			_iteration=1
			Log "WARNING | OpenVPN restarted due to failing to connect 10 times | KILLSWITCH"
		fi
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
		
		# ufw allow out from any to $VPN_IP
		# ufw allow in from any to $VPN_IP
		
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
		# systemctl restart openvpn-client@$defaultVPNConnection.service
		
		Log "STATUS | KILL SWITCH ENGAGED | KILLSWITCH"
		
	elif [ -x "$(command -v firewall-cmd)" ]; then 
		firewall-cmd --permanent --add-source=$VPN_IP
		firewall-cmd --reload
		Log "WARNING | FIREWALLD SUPPORT IS LIMITED, KILLSWITCH NOT SECURE ENOUGH"
	else
		Log "ERROR | FAILED TO ALLOW $VPN_IP! NO 'ufw' OR 'firewall-cmd' COMMAND FOUND!"
	fi
	
	while true; do
		_iteration=1
		infoIP=
		publicIP=
		cityIP=
		regionIP=
		countryIP=
		
		sleep 5
		
		isConnected=$(ping -c 1 -q ipinfo.io >&/dev/null; echo $?)
		if [[ $isConnected == "0" ]]; then
			isConnected=true
			# infoIP=$(curl -s ipinfo.io)
			infoIP=$(curl -s https://api.db-ip.com/v2/free/self/)
			publicIP=$(echo "$infoIP" | grep \"ip | awk -F'"' '{ print $4 }')
			cityIP=$(echo "$infoIP" | grep city | awk -F'"' '{ print $4 }')
			regionIP=$(echo "$infoIP" | grep continentName | awk -F'"' '{ print $4 }')
			countryIP=$(echo "$infoIP" | grep countryName | awk -F'"' '{ print $4 }')
			Log "STATUS | CONNECTED $publicIP $cityIP $regionIP $countryIP | KILLSWITCH"
		else
			isConnected=false
			Log "STATUS | DISCONNECTED | KILLSWITCH"
		fi
		
		while ! $isConnected; do
			_retriesLeft=$(( 5 - $_iteration ))
			echo "Retries left: $_retriesLeft"
			echo "Cannot connect to the internet."
			sleep 5
			_iteration=$(($_iteration + 1))
			if [ $_iteration -ge 5 ]; then
				echo "Restarting OpenVPN in 5 seconds"
				sleep 5
				ovpn -r
			fi
			
			sleep 2
			#publicIP=$(wget -qO- ipinfo.io/ip)
			isConnected=$(ping -c 1 -q ipinfo.io >&/dev/null; echo $?)
			if [[ $isConnected == "0" ]]; then
				isConnected=true
				Log "STATUS | CONNECTED $publicIP $cityIP $regionIP $countryIP | KILLSWITCH"
			else
				isConnected=false
				Log "STATUS | DISCONNECTED | KILLSWITCH"
			fi
		done
		
		source $ovpnConf
		vpnConfFile=/etc/openvpn/client/$defaultVPNConnection.conf
		VPN_IP=$(awk '/remote / {print $2}' $vpnConfFile)
		echo "----------------------------------"
		echo " ENTRY IP --> $VPN_IP"
		echo " EXIT IP  --> $publicIP"
		echo " REGION   --> $regionIP"
		echo " COUNTRY  --> $countryIP"
		echo " CITY     --> $cityIP"
		echo " Status check interval: 30 seconds"

		VPN_INTERFACE=$(ifconfig | grep -o "tun"[0-9])
		if [[ ! -n $VPN_INTERFACE ]]; then
			Log "ERROR | NO `tun` INTERFACE FOUND RESTARTING OpenVPN | KILLSWITCH"
			ovpn -r
		fi
		
		sleep 30
	done
}

Killswitch_Disable()
{
	if ! Has_sudo; then
		echo "$USER, please run ovpn with sudo or as root"
		exit
	fi

	ufw default allow outgoing
	ufw default allow incoming
	ufw reload
	echo
	echo "GETTING IP..."
	sleep 2
	# curl ip.changeip.com
	# wget -qO- ipinfo.io/ip
	publicIp=$(dig +short myip.opendns.com @resolver1.opendns.com)
	echo "Public IP --> $publicIP"
	Log "STATUS | KILL SWITCH DISENGAGED | KILLSWITCH"
	echo
}

Killswitch_Reload()
{
	if ! Has_sudo; then
		echo "$USER, please run ovpn with sudo or as root"
		exit
	fi

	Killswitch_Disable
	Killswitch_Enable
}

Import_ovpn()
{
	if ! Has_sudo; then
		echo "$USER, please run ovpn with sudo or as root"
		exit
	fi

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
	if ! Has_sudo; then
		echo "$USER, please run ovpn with sudo or as root"
		exit
	fi

	defaultVPNConnection=
	killSwitchEnabled=
	if [ -f $ovpnConf ]; then
		source $ovpnConf
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

		if (($defaultVPNConnectionNumber >= 1 && $defaultVPNConnectionNumber <= $maxNumber)); then
			Stop_vpn
			Disable_vpn
			sed "/$VPN_IP_OLD/d" /etc/ufw/user.rules > /tmp/user.rules
			mv -f /tmp/user.rules /etc/ufw/user.rules
			chown -f root:root /etc/ufw/user.rules
			defaultVPNConnection=$(cat $vpnListFile | head -n $defaultVPNConnectionNumber | tail -n 1)
			Log "STATUS | Default OpenVPN connection changed to $defaultVPNConnection"
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
			echo "VPN_IP_OLD=$VPN_IP" >> $ovpnConf
			# echo "VPN_PORT_OLD=$VPN_PORT" >> $ovpnConf
			# echo "VPN_PORT_PROTO_OLD=$VPN_PORT_PROTO" >> $ovpnConf

			ufw allow out from any to $VPN_IP
			ufw allow in from any to $VPN_IP
			ufw allow out to $VPN_IP port $VPN_PORT proto $VPN_PORT_PROTO
			ufw reload
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
	if ! Has_sudo; then
		echo "$USER, please run ovpn with sudo or as root"
		exit
	fi

	source $ovpnConf
	echo "Enabling OpenVPN..."
	Set_Service enable openvpn-client@$defaultVPNConnection.service
	Log "STATUS | OpenVPN Enabled on start-up"
	#if $killSwitchEnabled; then
		# echo 'CAUTION - Kill Switch is ENABLED, on next reboot, please run: "sudo ovpn -k off"'
		# echo "Kill Switch enabled on next system start"
		# systemctl enable killswitch.service
	#fi
}

Disable_vpn()
{
	if ! Has_sudo; then
		echo "$USER, please run ovpn with sudo or as root"
		exit
	fi

source $ovpnConf
	echo "Disabling OpenVPN..."
	Set_Service disable openvpn-client@$defaultVPNConnection.service
	if $killSwitchEnabled; then
		Log "WARNING | Kill Switch is enabled, but OpenVPN is disabled. Internet Connection not Possible"
		# echo 'CAUTION - Kill Switch is ENABLED, on next reboot, please run: "sudo ovpn -k off"'
		# echo "CAUTION - Disabling killswitch on next system start up."
		# systemctl disable killswitch.service
	fi
	Log "STATUS | OpenVPN Disabled on start-up"
}

Start_vpn()
{
	if ! Has_sudo; then
		echo "$USER, please run ovpn with sudo or as root"
		exit
	fi

	source $ovpnConf
	echo "Starting OpenVPN..."
	Set_Service start openvpn-client@$defaultVPNConnection.service
	#if $killSwitchEnabled; then
		# echo "Starting Kill Switch, Kill Switch set to enable when OpenVPN starts"
		# Killswitch on
		# systemctl start killswitch.service
	#fi
	Log "STATUS | Started OpenVPN"
}

Stop_vpn()
{
	if ! Has_sudo; then
		echo "$USER, please run ovpn with sudo or as root"
		exit
	fi

	source $ovpnConf
	echo "Stopping OpenVPN..."
	Set_Service stop openvpn-client@$defaultVPNConnection.service
	if $killSwitchEnabled; then
		Log "WARNING | Kill Switch is enabled, but OpenVPN has just stopped. Internet Connection not Possible"
		# echo "Stopping Kill Switch, Kill Switch set to enable when OpenVPN starts"
		# Killswitch off
		# systemctl stop killswitch.service
		# Change_variable killSwitchEnabled true bool $ovpnConf
	fi
	echo "...OpenVPN has stopped"
	Log "STATUS | Stopped OpenVPN"
}

Restart_vpn()
{
	if ! Has_sudo; then
		echo "$USER, please run ovpn with sudo or as root"
		exit
	fi
	
	source $ovpnConf
	echo "Restarting OpenVPN..."
	Set_Service restart openvpn-client@$defaultVPNConnection.service
	ufw reload
	#if $killSwitchEnabled; then
		# echo "Starting Kill Switch, Kill Switch set to enable when OpenVPN starts"
		# Killswitch on
		# systemctl enable killswitch.service
		# systemctl restart killswitch.service
	#fi
	echo "...OpenVPN has restarted"
	Log "STATUS | Restarted OpenVPN"
}

Status_vpn()
{
	if ! Has_sudo; then
		echo "$USER, please run ovpn with sudo or as root"
		exit
	fi
	
	source $ovpnConf
	Set_Service status openvpn-client@$defaultVPNConnection.service
	echo
	echo
	Set_Service status killswitch.service
}

View_logs()
{
	if ! Has_sudo; then
		echo "$USER, please run ovpn with sudo or as root"
		exit
	fi

	echo "OVPN - Manager logs are located at /var/log/ovpn.log"
	tail /var/log/ovpn.log
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
-v Print the version OpenVPN Manager
-b Backup OpenVPN Manager Configurations
-rb [backup.tar] Restore OpenVPN Manager Configurations
-l View logs
-h Display this help menu

Kill Switch Behavior:
- The Kill Switch is manually turned on or off. Once enabled, if the connection
to your OpenVPN server is lost, there will be no connection to the internet.
However, when the Kill Switch is enabled, and there is no connection to the internet,
The Kill Switch will restart the OpenVPN systemd service to try and re-establish a conneciton.

See 'man ovpn' for more details.
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
			-i) while [[ ! $2 == *".ovpn" ]] && [[ ! $2 == "-"* ]]; do
						echo "$2 is not a .ovpn file..."
					done

					while [[ $2 == *".ovpn" ]]; do
						Import_ovpn $2
						shift
					done ;;
			-k) if [ ! -n $2 ]; then
						echo "Please input 'on' or 'off' for kill switch command"
					else
						Killswitch $2
					fi
					shift;;
			-f) Fix_Permissions ;;
			-b) Backup ;;
			-rb) Restore $2
					shift ;;
			-v) echo OpenVPN - Manager v$version;;
			--dev-function)
					$2
					shift ;;
			-l) View_logs ;;
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
