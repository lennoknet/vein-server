# VEIN Server

This is a guided bash script for easy setup of a VEIN dedicated server and backup functions for command line interface (CLI) users only. The dashboard installation is currently deactivated.

This solution consists of a bash script that automates the process described at https://ramjet.notion.site/dedicated-servers (as of May 2, 2025), a backup script that can manually or daily backup the servers save data.

## Prerequisites

Refer to https://developer.valvesoftware.com/wiki/SteamCMD#Debian
You need to have software-properties-common installed as well as non-free repository and i386 architecture.

If you have no clue of Linux, you may also use my step-by-step manual to set up the machine to be able to run the script:
https://github.com/lennoknet/vein-server/blob/main/Deb13-Documentation.md
NAT and Port rules for your router is then your only thing you need to work on yourself.

## Installation

Ensure you have Debian 12 or 13 installed properly, given your machine a static IP, internet access and ensure the query port and game port you want to use are accessible through NAT.

To install the VEIN Server, just clone the repo, make the install script executable, and then run it:

```bash
git clone https://github.com/lennoknet/vein-server.git
cd vein-server
chmod +x setup-vein-server.sh
./setup-vein-server.sh
```

## Usage/Examples

Start server:     `systemctl start vein-server.service`  
Stop server:      `systemctl stop vein-server.service`  
Restart server:   `systemctl restart vein-server.service`  
View logs:       `journalctl -u vein-server.service -f`  

## Screenshots

### setup-vein-server.sh
![App Screenshot](https://i.imgur.com/jaJuMP4.png)

### backup-vein-server.sh
![App Screenshot](https://i.imgur.com/6F7sSN9.png)

## Planned Features

Follow the main branch - I only ensured this script is working out of the box when set up debian 12 or 13.
