# minictinit.sh
minictinit.sh is a simple init script to use with ProxMox LXC container clones based on Debian/Ubuntu. It can be installed as a systemd service. It runs only once on first boot and performs specified initialization tasks. Currently it supports the following init tasks:

* SSH configuration (creates host keys, permits root login, enables SSH service)
* Zabbix agent configuration (sets agent autoregistration by adding and changing some zabbix_agentd.conf parameters, limits logfile size)
* Default editor in /etc/bash.bashrc

## Usage
### Prepare container template
### Installation
