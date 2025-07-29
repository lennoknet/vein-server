# VEIN Server

This is a guided bash script for easy setup of a VEIN Demo dedicated server including a dashboard and backup functions.   

This solution consists of a bash script that automates the process described at https://ramjet.notion.site/dedicated-servers (as of May 2, 2025), a backup script that can manually or daily backup the servers save data, and a Python program that serves a dashboard for ease of use starting/stopping and logging the server.

## Installation

To install the VEIN Server, just clone the repo, make the install script executable, and then run it:

```bash
git clone https://github.com/warmbo/vein-server.git
cd vein-server
chmod +x setup-vein-server.sh
./setup-vein-server.sh
```

## Usage/Examples

Start server:     `systemctl start vein-server.service`  
Stop server:      `systemctl stop vein-server.service`  
Restart server:   `systemctl restart vein-server.service`  
View logs:       `journalctl -u vein-server.service -f`  
Dashboard:   `http://<your-server-ip>:5000`  

## Screenshots

### Dashboard
![App Screenshot](https://i.imgur.com/1pDEitr.png)

### setup-vein-server.sh
![App Screenshot](https://i.imgur.com/jaJuMP4.png)

### backup-vein-server.sh
![App Screenshot](https://i.imgur.com/6F7sSN9.png)

## Planned Features

- Server Reset/Wipe with confirmation dialog
- RCON messaging once implemented in server, for MOTD, server events, etc.
- System stats such as CPU usage, MEM usage, and save backup storage size monitoring
- Settings menu for changing server config
