#!/bin/bash

Has_sudo()
{
	if [ `whoami` != root ]; then
    echo Please run this script as root or using sudo
    return 1
    exit
  else
  		return 0
	fi
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
	echo "$_date $_errorMessage"
	chown -f root:root $_logFile
	chmod -f 770 $_logFile

	if [ $_logFileLines -ge 1000 ]; then
		sed -i '1d' $_logFile
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

Fix_Permissions()
{
	Has_sudo
	if id "openvpn" &>/dev/null; then
		chown -Rfv openvpn:openvpn /etc/openvpn
		chmod -Rfv 750 /etc/openvpn
	elif id "nm-openvpn" &>/dev/null; then
		chown -Rfv nm-openvpn:nm-openvpn /etc/openvpn
		chmod -Rfv 750 /etc/openvpn
	else
		echo "ERROR - NO openvpn USER FOUND!!!"
		echo "PLEASE SET UP YOUR OWN PERMISSIONS FOR"
		echo "/etc/openvpn"
	fi
}

Install_dependancies()
{
	Has_sudo
	packagesNeeded="openvpn"
	echo "Preparing to install needed dependancies for OpenVPN..."

	if [ -f /etc/os-release ]; then
		source /etc/os-release
		crbOrPowertools=
		os_detected=true
		echo "ID=$ID"
		
			case "$ID" in
				fedora)				dnf install $packagesNeeded -y ;;
				rhel)					dnf install $packagesNeeded -y ;;
				debian)				apt install $packagesNeeded -y ;;
				ubuntu)				apt install $packagesNeeded -y ;;
				linuxmint)			apt install $packagesNeeded -y ;;
				elementary)		apt install $packagesNeeded -y ;;
				arch)					pacman -Syu $packagesNeeded  ;;
				endeavouros)		pacman -Syu $packagesNeeded  ;;
				manjaro)				pacman -Syu $packagesNeeded  ;;
				opensuse*)			zypper install $packagesNeeded ;;
			esac
	else
		os_detected=false
		echo "|-------------------------------------------------------------------|"
		echo "|                       ******WARNING******                         |"
		echo "|                        ******ERROR******                          |"
		echo "|               FAILED TO FIND /etc/os-release FILE.                |"
		echo "|              PLEASE MANUALLY INSTALL THESE PACKAGES:              |"
		echo "|                             openvpn                               |"
		echo "|-------------------------------------------------------------------|"
		Log "ERROR | FAILED TO FIND /etc/os-release FILE!"
		Log "ERROR | COULD NOT IDENTIFY PACKAGE MANAGER!"
		read -p "Press ENTER to continue" ENTER
	fi
}

Disable_IPv6()
{
	if [ -x "$(command -v ufw)" ]; then
		read -p "Would you like to disable IPv6 in UFW? : [y/N] " disableIPv6
		if [[ $disableIPv6 == [yY] ]] || [[ $disableIPv6 == [yY][eE][sS] ]]; then
			Change_variable IPV6 no null /etc/default/ufw
			ufw disable
			ufw enable
		fi
			ufw reload
	fi
}

Setup()
{
	Has_sudo
	_serviceStorageDir=
	_serviceActiveDir=
	Install_dependancies
	echo "Press ENTER to skip"
	read -p "Input your VPN Provider : " accountFileName
	read -p "Input your VPN Account Name : " vpnAccountName
	read -p "Input your VPN Password : " vpnPassword
	clear

	if [ -x "$(command -v sv)" ]; then
		_isRunit=true
		if [[ $_service == *"@"* ]]; then
			_service=$(echo $_service | cut -d "@" -f 1)
		fi
	fi

	if [ -d /etc/sv ]; then # Void Linux - Runit
		_serviceStorageDir=/etc/sv
		_serviceActiveDir=/var/service/
		cp -fv .services/runit/* $_serviceStorageDir/
	elif [ -d /etc/runit/sv ]; then # Artix Linux - Runit
		_serviceStorageDir=/etc/runit/sv
		_serviceActiveDir=/var/service/
		cp -fv .services/runit/* $_serviceStorageDir/
	elif [ -x "$(command -v systemctl)" ]; then
		_serviceStorageDir=/usr/lib/systemd/system/
		cp -fv .services/systemd/* $_serviceStorageDir/
	else
		Log "ERROR | NO INIT SYSTEM FOUND, EXITING!"
		exit
	fi
	
	if [[ -n $vpnAccountName ]]; then
		mkdir -p /etc/openvpn/accounts/
		mkdir -p /etc/openvpn/client/
		echo "$accountUserName" >> /etc/openvpn/accounts/$accountFileName
	 	echo "$accountPassWord" >> /etc/openvpn/accounts/$accountFileName
		ls -w 1 /etc/openvpn/accounts/
 	fi
	Fix_Permissions
	Disable_IPv6
	cp ovpn.sh /bin/ovpn
	ln -s /bin/ovpn /usr/local/bin/ovpn
	chown -Rf root:root $_serviceStorageDir
	
	if [ -x "$(command -v sestatus)" ]; then
		/sbin/restorecon -v /usr/lib/systemd/system/openvpn-client@.service
		/sbin/restorecon -v /usr/lib/systemd/system/killswitch.service
		/sbin/restorecon -v /usr/bin/ovpn
	fi
	
	if [ -x "$(command -v apt)" ] || [ -x "$(command -v pacman)" ] || [ -x "$(command -v zypper)" ]; then
		cp -f .man-page/ovpn.1 /usr/share/man/man1/
	elif [ -x "$(command -v dnf)" ]; then
		cp -f .man-page/ovpn.1 /usr/local/share/man/man1/
	fi

	chmod +x /bin/ovpn
	ovpn -h
}

Restore()
{
	Has_sudo
	if [ ! -f $1 ]; then
		echo "ERROR: $1 IS NOT A FILE. TRY AGAIN!"
		exit
	fi
	
	importTar=$1
	tar xf $importTar -C /
	Fix_Permissions
	Setup
	ovpn -e -s
	echo "Complete!"
	
}

# MAIN

if [[ -n "$1" ]]; then
	while [[ -n "$1" ]]; do
		case "$1" in
			-rb) Restore $2 
						shift ;;
			*) echo "Option $1 not recognized" ;;
		esac
		shift
	done
else
	Setup
fi

# END MAIN
