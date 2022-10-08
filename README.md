# INSTALL INSTRUCTIONS

```sh
git clone https://github.com/Smiley-McSmiles/ovpn-manager
cd ovpn-manager
chmod +x setup.sh
sudo ./setup.sh
```

# UPDATE INSTRUCTIONS
`sudo wget -O /bin/ovpn https://raw.githubusercontent.com/Smiley-McSmiles/ovpn-manager/main/ovpn.sh; sudo chmod +x /bin/ovpn`

# USAGE

```sh
OpenVPN Manager v1.1.0
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

Kill Switch Behavior:
- The Kill Switch is automatic once enabled. Running 'ovpn -S' when 'ovpn -k on'
will allow connections outside of the 'tun' interface. Then running 'ovpn -s'
Will re-enable the Kill Switch if 'ovpn -k on'.

```
