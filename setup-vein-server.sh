#!/usr/bin/env bash

# Enhanced VEIN Server Installer
# This script installs and configures a VEIN game server

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
SERVER_NAME="My New VEIN Server"
SERVER_DESC="Vanilla Server"
PUBLIC="true"
MAX_PLAYERS=16
SUPER_ADMIN_ID=""
ADMIN_ID=""
PASSWORD=""
PORT=7777
QUERY_PORT=27015
VAC_ENABLED=0
HEARTBEAT_INTERVAL=5.0
AUTO_UPDATE=true
AUTO_RESTART=true
BIND_ADDR="0.0.0.0"
INSTALL_PATH="/home/steam/Steam/vein-server"
START_ON_BOOT=true
DASH_PORT=5000

# Function to display header
display_header() {
    clear
    echo -e "${BOLD}${BLUE}=======================================${NC}"
    echo -e "${BOLD}${BLUE}    VEIN Server Installation Script    ${NC}"
    echo -e "${BOLD}${BLUE}=======================================${NC}"
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
    
    echo -e "Please configure your VEIN server settings:"
    echo ""
    
    # Server Name
    read -p "$(echo -e "${BOLD}Server name${NC} [${SERVER_NAME}]: ")" input
    SERVER_NAME=${input:-"$SERVER_NAME"}

    # Server Description
    read -p "$(echo -e "${BOLD}Server description${NC} [${SERVER_DESC}]: ")" input
    SERVER_DESC=${input:-"$SERVER_DESC"}
    
    # Public Server
    read -p "$(echo -e "${BOLD}Public listing?${NC} (true/false) [${PUBLIC}]: ")" input
    PUBLIC=${input:-"$PUBLIC"}
    
    # Max Players
    read -p "$(echo -e "${BOLD}Max players${NC} [${MAX_PLAYERS}]: ")" input
    MAX_PLAYERS=${input:-"$MAX_PLAYERS"}
    
    # Server Password - Prompt for password with confirmation
    while true; do
        read -p "$(echo -e "${BOLD}Server password${NC} (leave blank for none): ")" PASSWORD
        
        # If password is blank, confirm that's what they want
        if [ -z "$PASSWORD" ]; then
            read -p "$(echo -e "${YELLOW}Warning: No password means anyone can join. Continue?${NC} (y/n): ")" confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                break
            fi
        else
            read -p "$(echo -e "${BOLD}Confirm password${NC}: ")" PASSWORD_CONFIRM
            if [ "$PASSWORD" == "$PASSWORD_CONFIRM" ]; then
                break
            else
                echo -e "${RED}Passwords do not match. Please try again.${NC}"
            fi
        fi
    done
    
    # Super Admin SteamID
    read -p "$(echo -e "${BOLD}SuperAdmin SteamID${NC} [${SUPER_ADMIN_ID}]: ")" input
    SUPER_ADMIN_ID=${input:-"$SUPER_ADMIN_ID"}
    
    # Admin SteamID
    read -p "$(echo -e "${BOLD}Admin SteamID${NC} (optional) [${ADMIN_ID}]: ")" input
    ADMIN_ID=${input:-"$ADMIN_ID"}
    
    echo ""
    section_header "Advanced Settings"
    echo -e "Configure advanced server settings (optional):"
    echo ""
    
    # Game Port
    read -p "$(echo -e "${BOLD}Game Port${NC} [${PORT}]: ")" input
    PORT=${input:-"$PORT"}
    
    # Query Port
    read -p "$(echo -e "${BOLD}Query Port${NC} [${QUERY_PORT}]: ")" input
    QUERY_PORT=${input:-"$QUERY_PORT"}
    
    # VAC Enabled
    read -p "$(echo -e "${BOLD}VAC Enabled${NC} (0/1) [${VAC_ENABLED}]: ")" input
    VAC_ENABLED=${input:-"$VAC_ENABLED"}
    
    # Heartbeat Interval
    read -p "$(echo -e "${BOLD}Heartbeat Interval${NC} [${HEARTBEAT_INTERVAL}]: ")" input
    HEARTBEAT_INTERVAL=${input:-"$HEARTBEAT_INTERVAL"}
    
    # Bind Address
    read -p "$(echo -e "${BOLD}Bind Address${NC} [${BIND_ADDR}]: ")" input
    BIND_ADDR=${input:-"$BIND_ADDR"}
    
    # Auto Update
    read -p "$(echo -e "${BOLD}Auto update on restart?${NC} (true/false) [${AUTO_UPDATE}]: ")" input
    AUTO_UPDATE=${input:-"$AUTO_UPDATE"}
    
    # Auto Restart
    read -p "$(echo -e "${BOLD}Auto restart on failure?${NC} (true/false) [${AUTO_RESTART}]: ")" input
    AUTO_RESTART=${input:-"$AUTO_RESTART"}
    
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
    run_silent "Installing required packages" "apt install -y ufw curl lib32gcc-s1 whiptail dialog"
    run_silent "Installing more required packages" "apt install -y libatomic1 libasound2 libpulse0"
}

# Function to configure firewall
configure_firewall() {
    section_header "Configuring Firewall"
    
    run_silent "Allowing game port ${PORT}/udp" "/usr/sbin/ufw allow ${PORT}/udp"
    run_silent "Allowing query port ${QUERY_PORT}/udp" "/usr/sbin/ufw allow ${QUERY_PORT}/udp"
#    run_silent "Allowing dashboard port ${DASH_PORT}/tcp" "ufw allow ${DASH_PORT}/tcp"
    run_silent "Allowing ssh port 22/tcp" "/usr/sbin/ufw allow 22/tcp"
    run_silent "Enabling firewall" "/usr/sbin/ufw --force enable"
}

# Function to create steam user
create_steam_user() {
    section_header "Creating Steam User"
    
    if id "steam" &>/dev/null; then
        echo -e "   ${YELLOW}Steam user already exists. Skipping.${NC}"
    else
        STEAM_PASSWORD=$(openssl rand -base64 12)
        run_silent "Creating steam user" "/usr/sbin/useradd -m -s /bin/bash steam"
        run_silent "Setting steam user password" "echo 'steam:${STEAM_PASSWORD}' | /usr/bin/chpasswd"
    fi
}

# Function to install SteamCMD
install_steamcmd() {
    section_header "Installing SteamCMD"
    
    run_silent "Creating Steam directory" "/usr/sbin/runuser -l steam -c 'mkdir -p ~/Steam'"
    run_silent "Downloading SteamCMD" "/usr/sbin/runuser -l steam -c 'cd ~/Steam && curl -sqL \"https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz\" | tar zxvf -'"
}

# Function to install VEIN server
install_vein_server() {
    section_header "Installing VEIN Server"
    
    echo -e "   ${YELLOW}⚙️  Installing VEIN server (this may take some time, downloading about 15GB)...${NC}"
    
    if /usr/sbin/runuser -l steam -c "~/Steam/steamcmd.sh +force_install_dir ${INSTALL_PATH} +login anonymous +app_update 2131400 validate +quit" > /dev/null 2>&1; then
        echo -e "   ${GREEN}✓ VEIN server installed successfully${NC}"
    else
        echo -e "   ${RED}✗ Failed to install VEIN server${NC}"
        echo -e "   ${RED}Please check your internet connection and try again${NC}"
        exit 1
    fi
    
# symlink instead of copying is preferred, monitoring behaviour
    run_silent "Copying steamclient.so" "mkdir -p \"${INSTALL_PATH}/Vein/Binaries/Linux/\" && cp /home/steam/Steam/linux64/steamclient.so \"${INSTALL_PATH}/Vein/Binaries/Linux/steamclient.so\""
}

# Function to create server config
create_server_config() {
    section_header "Creating Server Configuration"
    
    CONFIG_DIR="${INSTALL_PATH}/Vein/Saved/Config/LinuxServer"
    run_silent "Creating config directory" "mkdir -p \"${CONFIG_DIR}\""
    
    # Write Game.ini
    CONFIG_FILE="${CONFIG_DIR}/Game.ini"
    echo -e "   ${YELLOW}⚙️  Writing server configuration...${NC}"
    
    cat > "${CONFIG_FILE}" <<EOF
[/Script/Engine.GameSession]
MaxPlayers=${MAX_PLAYERS}

[/Script/Vein.VeinGameSession]
bPublic=${PUBLIC}
ServerName="${SERVER_NAME}"
ServerDesciption="${SERVER_DESC}"
BindAddr=${BIND_ADDR}
SuperAdminSteamIDs=${SUPER_ADMIN_ID}
$([ -n "${ADMIN_ID}" ] && echo "AdminSteamIDs=${ADMIN_ID}")
HeartbeatInterval=${HEARTBEAT_INTERVAL}
Password="${PASSWORD}"

[OnlineSubsystemSteam]
GameServerQueryPort=${QUERY_PORT}
bVACEnabled=${VAC_ENABLED}

[URL]
Port=${PORT}
EOF
    
    echo -e "   ${GREEN}✓${NC}"
}

# Function to create systemd service
create_systemd_service() {
    section_header "Creating SystemD Service"
    
    AUTO_UPDATE_CMD=""
    if [ "${AUTO_UPDATE}" = "true" ]; then
        AUTO_UPDATE_CMD="ExecStartPre=/home/steam/Steam/steamcmd.sh +force_install_dir ${INSTALL_PATH} +login anonymous +app_update 2131400 validate +quit"
    fi
    
    RESTART_POLICY="no"
    if [ "${AUTO_RESTART}" = "true" ]; then
        RESTART_POLICY="on-failure"
    fi
    
    cat > /etc/systemd/system/vein-server.service <<EOF
[Unit]
Description=VEIN Dedicated Server
After=network.target

[Service]
Type=simple
User=steam
WorkingDirectory=${INSTALL_PATH}
${AUTO_UPDATE_CMD}
ExecStart=${INSTALL_PATH}/VeinServer.sh -QueryPort=${QUERY_PORT} -Port=${PORT}
Restart=${RESTART_POLICY}
RestartSec=10
LimitNOFILE=10000

[Install]
WantedBy=multi-user.target
EOF
    
    run_silent "Setting permissions" "chown -R steam:steam ${INSTALL_PATH}"
    run_silent "Reloading systemd daemon" "systemctl daemon-reload"
    
    if [ "${START_ON_BOOT}" = "true" ]; then
        run_silent "Enabling service at boot" "systemctl enable vein-server.service"
    fi
}

# Function to display completion message
display_completion() {
    display_header
    echo -e "${GREEN}${BOLD}✓ VEIN Server Installation Completed Successfully!${NC}"
    echo ""
    echo -e "Your server has been configured with the following settings:"
    echo -e "   ${BOLD}Server Name:${NC} ${SERVER_NAME}"
    echo -e "   ${BOLD}Public:${NC} ${PUBLIC}"
    echo -e "   ${BOLD}Max Players:${NC} ${MAX_PLAYERS}"
    echo -e "   ${BOLD}Password Protected:${NC} $([ -n "${PASSWORD}" ] && echo "Yes" || echo "No")"
    echo -e "   ${BOLD}Game Port:${NC} ${PORT}"
    echo -e "   ${BOLD}Query Port:${NC} ${QUERY_PORT}"
    echo -e "   ${BOLD}Installation Path:${NC} ${INSTALL_PATH}"
    echo ""
    echo -e "${YELLOW}To manage your server:${NC}"
    echo -e "   ${BOLD}Start server:${NC} systemctl start vein-server.service"
    echo -e "   ${BOLD}Stop server:${NC} systemctl stop vein-server.service"
    echo -e "   ${BOLD}Restart server:${NC} systemctl restart vein-server.service"
    echo -e "   ${BOLD}Check status:${NC} systemctl status vein-server.service"
    echo -e "   ${BOLD}View logs:${NC} journalctl -u vein-server.service -f"
    echo -e "   ${BOLD}View dashboard:${NC} http://$(hostname -I | awk '{print $1}'):5000"

    echo ""
    
    if [ "${START_ON_BOOT}" = "true" ]; then
        echo -e "Your server is ${GREEN}enabled${NC} to start automatically at boot."
    else
        echo -e "Your server is ${YELLOW}not enabled${NC} to start automatically at boot."
    fi
    
    echo ""
    echo -e "Do you want to start the server now? (y/n): "
    read -r START_NOW
    if [[ "${START_NOW}" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Starting VEIN server...${NC}"
        systemctl start vein-server.service
        echo -e "${GREEN}Server started!${NC}"
    fi
}

# Function to install optional dashboard - system packages only
# ##### this needs some rework for working with debian and ubuntu likewise, so not available in this fork #####
#install_dashboard() {
#    section_header "Dashboard Installation"
#    read -p "Would you like to install the dashboard at http://$(hostname -I | awk '{print $1}'):5000? (y/n): " dashboard_choice
#
#    # Query Port
#    read -p "$(echo -e "${BOLD}Dashboard Port${NC} [${DASH_PORT}]: ")" input
#    DASH_PORT=${input:-"$DASH_PORT"}
#
#    if [[ "$dashboard_choice" =~ ^[Yy]$ ]]; then
#        # User wants dashboard - proceed with installation
#        section_header "Installing Python3 and Flask"
#        run_silent "Installing python3" "apt install -y python3"
#        
#        # Try to install Flask via system package manager
#        if ! run_silent "Installing Flask via apt" "apt install -y python3-flask"; then
#            echo -e "${RED}Failed to install Flask via system packages.${NC}"
#            echo -e "${YELLOW}Trying alternative method with pip...${NC}"
#            
#            run_silent "Installing python3-pip" "apt install -y python3-pip"
#            
#            # Use pip with --break-system-packages as last resort
#            if ! run_silent "Installing Flask via pip" "python3 -m pip install --break-system-packages flask"; then
#                echo -e "${RED}Failed to install Flask. Dashboard installation aborted.${NC}"
#                return 1
#            fi
#        fi
#
#        section_header "Setting up Dashboard Service"
#        DASHBOARD_PATH="/home/steam/vein-dashboard"
#        SERVICE_FILE="/etc/systemd/system/vein-dashboard.service"
#
#        # Setup dashboard files
#        run_silent "Creating dashboard directory" "mkdir -p \"${DASHBOARD_PATH}\""
#        
#        # Copy dashboard files or fail gracefully
#        if [ -d "dash" ]; then
#            run_silent "Copying dashboard files" "cp -r dash/* \"${DASHBOARD_PATH}/\""
#            run_silent "Setting dashboard permissions" "chown -R steam:steam \"${DASHBOARD_PATH}\""
#            
#            # Create systemd service (no virtual environment)
#            cat <<EOF > "$SERVICE_FILE"
#[Unit]
#Description=VEIN Dashboard
#After=network.target
#
#[Service]
#User=steam
#WorkingDirectory=${DASHBOARD_PATH}
#ExecStart=/usr/bin/python3 ${DASHBOARD_PATH}/app.py
#Restart=always
#
#[Install]
#WantedBy=multi-user.target
#EOF
#
#            run_silent "Reloading systemd daemon" "systemctl daemon-reload"
#            run_silent "Enabling dashboard service" "systemctl enable vein-dashboard"
#            run_silent "Starting dashboard service" "systemctl start vein-dashboard"
#
#            echo -e "${GREEN}Dashboard installed and running at http://$(hostname -I | awk '{print $1}'):5000${NC}"
#            echo -e "${YELLOW}Dashboard installed in: ${DASHBOARD_PATH}${NC}"
#        else
#            echo -e "${RED}Dashboard files not found in 'dash' directory.${NC}"
#            echo -e "${YELLOW}Dashboard installation failed - files missing.${NC}"
#            echo -e "${YELLOW}Please ensure the 'dash' directory with dashboard files exists.${NC}"
#            # Clean up the partial installation
#            run_silent "Cleaning up failed installation" "rm -rf \"${DASHBOARD_PATH}\""
#            return 1
#        fi
#    else
#        # User doesn't want dashboard - skip entirely
#        echo -e "${YELLOW}Dashboard installation skipped.${NC}"
#    fi
#}

# Main function
main() {
    set -e # Exit on error
    
    check_root
    display_header
    
    echo -e "This script will install and configure a VEIN dedicated server."
    echo -e "It will perform the following steps:"
    echo -e "  1. Install required dependencies"
    echo -e "  2. Configure firewall rules"
    echo -e "  3. Create a steam user"
    echo -e "  4. Install SteamCMD"
    echo -e "  5. Download and install the VEIN server"
    echo -e "  6. Configure server settings"
    echo -e "  7. Set up a systemd service"
#    echo -e "  8. Optionally install a dashboard"
    echo ""
    echo -e "Press ${BOLD}ENTER${NC} to begin or ${BOLD}CTRL+C${NC} to cancel..."
    read -r
    
    configure_server
    
    # Confirmation
    display_header
    echo -e "${YELLOW}Please review your settings:${NC}"
    echo ""
    echo -e "   ${BOLD}Server Name:${NC} ${SERVER_NAME}"
    echo -e "   ${BOLD}Public:${NC} ${PUBLIC}"
    echo -e "   ${BOLD}Max Players:${NC} ${MAX_PLAYERS}"
    echo -e "   ${BOLD}Password Protected:${NC} $([ -n "${PASSWORD}" ] && echo "Yes" || echo "No")"
    echo -e "   ${BOLD}Game Port:${NC} ${PORT}"
    echo -e "   ${BOLD}Query Port:${NC} ${QUERY_PORT}"
    echo -e "   ${BOLD}Auto Update:${NC} ${AUTO_UPDATE}"
    echo -e "   ${BOLD}Auto Restart:${NC} ${AUTO_RESTART}"
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
    configure_firewall
    create_steam_user
    install_steamcmd
    install_vein_server
    create_server_config
    create_systemd_service
#    install_dashboard
    display_completion
}

# Execute main function
main
