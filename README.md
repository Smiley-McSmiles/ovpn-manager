# DESCRIPTION
OVPN-Manager is a simple BASH script to install, and manage your OpenVPN client connetions. Switch between connections and enable a kill switch to prevent IP leaks and import and backup your .ovpn connections to use on another system for easy setup.

> v1.1.9

> Tested on Fedora 36, Ubuntu 22.04, Arch Linux, and Artix Linux (Runit)

### What is supported:
- GNU/Linux Systems with
  - SystemD, Runit, Dinit, or OpenRC
  - SELinux or Apparmour

### What will be supported:
- BSD systems
- s6 init system

## INSTALL/UPDATE INSTRUCTIONS

```bash
git clone https://github.com/Smiley-McSmiles/ovpn-manager
cd ovpn-manager
chmod +x setup.sh
sudo ./setup.sh
```

## USAGE

```
OpenVPN Manager v1.1.7
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
```
