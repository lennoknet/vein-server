#!/usr/bin/env bash

# Enhanced Elysium Server Installer
# This script installs and configures a Echoes of Elysium game server as a service

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variables with defaults
SERVER_NAME="My New Elysium Server"
SERVER_ADDR="0.0.0.0"
SERVER_PORT="27015"
SERVER_DATA="./GameData/"
SERVER_WORLD="./world/"
SERVER_LOGS="./logs/"
SERVER_PASSWORD="secret"
SERVER_SAVEFREQ="5"
SERVER_PROFILE="false"
SERVER_BACKUPS="true"
SERVER_BAK_FREQ="30"
SERVER_BAK_MAX="5"
SERVER_CHANNEL="public"
INSTALL_PATH="/home/steam/Steam/elysium-server"
START_ON_BOOT=true

# Function to display header
display_header() {
    clear
    echo -e "${BOLD}${BLUE}====================================================${NC}"
    echo -e "${BOLD}${BLUE}    Echoes of Elysium Server Installation Script    ${NC}"
    echo -e "${BOLD}${BLUE}====================================================${NC}"
    echo ""
}

# Function to display section header
section_header() {
    echo ""
    echo -e "${BOLD}${CYAN}>> $1${NC}"
    echo -e "${CYAN}---------------------------------------${NC}"
}

# Function to run commands silently
run_silent() {
    echo -en "   ${YELLOW}⚙️  $1... ${NC}"
    if eval "$2" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        echo -e "   ${RED}Error executing: $2${NC}"
        return 1
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running as root
check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        echo -e "${RED}Error: Please run as root (e.g., sudo $0)${NC}"
        exit 1
    fi
}

# Function to configure server settings
configure_server() {
    display_header
    section_header "Server Configuration"
    
    echo -e "Please configure your Elysium server settings:"
    echo ""
    
    # Server Name
    read -p "$(echo -e "${BOLD}Server name${NC} [${SERVER_NAME}]: ")" input
    SERVER_NAME=${input:-"$SERVER_NAME"}
    
    # Public Address
    read -p "$(echo -e "${BOLD}Binding IP${NC} (0.0.0.0=all)) [${SERVER_ADDR}]: ")" input
    SERVER_ADDR=${input:-"$SERVER_ADDR"}
    
    # Server Port
    read -p "$(echo -e "${BOLD}Server Port${NC} [${SERVER_PORT}]: ")" input
    SERVER_PORT=${input:-"$SERVER_PORT"}
    
    # Server Password - Prompt for password with confirmation
    while true; do
        read -p "$(echo -e "${BOLD}Server password${NC} (leave blank for none): ")" SERVER_PASSWORD
        
        # If password is blank, confirm that's what they want
        if [ -z "$SERVER_PASSWORD" ]; then
            read -p "$(echo -e "${YELLOW}Warning: No password means anyone can join. Continue?${NC} (y/n): ")" confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                break
            fi
        else
            read -p "$(echo -e "${BOLD}Confirm password${NC}: ")" PASSWORD_CONFIRM
            if [ "$SERVER_PASSWORD" == "$PASSWORD_CONFIRM" ]; then
                break
            else
                echo -e "${RED}Passwords do not match. Please try again.${NC}"
            fi
        fi
    done
    
    # Data Path
    read -p "$(echo -e "${BOLD}Data Path${NC} [${SERVER_DATA}]: ")" input
    SERVER_DATA=${input:-"$SERVER_DATA"}
    
    # World Path
    read -p "$(echo -e "${BOLD}World Path${NC} (optional) [${SERVER_WORLD}]: ")" input
    SERVER_WORLD=${input:-"$SERVER_WORLD"}
    
    echo ""
    section_header "Advanced Settings"
    echo -e "Configure advanced server settings (optional):"
    echo ""
    
    # Log Path
    read -p "$(echo -e "${BOLD}Log Path${NC} [${SERVER_LOGS}]: ")" input
    SERVER_LOGS=${input:-"$SERVER_LOGS"}
	
	# Save Frequency
    read -p "$(echo -e "${BOLD}Save Frequency${NC} [${SERVER_SAVEFREQ}]: ")" input
    SERVER_SAVEFREQ=${input:-"$SERVER_SAVEFREQ"}

    # Server Profile
    read -p "$(echo -e "${BOLD}Server Profile${NC} (true/false) [${SERVER_PROFILE}]: ")" input
    SERVER_PROFILE=${input:-"$SERVER_PROFILE"}
	
    # Backup
    read -p "$(echo -e "${BOLD}Backups${NC} (true/false) [${SERVER_BACKUPS}]: ")" input
    SERVER_BACKUPS=${input:-"$SERVER_BACKUPS"}
    
    # Backup Frequency
    read -p "$(echo -e "${BOLD}Backup Frequency${NC} [${SERVER_BAK_FREQ}]: ")" input
    SERVER_BAK_FREQ=${input:-"$SERVER_BAK_FREQ"}

    # Backup Amount
    read -p "$(echo -e "${BOLD}Backup max amount to keep${NC} [${SERVER_BAK_MAX}]: ")" input
    SERVER_BAK_MAX=${input:-"$SERVER_BAK_MAX"}

    # Server Channel
    read -p "$(echo -e "${BOLD}Server Channel${NC} (public/beta) [${SERVER_CHANNEL}]: ")" input
    SERVER_CHANNEL=${input:-"$SERVER_CHANNEL"}
    
     # Start on Boot
    read -p "$(echo -e "${BOLD}Start on boot?${NC} (true/false) [${START_ON_BOOT}]: ")" input
    START_ON_BOOT=${input:-"$START_ON_BOOT"}
    
    # Installation Path
    read -p "$(echo -e "${BOLD}Installation Path${NC} [${INSTALL_PATH}]: ")" input
    INSTALL_PATH=${input:-"$INSTALL_PATH"}
}

# Function to install system dependencies
install_dependencies() {
    section_header "Installing Dependencies"
    
    run_silent "Updating package lists" "apt update"
    run_silent "Installing required packages" "apt install -y curl jo lib32gcc-s1 whiptail dialog"
}

# Function to create steam user
create_steam_user() {
    section_header "Creating Steam User"
    
    if id "steam" &>/dev/null; then
        echo -e "   ${YELLOW}Steam user already exists. Skipping.${NC}"
    else
        STEAM_PASSWORD=$(openssl rand -base64 12)
        run_silent "Creating steam user" "/usr/sbin/useradd -m -s /bin/bash steam"
        run_silent "Setting steam user password" "echo 'steam:${STEAM_PASSWORD}' | /usr/sbin/chpasswd"
    fi
}

# Function to install SteamCMD
install_steamcmd() {
    section_header "Installing SteamCMD"
    
    run_silent "Creating Steam directory" "/usr/sbin/runuser -l steam -c 'mkdir -p ~/Steam'"
    run_silent "Downloading SteamCMD" "/usr/sbin/runuser -l steam -c 'cd ~/Steam && curl -sqL \"https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz\" | tar zxvf -'"
}

# Function to install Elysium server
install_elys_server() {
    section_header "Installing Elysium Server"
    
    echo -e "   ${YELLOW}⚙️  Installing Echoes of Elysium server (this may take a while)...${NC}"
    
    if /usr/sbin/runuser -l steam -c "~/Steam/steamcmd.sh +force_install_dir ${INSTALL_PATH} +login anonymous +app_update 2915100 -beta ${SERVER_CHANNEL} validate +quit" > /dev/null 2>&1; then
        echo -e "   ${GREEN}✓ Elysium server installed successfully${NC}"
    else
        echo -e "   ${RED}✗ Failed to install Elysium server${NC}"
        echo -e "   ${RED}Please check your internet connection and try again${NC}"
        exit 1
    fi


    run_silent "Remove previous symlink if exist" "rm -f \"${INSTALL_PATH}/linux64/libsteam_api.so\""
    run_silent "Creating symlink for libsteam_api.so" "mkdir -p \"${INSTALL_PATH}/linux64/\" && ln -s \"${INSTALL_PATH}/libsteam_api.so\" \"${INSTALL_PATH}/linux64/\""

}

# Function to create server config
create_server_config() {
    section_header "Creating Server Configuration"

# Create Config JSON
jo -p \
    address="${SERVER_ADDR}" \
    port=${SERVER_PORT} \
    name="${SERVER_NAME}" \
    password="${SERVER_PASSWORD}" \
    gameDataDir="${SERVER_DATA}" \
    worldDataDir="${SERVER_WORLD}" \
    logsDir="${SERVER_LOGS}" \
    enableProfiling=${SERVER_PROFILE} \
    saveFreqMins=${SERVER_SAVEFREQ} \
    backupsEnabled=${SERVER_BACKUPS} \
    backupFreqMins=${SERVER_BAK_FREQ} \
    maxBackups=${SERVER_BAK_MAX} \
    > ${INSTALL_PATH}/config.json


    
    echo -e "   ${GREEN}✓${NC}"
}

# Function to create systemd service
create_systemd_service() {
    section_header "Creating SystemD Service"
    
   
    cat > /etc/systemd/system/elysium-server.service <<EOF
[Unit]
Description=Elysium Dedicated Server
After=network.target

[Service]
Type=simple
User=steam
WorkingDirectory=${INSTALL_PATH}
Environment="LD_LIBRARY_PATH=${INSTALL_PATH}:${INSTALL_PATH}/linux64"
Environment="SteamAppId=2644050"
ExecStartPre=/home/steam/Steam/steamcmd.sh +force_install_dir ${INSTALL_PATH} +login anonymous +app_update 2915100 -beta ${SERVER_CHANNEL} validate +quit
ExecStart=${INSTALL_PATH}/ElysiumServer --config ${INSTALL_PATH}/config.json
Restart=on-failure
RestartSec=10
LimitNOFILE=10000

[Install]
WantedBy=multi-user.target
EOF
    
    run_silent "Setting permissions 1/3" "chown -R steam:steam ${INSTALL_PATH}"
	run_silent "Setting permissions 2/3" "chmod -R 755 ${INSTALL_PATH}"
	run_silent "Setting permissions 3/3" "chmod +x ${INSTALL_PATH}/ElysiumServer"
    run_silent "Reloading systemd daemon" "systemctl daemon-reload"
    run_silent "Checking Public IP" "ExternalIP4=$(curl -s https://ipv4.myip.wtf/text)"

    
    if [ "${START_ON_BOOT}" = "true" ]; then
        run_silent "Enabling service at boot" "systemctl enable elysium-server.service"
    fi
}

# Function to display completion message
display_completion() {
    display_header
    echo -e "${GREEN}${BOLD}✓ Elysium Server Installation Completed Successfully!${NC}"
    echo ""
    echo -e "Your server has been configured with the following settings:"
    echo -e "   ${BOLD}Server Name:${NC} ${SERVER_NAME}"
	echo -e "   ${BOLD}Game Port:${NC} ${SERVER_PORT}"
    echo -e "   ${BOLD}Public IP:${NC} ${ExternalIP4}"
    echo -e "   ${BOLD}Password Protected:${NC} $([ -n "${PASSWORD}" ] && echo "Yes" || echo "No")"
    echo -e "   ${BOLD}Installation Path:${NC} ${INSTALL_PATH}"
    echo ""
    echo -e "${YELLOW}To manage your server:${NC}"
    echo -e "   ${BOLD}Start server:${NC} systemctl start elysium-server.service"
    echo -e "   ${BOLD}Stop server:${NC} systemctl stop elysium-server.service"
    echo -e "   ${BOLD}Restart server:${NC} systemctl restart elysium-server.service"
    echo -e "   ${BOLD}Check status:${NC} systemctl status elysium-server.service"
    echo -e "   ${BOLD}View logs:${NC} journalctl -u elysium-server.service -f"

    echo ""
    
    if [ "${START_ON_BOOT}" = "true" ]; then
        echo -e "Your server is ${GREEN}enabled${NC} to start automatically at boot."
    else
        echo -e "Your server is ${YELLOW}not enabled${NC} to start automatically at boot."
    fi
            
    echo ""
    echo -e 'Do you want to start the server now? (y/n): '
    read -r START_NOW
    if [[ "${START_NOW}" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Starting Elysium server...${NC}"
        systemctl start elysium-server.service
        echo -e "${GREEN}Server started!${NC}"
    fi
}

# Main function
main() {
    set -e # Exit on error
    
    check_root
    display_header
    
    echo -e "This script will install and configure a Elysium dedicated server."
    echo -e "It will perform the following steps:"
    echo -e "  1. Install required dependencies"
    echo -e "  2. Configure firewall rules"
    echo -e "  3. Create a steam user"
    echo -e "  4. Install SteamCMD"
    echo -e "  5. Download and install the Elysium server"
    echo -e "  6. Configure server settings"
    echo -e "  7. Set up a systemd service"
    echo ""
    echo -e "Press ${BOLD}ENTER${NC} to begin or ${BOLD}CTRL+C${NC} to cancel..."
    read -r
    
    configure_server
    
    # Confirmation
    display_header
    echo -e "${YELLOW}Please review your settings:${NC}"
    echo ""
    echo -e "   ${BOLD}Server Name:${NC} ${SERVER_NAME}"
    echo -e "   ${BOLD}Bind IP:${NC} ${SERVER_ADDR}"
	echo -e "   ${BOLD}Server Port:${NC} ${SERVER_PORT}"
    echo -e "   ${BOLD}Data Path:${NC} ${SERVER_DATA}"
	echo -e "   ${BOLD}World Path:${NC} ${SERVER_WORLD}"
	echo -e "   ${BOLD}Logs Path:${NC} ${SERVER_LOGS}"
    echo -e "   ${BOLD}Password Protected:${NC} $([ -n "${PASSWORD}" ] && echo "Yes" || echo "No")"
    echo -e "   ${BOLD}Save Frequency:${NC} ${QUERY_PORT}"
    echo -e "   ${BOLD}Profile:${NC} ${SERVER_PROFILE}"
	echo -e "   ${BOLD}Backups:${NC} ${SERVER_BACKUPS}"
	echo -e "   ${BOLD}Backup Frequency:${NC} ${SERVER_BAK_FREQ}"
	echo -e "   ${BOLD}Backup Max Amount:${NC} ${SERVER_BAK_MAX}"
    echo -e "   ${BOLD}Channel:${NC} ${SERVER_CHANNEL}"
    echo -e "   ${BOLD}Start on Boot:${NC} ${START_ON_BOOT}"
    echo -e "   ${BOLD}Installation Path:${NC} ${INSTALL_PATH}"
    echo ""
    echo -e "Proceed with installation? (y/n): "
    read -r CONFIRM
    
    if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
        echo -e "${RED}Installation cancelled.${NC}"
        exit 0
    fi
    
    display_header
    install_dependencies
    create_steam_user
    install_steamcmd
    install_elys_server
    create_server_config
    create_systemd_service
    display_completion
}

# Execute main function
main
