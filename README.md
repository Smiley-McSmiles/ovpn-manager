# DESCRIPTION
OVPN-Manager is a simple BASH script to install, and manage your OpenVPN client connetions. Switch between connections and enable a kill switch to prevent IP leaks and import and backup your .ovpn connections to use on another system for easy setup.

> v1.1.9

> Tested on Fedora 36, Ubuntu 22.04, Arch Linux, and Artix Linux (Runit)

### What is supported:
- GNU/Linux Systems with
  - SystemD, Runit, Dinit, or OpenRC
  - SELinux or Apparmour
  - UFW firewall

### What will be supported:
- BSD systems
- nftables

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
-s, --start | Start OpenVPN
-S, --stop | Stop OpenVPN
-t, --status | Status of OpenVPN
-e, --enable | Enable OpenVPN
-d, --disable | Disable OpenVPN
-r, --restart | Restart OpenVPN
-c, --change-server | Change OpenVPN Connection
-i, --import | Import OpenVPN .ovpn file
-sd, --switch-dns | switch to new DNS server
-k, --killswitch | [on/off] Enable or Disable the Killswitch
-f, --fix-permissions | Fix OpenVPN permissions
-v, --version | Print the version OpenVPN Manager
-b, --backup | Backup OpenVPN Manager Configurations
-rb, --remove-backup | [backup.tar] Restore OpenVPN Manager Configurations
-l, --view-logs | View logs
-h, --help | Display this help menu

Kill Switch Behavior:
- The Kill Switch is manually turned on or off. Once enabled, if the connection
to your OpenVPN server is lost, there will be no connection to the internet.
However, when the Kill Switch is enabled, and there is no connection to the internet,
The Kill Switch will restart the OpenVPN systemd service to try and re-establish a conneciton.
```
