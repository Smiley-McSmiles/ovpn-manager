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
	ovpnServiceLocation=/usr/lib/systemd/system/
	Install_dependancies
	echo "Press ENTER to skip"
	read -p "Input your VPN Provider : " accountFileName
	read -p "Input your VPN Account Name : " vpnAccountName
	read -p "Input your VPN Password : " vpnPassword
	clear
	
	if [[ -n $vpnAccountName ]]; then
		mkdir -p /etc/openvpn/accounts/
		mkdir -p /etc/openvpn/client/
		echo "$accountUserName" >> /etc/openvpn/accounts/$accountFileName
	 	echo "$accountPassWord" >> /etc/openvpn/accounts/$accountFileName
		ls -w 1 /etc/openvpn/accounts/
 	fi
	Fix_Permissions
	Disable_IPv6
	mv ovpn.sh /bin/ovpn
	ln -s /bin/ovpn /usr/local/bin/ovpn
	mv -fv .services/* $ovpnServiceLocation
	chown -Rf root:root $ovpnServiceLocation
	
	if [ -x "$(command -v sestatus)" ]; then
		/sbin/restorecon -v /usr/lib/systemd/system/openvpn-client@.service
		/sbin/restorecon -v /usr/lib/systemd/system/killswitch.service
		/sbin/restorecon -v /usr/bin/ovpn
	fi
	
	if [ -x "$(command -v apt)" ] || [ -x "$(command -v pacman)" ] || [ -x "$(command -v zypper)" ]; then
		mv -f .man-page/ovpn.1 /usr/share/man/man1/
	elif [ -x "$(command -v dnf)" ]; then
		mv -f .man-page/ovpn.1 /usr/local/share/man/man1/
	fi

	chmod +x /bin/ovpn
	ovpn -h -i
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
