#!/usr/bin/env bash

# VEIN Server Backup Manager
# This script manages backups of VEIN server save games with a TUI interface

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Default variables
SAVE_DIR="/home/steam/Steam/vein-server/Vein/Saved/SaveGames"
BACKUP_DIR="/home/steam/vein-server-backups"
CURRENT_USER=$(whoami)
CRON_BACKUP_FILE="/etc/cron.d/vein-server-backup"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Function to display header
display_header() {
    clear
    echo -e "${BOLD}${BLUE}=======================================${NC}"
    echo -e "${BOLD}${BLUE}     VEIN Server Backup Manager        ${NC}"
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

# Check if running as root
check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        echo -e "${RED}Error: Please run as root (e.g., sudo $0)${NC}"
        exit 1
    fi
}

# Create backup directory if it doesn't exist
ensure_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        run_silent "Creating backup directory" "mkdir -p '$BACKUP_DIR'"
        run_silent "Setting backup directory permissions" "chown steam:steam '$BACKUP_DIR'"
    fi
}

# Function to create a backup
create_backup() {
    local backup_name=$1
    local override=$2
    local backup_file="${BACKUP_DIR}/${backup_name}.tar.gz"
    
    # Check if file exists and override is not set
    if [ -f "$backup_file" ] && [ "$override" != "true" ]; then
        echo -e "${RED}Backup file already exists. Use override option or choose a different name.${NC}"
        return 1
    fi
    
    # Check if save directory exists
    if [ ! -d "$SAVE_DIR" ]; then
        echo -e "${RED}Save directory $SAVE_DIR not found.${NC}"
        return 1
    fi
    
    # Create backup
    echo -e "${YELLOW}Creating backup... This may take a while for large save files.${NC}"
    
    if tar -czf "$backup_file" -C "$(dirname "$SAVE_DIR")" "$(basename "$SAVE_DIR")" > /dev/null 2>&1; then
        run_silent "Setting backup file permissions" "chown steam:steam '$backup_file'"
        echo -e "${GREEN}Backup created successfully: $backup_file${NC}"
        return 0
    else
        echo -e "${RED}Failed to create backup.${NC}"
        return 1
    fi
}

# Function to list available backups
list_backups() {
    section_header "Available Backups"
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        echo -e "   ${YELLOW}No backups found.${NC}"
        return 1
    fi
    
    echo -e "   ${BOLD}Backup files in ${BACKUP_DIR}:${NC}"
    echo ""
    
    local count=1
    local backup_files=()
    
    while IFS= read -r file; do
        backup_files+=("$file")
        local file_size=$(du -h "$file" | cut -f1)
        local file_date=$(date -r "$file" "+%Y-%m-%d %H:%M:%S")
        echo -e "   ${BOLD}[$count]${NC} $(basename "$file" .tar.gz)"
        echo -e "       Size: $file_size | Date: $file_date"
        ((count++))
    done < <(find "$BACKUP_DIR" -name "*.tar.gz" -type f | sort -r)
    
    # Return the array of backup files
    if [ ${#backup_files[@]} -gt 0 ]; then
        export backup_files
        return 0
    else
        return 1
    fi
}

# Function to restore a backup
restore_backup() {
    local backup_file=$1
    
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}Backup file not found: $backup_file${NC}"
        return 1
    fi
    
    # Stop the server if it's running
    if systemctl is-active --quiet vein-server.service; then
        echo -e "${YELLOW}VEIN server is running. Stopping before restore...${NC}"
        run_silent "Stopping VEIN server" "systemctl stop vein-server.service"
    fi
    
    # Create backup of current save if it exists
    if [ -d "$SAVE_DIR" ]; then
        echo -e "${YELLOW}Creating backup of current save before restore...${NC}"
        local pre_restore_backup="${BACKUP_DIR}/pre_restore_${TIMESTAMP}.tar.gz"
        if tar -czf "$pre_restore_backup" -C "$(dirname "$SAVE_DIR")" "$(basename "$SAVE_DIR")" > /dev/null 2>&1; then
            run_silent "Setting pre-restore backup permissions" "chown steam:steam '$pre_restore_backup'"
            echo -e "${GREEN}Pre-restore backup created: $pre_restore_backup${NC}"
        else
            echo -e "${RED}Failed to create pre-restore backup. Continuing anyway...${NC}"
        fi
    fi
    
    # Remove existing save directory
    if [ -d "$SAVE_DIR" ]; then
        run_silent "Removing current save directory" "rm -rf '$SAVE_DIR'"
    fi
    
    # Create parent directory if it doesn't exist
    run_silent "Ensuring parent directory exists" "mkdir -p '$(dirname "$SAVE_DIR")'"
    
    # Restore from backup
    echo -e "${YELLOW}Restoring from backup... This may take a while.${NC}"
    
    if tar -xzf "$backup_file" -C "$(dirname "$SAVE_DIR")" > /dev/null 2>&1; then
        run_silent "Setting restored files permissions" "chown -R steam:steam '$(dirname "$SAVE_DIR")'"
        echo -e "${GREEN}Restore completed successfully!${NC}"
        
        # Start the server if it was running before
        if systemctl is-enabled --quiet vein-server.service; then
            echo -e "${YELLOW}Starting VEIN server...${NC}"
            run_silent "Starting VEIN server" "systemctl start vein-server.service"
        fi
        
        return 0
    else
        echo -e "${RED}Failed to restore from backup.${NC}"
        return 1
    fi
}

# Function to set up automatic backups
setup_auto_backup() {
    local interval=$1  # 6 or 24
    local auto_backup_script="/usr/local/bin/vein-server-auto-backup.sh"
    
    # Create the auto-backup script
    cat > "$auto_backup_script" <<EOF
#!/bin/bash
# Automatic backup script for VEIN server

# Check if server is running
if systemctl is-active --quiet vein-server.service; then
    # Create timestamp for log
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting automatic backup" >> ${BACKUP_DIR}/backup.log
    
    # Create backup
    tar -czf "${BACKUP_DIR}/auto_backup.tar.gz" -C "$(dirname "$SAVE_DIR")" "$(basename "$SAVE_DIR")" >> ${BACKUP_DIR}/backup.log 2>&1
    
    # Set proper permissions
    chown steam:steam "${BACKUP_DIR}/auto_backup.tar.gz"
    chown steam:steam "${BACKUP_DIR}/backup.log"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Automatic backup completed" >> ${BACKUP_DIR}/backup.log
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Server not running, skipping backup" >> ${BACKUP_DIR}/backup.log
fi
EOF
    
    # Make the script executable
    run_silent "Creating automatic backup script" "chmod +x '$auto_backup_script'"
    
    # Create cron job
    if [ "$interval" == "6" ]; then
        # Every 6 hours
        cat > "$CRON_BACKUP_FILE" <<EOF
# VEIN Server automatic backup - every 6 hours
0 */6 * * * root $auto_backup_script
EOF
    else
        # Every 24 hours
        cat > "$CRON_BACKUP_FILE" <<EOF
# VEIN Server automatic backup - every 24 hours
0 0 * * * root $auto_backup_script
EOF
    fi
    
    run_silent "Setting up cron job" "chmod 644 '$CRON_BACKUP_FILE'"
    
    echo -e "${GREEN}Automatic backups configured to run every $interval hours.${NC}"
    echo -e "${YELLOW}Backups will be saved to: ${BACKUP_DIR}/auto_backup.tar.gz${NC}"
}

# Function to disable automatic backups
disable_auto_backup() {
    if [ -f "$CRON_BACKUP_FILE" ]; then
        run_silent "Removing cron job" "rm -f '$CRON_BACKUP_FILE'"
        echo -e "${GREEN}Automatic backups disabled.${NC}"
    else
        echo -e "${YELLOW}Automatic backups were not enabled.${NC}"
    fi
}

# Function to show automatic backup status
show_auto_backup_status() {
    if [ -f "$CRON_BACKUP_FILE" ]; then
        local interval=$(grep -q "*/6" "$CRON_BACKUP_FILE" && echo "6" || echo "24")
        echo -e "${GREEN}Automatic backups are enabled (every $interval hours).${NC}"
        echo -e "${YELLOW}Backup file: ${BACKUP_DIR}/auto_backup.tar.gz${NC}"
        
        # Check if an automatic backup exists
        if [ -f "${BACKUP_DIR}/auto_backup.tar.gz" ]; then
            local file_size=$(du -h "${BACKUP_DIR}/auto_backup.tar.gz" | cut -f1)
            local file_date=$(date -r "${BACKUP_DIR}/auto_backup.tar.gz" "+%Y-%m-%d %H:%M:%S")
            echo -e "${YELLOW}Last backup: $file_date ($file_size)${NC}"
        else
            echo -e "${YELLOW}No automatic backup has been created yet.${NC}"
        fi
    else
        echo -e "${YELLOW}Automatic backups are disabled.${NC}"
    fi
}

# Function to configure backup settings
configure_backup_settings() {
    display_header
    section_header "Backup Settings"
    
    echo -e "Please configure your backup settings:"
    echo ""
    
    # Backup directory
    read -p "$(echo -e "${BOLD}Backup directory${NC} [${BACKUP_DIR}]: ")" input
    BACKUP_DIR=${input:-"$BACKUP_DIR"}
    
    # Save directory
    read -p "$(echo -e "${BOLD}Save directory${NC} [${SAVE_DIR}]: ")" input
    SAVE_DIR=${input:-"$SAVE_DIR"}
    
    # Ensure backup directory exists
    ensure_backup_dir
    
    echo -e "${GREEN}Settings updated.${NC}"
}

# Function for manual backup
perform_manual_backup() {
    display_header
    section_header "Manual Backup"
    
    # Get backup name
    read -p "$(echo -e "${BOLD}Backup name${NC} [backup_${TIMESTAMP}]: ")" backup_name
    backup_name=${backup_name:-"backup_${TIMESTAMP}"}
    
    # Check if backup exists
    if [ -f "${BACKUP_DIR}/${backup_name}.tar.gz" ]; then
        read -p "$(echo -e "${BOLD}Backup already exists. Override?${NC} (y/n): ")" override
        if [[ "$override" =~ ^[Yy]$ ]]; then
            create_backup "$backup_name" "true"
        else
            echo -e "${YELLOW}Backup canceled.${NC}"
        fi
    else
        create_backup "$backup_name" "false"
    fi
    
    echo -e "${YELLOW}Press Enter to return to the main menu...${NC}"
    read
}

# Function for backup restoration
perform_restore() {
    display_header
    section_header "Restore Backup"
    
    # List all backups
    if list_backups; then
        echo ""
        read -p "$(echo -e "${BOLD}Select backup to restore [number]${NC} (0 to cancel): ")" selection
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#backup_files[@]} ]; then
            local selected_file="${backup_files[$((selection-1))]}"
            
            echo -e "${YELLOW}You selected: $(basename "$selected_file" .tar.gz)${NC}"
            read -p "$(echo -e "${BOLD}Are you sure you want to restore this backup?${NC} (y/n): ")" confirm
            
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                restore_backup "$selected_file"
            else
                echo -e "${YELLOW}Restore canceled.${NC}"
            fi
        elif [ "$selection" == "0" ]; then
            echo -e "${YELLOW}Restore canceled.${NC}"
        else
            echo -e "${RED}Invalid selection.${NC}"
        fi
    fi
    
    echo -e "${YELLOW}Press Enter to return to the main menu...${NC}"
    read
}

# Function to manage automatic backups
manage_auto_backups() {
    while true; do
        display_header
        section_header "Automatic Backup Management"
        
        echo -e "Current status:"
        show_auto_backup_status
        echo ""
        
        echo -e "Please select an option:"
        echo -e "  ${BOLD}1.${NC} Enable automatic backups every 6 hours"
        echo -e "  ${BOLD}2.${NC} Enable automatic backups every 24 hours"
        echo -e "  ${BOLD}3.${NC} Disable automatic backups"
        echo -e "  ${BOLD}4.${NC} Return to main menu"
        echo ""
        
        read -p "$(echo -e "${BOLD}Select option${NC} [1-4]: ")" option
        
        case $option in
            1)
                setup_auto_backup "6"
                ;;
            2)
                setup_auto_backup "24"
                ;;
            3)
                disable_auto_backup
                ;;
            4)
                return
                ;;
            *)
                echo -e "${RED}Invalid option.${NC}"
                ;;
        esac
        
        echo -e "${YELLOW}Press Enter to continue...${NC}"
        read
    done
}

# Main menu function
main_menu() {
    while true; do
        display_header
        
        echo -e "Please select an option:"
        echo -e "  ${BOLD}1.${NC} Perform manual backup"
        echo -e "  ${BOLD}2.${NC} List available backups"
        echo -e "  ${BOLD}3.${NC} Restore from backup"
        echo -e "  ${BOLD}4.${NC} Manage automatic backups"
        echo -e "  ${BOLD}5.${NC} Configure backup settings"
        echo -e "  ${BOLD}6.${NC} Exit"
        echo ""
        
        read -p "$(echo -e "${BOLD}Select option${NC} [1-6]: ")" option
        
        case $option in
            1)
                perform_manual_backup
                ;;
            2)
                display_header
                section_header "Available Backups"
                list_backups
                echo -e "${YELLOW}Press Enter to return to the main menu...${NC}"
                read
                ;;
            3)
                perform_restore
                ;;
            4)
                manage_auto_backups
                ;;
            5)
                configure_backup_settings
                ;;
            6)
                echo -e "${GREEN}Exiting VEIN Server Backup Manager. Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Main function
main() {
    check_root
    ensure_backup_dir
    main_menu
}

# Execute main function
main
