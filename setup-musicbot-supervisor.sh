#!/bin/bash
# Music Bot Supervisor Setup Script
# One-click deployment for music bot supervision on any VPS
# Author: GitHub Copilot
# Version: 1.0

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_VERSION="1.0"
LOG_FILE="/tmp/musicbot-setup.log"
CONFIG_FILE="./bot-config.conf"

# Default settings
DEFAULT_BOT_MODULE="AnonXMusic"
DEFAULT_LOG_RETENTION_DAYS=7
DEFAULT_MONITOR_LOG_RETENTION_DAYS=30

print_header() {
    clear
    echo -e "${PURPLE}================================================${NC}"
    echo -e "${PURPLE}  🎵 MUSIC BOT SUPERVISOR SETUP v${SCRIPT_VERSION} 🎵  ${NC}"
    echo -e "${PURPLE}================================================${NC}"
    echo -e "${CYAN}  One-click deployment for music bot management${NC}"
    echo -e "${CYAN}  $(date)${NC}"
    echo -e "${PURPLE}================================================${NC}\n"
}

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo -e "$1"
}

print_success() {
    log "${GREEN}[✓] $1${NC}"
}

print_warning() {
    log "${YELLOW}[⚠️] $1${NC}"
}

print_error() {
    log "${RED}[✗] $1${NC}"
}

print_info() {
    log "${BLUE}[i] $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Check system compatibility
check_system() {
    print_info "Checking system compatibility..."
    
    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot determine OS version"
        exit 1
    fi
    
    . /etc/os-release
    
    case $ID in
        ubuntu|debian)
            print_success "Compatible OS detected: $PRETTY_NAME"
            ;;
        *)
            print_warning "Untested OS: $PRETTY_NAME (proceeding anyway)"
            ;;
    esac
}

# Install required packages
install_dependencies() {
    print_info "Installing required packages..."
    
    apt update > /dev/null 2>&1
    
    local packages=("supervisor" "bc" "curl" "wget")
    local missing_packages=()
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            missing_packages+=("$package")
        fi
    done
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        print_info "Installing missing packages: ${missing_packages[*]}"
        apt install -y "${missing_packages[@]}" > /dev/null 2>&1
        print_success "Packages installed successfully"
    else
        print_success "All required packages already installed"
    fi
}

# Check if supervisor is already configured and offer management options
check_existing_setup() {
    if [[ -f "/etc/supervisor/conf.d/musicbots.conf" ]] && systemctl is-active supervisor >/dev/null 2>&1; then
        print_info "Existing music bot supervisor setup detected!"
        
        echo -e "\n${CYAN}Current bot status:${NC}"
        supervisorctl status musicbots:* 2>/dev/null || echo "No bots currently configured"
        
        echo -e "\n${CYAN}Setup Management Options:${NC}"
        echo -e "  ${YELLOW}1${NC} - Add new bots to existing setup"
        echo -e "  ${YELLOW}2${NC} - Remove existing bots"
        echo -e "  ${YELLOW}3${NC} - Completely reinstall (remove all and start fresh)"
        echo -e "  ${YELLOW}4${NC} - Continue with current setup (no changes)"
        echo -e "  ${YELLOW}5${NC} - Exit"
        
        while true; do
            echo ""
            read -p "Your choice: " management_choice
            
            case "$management_choice" in
                "1")
                    print_info "Adding new bots to existing setup..."
                    return 0  # Continue with normal detection/setup
                    ;;
                "2")
                    manage_existing_bots
                    exit 0
                    ;;
                "3")
                    print_warning "Completely reinstalling supervisor setup..."
                    cleanup_existing_setup
                    return 0  # Continue with fresh setup
                    ;;
                "4")
                    print_info "Keeping current setup unchanged."
                    exit 0
                    ;;
                "5")
                    print_info "Exiting..."
                    exit 0
                    ;;
                *)
                    print_error "Invalid choice. Please enter 1, 2, 3, 4, or 5."
                    ;;
            esac
        done
    fi
    return 0  # No existing setup, continue normally
}

# Function to manage existing bots (add/remove)
manage_existing_bots() {
    print_info "Managing existing bots..."
    
    # Get current bots from supervisor config
    local current_bots=()
    if [[ -f "/etc/supervisor/conf.d/musicbots.conf" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^\[program:(.+)-musicbot\] ]]; then
                local bot_name="${BASH_REMATCH[1]}"
                current_bots+=("$bot_name")
            fi
        done < "/etc/supervisor/conf.d/musicbots.conf"
    fi
    
    if [[ ${#current_bots[@]} -eq 0 ]]; then
        print_warning "No bots found in current configuration"
        return
    fi
    
    echo -e "\n${CYAN}Current bots:${NC}"
    for i in "${!current_bots[@]}"; do
        local bot_name="${current_bots[$i]}"
        local status=$(supervisorctl status "musicbots:${bot_name}-musicbot" 2>/dev/null | awk '{print $2}' || echo "UNKNOWN")
        echo -e "${BLUE}[$((i+1))]${NC} $bot_name (Status: $status)"
    done
    
    echo -e "\n${CYAN}Remove bots:${NC}"
    echo -e "  ${YELLOW}1,2,3${NC} - Remove specific bots (comma-separated)"
    echo -e "  ${YELLOW}all${NC} - Remove all bots"
    echo -e "  ${YELLOW}cancel${NC} - Cancel and exit"
    
    while true; do
        echo ""
        read -p "Enter bots to remove: " remove_choice
        
        case "$remove_choice" in
            "all"|"ALL")
                print_warning "Removing all bots..."
                for bot_name in "${current_bots[@]}"; do
                    remove_bot_from_supervisor "$bot_name"
                done
                cleanup_supervisor_config
                print_success "All bots removed successfully!"
                break
                ;;
            "cancel"|"CANCEL"|"c"|"C")
                print_info "Operation cancelled"
                return
                ;;
            *[0-9]*)
                # Parse comma-separated numbers
                IFS=',' read -ra REMOVE_CHOICES <<< "$remove_choice"
                local bots_to_remove=()
                local valid=true
                
                for num in "${REMOVE_CHOICES[@]}"; do
                    # Remove spaces
                    num=$(echo "$num" | tr -d ' ')
                    if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le ${#current_bots[@]} ]]; then
                        bots_to_remove+=("${current_bots[$((num-1))]}")
                    else
                        print_error "Invalid choice: $num"
                        valid=false
                        break
                    fi
                done
                
                if [[ "$valid" == true ]] && [[ ${#bots_to_remove[@]} -gt 0 ]]; then
                    print_warning "Removing ${#bots_to_remove[@]} bot(s)..."
                    for bot_name in "${bots_to_remove[@]}"; do
                        remove_bot_from_supervisor "$bot_name"
                    done
                    
                    # Regenerate supervisor config and monitoring script
                    regenerate_configs_after_removal
                    print_success "Selected bots removed successfully!"
                    break
                fi
                ;;
            *)
                print_error "Invalid choice. Please enter specific numbers, 'all', or 'cancel'."
                ;;
        esac
    done
}

# Remove specific bot from supervisor
remove_bot_from_supervisor() {
    local bot_name="$1"
    print_info "Removing bot: $bot_name"
    
    # Stop the bot
    supervisorctl stop "musicbots:${bot_name}-musicbot" 2>/dev/null || true
    
    # Remove from supervisor
    supervisorctl remove "musicbots:${bot_name}-musicbot" 2>/dev/null || true
    
    print_success "Bot $bot_name removed from supervisor"
}

# Regenerate configs after bot removal
regenerate_configs_after_removal() {
    print_info "Regenerating configurations..."
    
    # Get remaining bots
    local remaining_bots=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^\[program:(.+)-musicbot\] ]]; then
            local bot_name="${BASH_REMATCH[1]}"
            # Check if bot still exists and is not being removed
            if supervisorctl status "musicbots:${bot_name}-musicbot" >/dev/null 2>&1; then
                # Find the directory for this bot
                local bot_dir=$(grep -A 20 "^\[program:${bot_name}-musicbot\]" /etc/supervisor/conf.d/musicbots.conf | grep "^directory=" | cut -d'=' -f2)
                if [[ -n "$bot_dir" ]] && [[ -d "$bot_dir" ]]; then
                    remaining_bots+=("${bot_name}:${bot_dir}")
                fi
            fi
        fi
    done < "/etc/supervisor/conf.d/musicbots.conf"
    
    if [[ ${#remaining_bots[@]} -gt 0 ]]; then
        # Create temp file with remaining bots
        printf '%s\n' "${remaining_bots[@]}" > /tmp/remaining_bots.list
        
        # Regenerate supervisor config
        generate_supervisor_config "/tmp/remaining_bots.list"
        
        # Regenerate monitoring script
        generate_monitoring_script "/tmp/remaining_bots.list"
        
        # Reload supervisor
        supervisorctl reread >/dev/null 2>&1
        supervisorctl update >/dev/null 2>&1
        
        rm -f /tmp/remaining_bots.list
    else
        cleanup_supervisor_config
    fi
}

# Cleanup supervisor configuration when no bots remain
cleanup_supervisor_config() {
    print_info "Cleaning up supervisor configuration..."
    
    # Stop all musicbots
    supervisorctl stop musicbots:* 2>/dev/null || true
    
    # Remove the config file
    rm -f /etc/supervisor/conf.d/musicbots.conf
    
    # Remove monitoring script
    rm -f /root/monitor_all_bots.sh
    
    # Reload supervisor
    supervisorctl reread >/dev/null 2>&1
    supervisorctl update >/dev/null 2>&1
    
    print_success "Supervisor configuration cleaned up"
}

# Cleanup existing setup completely
cleanup_existing_setup() {
    print_warning "Removing existing setup completely..."
    
    # Stop all bots
    supervisorctl stop musicbots:* 2>/dev/null || true
    
    # Remove supervisor config
    rm -f /etc/supervisor/conf.d/musicbots.conf
    
    # Remove monitoring script
    rm -f /root/monitor_all_bots.sh
    
    # Remove cron jobs
    (crontab -l 2>/dev/null | grep -v "musicbot\|monitor_all_bots") | crontab - 2>/dev/null || true
    
    # Reload supervisor
    supervisorctl reread >/dev/null 2>&1
    supervisorctl update >/dev/null 2>&1
    
    print_success "Existing setup removed completely"
}

# Auto-detect music bot directories with user selection
detect_bot_directories() {
    print_info "Auto-detecting music bot directories..."
    
    local potential_bots=()
    local search_paths=("/root" "/home")
    
    for search_path in "${search_paths[@]}"; do
        if [[ -d "$search_path" ]]; then
            # Look for directories with BOTH .venv AND .env (strict requirement)
            while IFS= read -r -d '' dir; do
                local dirname=$(basename "$dir")
                if [[ -d "$dir/.venv" ]] && [[ -f "$dir/.env" ]]; then
                    # Additional check: ensure .env is not empty and contains bot configuration
                    if [[ -s "$dir/.env" ]]; then
                        # Additional validation: check if .env contains essential bot config
                        if grep -q -E "(API_ID|BOT_TOKEN|SESSION|DATABASE)" "$dir/.env" 2>/dev/null; then
                            potential_bots+=("$dirname:$dir")
                            print_success "Found potential bot: $dirname -> $dir"
                        else
                            print_warning "Skipping $dirname: .env missing essential configuration"
                        fi
                    else
                        print_warning "Skipping $dirname: .env file is empty"
                    fi
                else
                    if [[ -d "$dir/.venv" ]] && [[ ! -f "$dir/.env" ]]; then
                        print_warning "Skipping $dirname: has .venv but missing .env file"
                    fi
                fi
            done < <(find "$search_path" -maxdepth 1 -type d -print0 2>/dev/null)
        fi
    done
    
    if [[ ${#potential_bots[@]} -eq 0 ]]; then
        print_warning "No valid music bot directories found"
        return 1
    fi
    
    # Let user select which bots to deploy
    if select_bots_for_deployment "${potential_bots[@]}"; then
        return 0
    else
        return 1
    fi
}

# Function to let user select which bots to deploy
select_bots_for_deployment() {
    local potential_bots=("$@")
    local selected_bots=()
    
    echo -e "\n${CYAN}🤖 Select bots to deploy:${NC}"
    echo -e "${YELLOW}Found ${#potential_bots[@]} potential bot(s). Choose which ones to deploy:${NC}\n"
    
    for i in "${!potential_bots[@]}"; do
        local bot_config="${potential_bots[$i]}"
        local bot_name=$(echo "$bot_config" | cut -d':' -f1)
        local bot_dir=$(echo "$bot_config" | cut -d':' -f2)
        
        echo -e "${BLUE}[$((i+1))]${NC} $bot_name (${bot_dir})"
        
        # Show .env validation status
        if grep -q -E "(API_ID|BOT_TOKEN)" "$bot_dir/.env" 2>/dev/null; then
            echo -e "    ${GREEN}✓ Configuration looks valid${NC}"
        else
            echo -e "    ${YELLOW}⚠ Configuration may be incomplete${NC}"
        fi
    done
    
    echo -e "\n${CYAN}Options:${NC}"
    echo -e "  ${YELLOW}a${NC} - Deploy ALL bots"
    echo -e "  ${YELLOW}1,2,3${NC} - Deploy specific bots (comma-separated)"
    echo -e "  ${YELLOW}n${NC} - Skip auto-detection, configure manually"
    
    while true; do
        echo ""
        read -p "Your choice: " choice
        
        case "$choice" in
            "a"|"A"|"all"|"ALL")
                selected_bots=("${potential_bots[@]}")
                print_success "Selected all ${#selected_bots[@]} bots for deployment"
                break
                ;;
            "n"|"N"|"none"|"NONE")
                print_info "Skipping auto-detection. Use --interactive for manual configuration."
                return 1
                ;;
            *[0-9]*)
                # Parse comma-separated numbers
                IFS=',' read -ra CHOICES <<< "$choice"
                selected_bots=()
                local valid=true
                
                for num in "${CHOICES[@]}"; do
                    # Remove spaces
                    num=$(echo "$num" | tr -d ' ')
                    if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le ${#potential_bots[@]} ]]; then
                        selected_bots+=("${potential_bots[$((num-1))]}")
                    else
                        print_error "Invalid choice: $num"
                        valid=false
                        break
                    fi
                done
                
                if [[ "$valid" == true ]] && [[ ${#selected_bots[@]} -gt 0 ]]; then
                    print_success "Selected ${#selected_bots[@]} bot(s) for deployment"
                    break
                fi
                ;;
            *)
                print_error "Invalid choice. Please enter 'a' for all, specific numbers, or 'n' for none."
                ;;
        esac
    done
    
    if [[ ${#selected_bots[@]} -eq 0 ]]; then
        print_warning "No bots selected for deployment"
        return 1
    fi
    
    # Store selected bots for later use
    printf '%s\n' "${selected_bots[@]}" > /tmp/detected_bots.list
    return 0
}

# Interactive bot configuration
configure_bots_interactive() {
    print_info "Interactive bot configuration..."
    
    local bots=()
    echo -e "${CYAN}Enter your music bot configurations:${NC}"
    echo -e "${YELLOW}Format: bot_name:directory_path${NC}"
    echo -e "${YELLOW}Example: amiop:/root/amiop${NC}"
    echo -e "${YELLOW}Enter empty line to finish${NC}\n"
    
    while true; do
        read -p "Bot configuration: " bot_config
        if [[ -z "$bot_config" ]]; then
            break
        fi
        
        if [[ "$bot_config" =~ ^[a-zA-Z0-9_-]+:.+$ ]]; then
            local bot_name=$(echo "$bot_config" | cut -d':' -f1)
            local bot_dir=$(echo "$bot_config" | cut -d':' -f2)
            
            if [[ -d "$bot_dir" ]]; then
                bots+=("$bot_config")
                print_success "Added: $bot_name -> $bot_dir"
            else
                print_error "Directory not found: $bot_dir"
            fi
        else
            print_error "Invalid format. Use: bot_name:directory_path"
        fi
    done
    
    if [[ ${#bots[@]} -eq 0 ]]; then
        print_error "No valid bot configurations provided"
        return 1
    fi
    
    printf '%s\n' "${bots[@]}" > /tmp/configured_bots.list
    return 0
}

# Load configuration from file
load_config_file() {
    if [[ -f "$CONFIG_FILE" ]]; then
        print_info "Loading configuration from $CONFIG_FILE"
        source "$CONFIG_FILE"
        
        if [[ -n "${BOTS[@]}" ]]; then
            printf '%s\n' "${BOTS[@]}" > /tmp/configured_bots.list
            print_success "Configuration loaded successfully"
            return 0
        fi
    fi
    return 1
}

# Generate supervisor configuration
generate_supervisor_config() {
    local bot_list_file="$1"
    print_info "Generating supervisor configuration..."
    
    local config_file="/etc/supervisor/conf.d/musicbots.conf"
    local bot_names=()
    local bot_configs=""
    local priority=100
    
    # Create group section
    while IFS= read -r bot_config; do
        local bot_name=$(echo "$bot_config" | cut -d':' -f1)
        bot_names+=("${bot_name}-musicbot")
    done < "$bot_list_file"
    
    local group_programs=$(IFS=,; echo "${bot_names[*]}")
    
    cat > "$config_file" << EOF
[group:musicbots]
programs=$group_programs

EOF
    
    # Create individual bot configurations
    while IFS= read -r bot_config; do
        local bot_name=$(echo "$bot_config" | cut -d':' -f1)
        local bot_dir=$(echo "$bot_config" | cut -d':' -f2)
        local module_name="${BOT_MODULE:-$DEFAULT_BOT_MODULE}"
        
        cat >> "$config_file" << EOF
[program:${bot_name}-musicbot]
command=$bot_dir/.venv/bin/python -m $module_name
directory=$bot_dir
user=root
autostart=true
autorestart=true
startretries=3
redirect_stderr=true
stdout_logfile=/var/log/supervisor/${bot_name}-musicbot.log
stdout_logfile_maxbytes=50MB
stdout_logfile_backups=10
environment=PATH="$bot_dir/.venv/bin:/usr/bin:/usr/local/bin",PYTHONPATH="$bot_dir"
stopwaitsecs=10
killasgroup=true
stopasgroup=true
priority=$priority

EOF
        ((priority++))
    done < "$bot_list_file"
    
    print_success "Supervisor configuration generated: $config_file"
}

# Generate monitoring script
generate_monitoring_script() {
    local bot_list_file="$1"
    local script_path="/root/monitor_all_bots.sh"
    
    print_info "Generating monitoring script..."
    
    # Build bot arrays for the script
    local bots_declare="declare -A BOTS=("
    local display_names_declare="declare -A BOT_DISPLAY_NAMES=("
    
    while IFS= read -r bot_config; do
        local bot_name=$(echo "$bot_config" | cut -d':' -f1)
        local bot_dir=$(echo "$bot_config" | cut -d':' -f2)
        local display_name=$(echo "$bot_name" | sed 's/./\U&/' | sed 's/.*/& Music Bot/')
        
        bots_declare+="\n    [\"musicbots:${bot_name}-musicbot\"]=\"$bot_dir\""
    done < "$bot_list_file"
    bots_declare+="\n)"
    
    while IFS= read -r bot_config; do
        local bot_name=$(echo "$bot_config" | cut -d':' -f1)
        local display_name=$(echo "$bot_name" | sed 's/./\U&/' | sed 's/.*/& Music Bot/')
        
        display_names_declare+="\n    [\"musicbots:${bot_name}-musicbot\"]=\"$display_name\""
    done < "$bot_list_file"
    display_names_declare+="\n)"
    
    # Generate the complete monitoring script
    cat > "$script_path" << 'MONITORING_SCRIPT_EOF'
#!/bin/bash
# Auto-generated monitoring script

MONITORING_SCRIPT_EOF
    
    echo -e "$bots_declare" >> "$script_path"
    echo "" >> "$script_path"
    echo -e "$display_names_declare" >> "$script_path"
    
    # Add the rest of the monitoring script functionality
    cat >> "$script_path" << 'MONITORING_SCRIPT_EOF'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}    MUSIC BOTS MONITORING       ${NC}"
    echo -e "${PURPLE}    $(date)    ${NC}"
    echo -e "${PURPLE}================================${NC}"
}

print_status() {
    echo -e "${GREEN}[✓] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[⚠️] $1${NC}"
}

print_error() {
    echo -e "${RED}[✗] $1${NC}"
}

print_info() {
    echo -e "${BLUE}[i] $1${NC}"
}

get_bot_status() {
    local bot_name=$1
    sudo supervisorctl status "$bot_name" 2>/dev/null | awk '{print $2}' || echo "UNKNOWN"
}

get_bot_pid() {
    local bot_name=$1
    sudo supervisorctl status "$bot_name" 2>/dev/null | grep -o 'pid [0-9]*' | cut -d' ' -f2
}

get_bot_uptime() {
    local bot_name=$1
    sudo supervisorctl status "$bot_name" 2>/dev/null | grep -o 'uptime [^,]*' | sed 's/uptime //' || echo "N/A"
}

check_bot_memory() {
    local bot_name=$1
    local pid=$(get_bot_pid "$bot_name")
    
    if [ ! -z "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        local memory=$(ps -p "$pid" -o rss= 2>/dev/null | awk '{print $1/1024}')
        if [ ! -z "$memory" ]; then
            printf "%.1f" "$memory"
        else
            echo "N/A"
            return 2
        fi
    else
        echo "N/A"
        return 2
    fi
    
    # Return status based on memory usage
    if (( $(echo "$memory > 500" | bc -l) )); then
        return 1  # High memory
    else
        return 0  # Normal memory
    fi
}

check_bot_errors() {
    local bot_name=$1
    local log_name=$(echo "$bot_name" | sed 's/musicbots://')
    local log_file="/var/log/supervisor/${log_name}.log"
    
    if [ -f "$log_file" ]; then
        local error_count=$(tail -100 "$log_file" 2>/dev/null | grep -c -i "error\|exception\|traceback" 2>/dev/null || echo "0")
        # Clean the error count to ensure it's just a number
        error_count=$(echo "$error_count" | tr -d '\n\r' | grep -o '[0-9]*' | head -1)
        [ -z "$error_count" ] && error_count="0"
        echo "$error_count"
        
        if [ "$error_count" -gt 10 ] 2>/dev/null; then
            return 1
        fi
    else
        echo "0"
    fi
    return 0
}

monitor_single_bot() {
    local bot_name=$1
    local bot_dir=$2
    local display_name=${BOT_DISPLAY_NAMES[$bot_name]}
    
    echo -e "\n${CYAN}--- $display_name ---${NC}"
    
    local status=$(get_bot_status "$bot_name")
    local uptime=$(get_bot_uptime "$bot_name")
    
    case $status in
        "RUNNING")
            print_status "Status: RUNNING (uptime: $uptime)"
            ;;
        "STOPPED")
            print_error "Status: STOPPED"
            ;;
        "FATAL")
            print_error "Status: FATAL"
            ;;
        *)
            print_warning "Status: $status"
            ;;
    esac
    
    # Memory check
    local memory_result
    memory_result=$(check_bot_memory "$bot_name")
    local memory_status=$?
    
    if [ "$memory_result" != "N/A" ]; then
        if [ $memory_status -eq 0 ]; then
            print_info "Memory: ${memory_result}MB"
        elif [ $memory_status -eq 1 ]; then
            print_warning "Memory: ${memory_result}MB (HIGH!)"
        else
            print_warning "Memory: $memory_result"
        fi
    else
        print_warning "Memory: $memory_result"
    fi
    
    # Error check
    local error_result
    error_result=$(check_bot_errors "$bot_name")
    local error_status=$?
    
    if [ $error_status -eq 1 ]; then
        print_warning "Recent errors: $error_result (HIGH!)"
    else
        print_info "Recent errors: $error_result"
    fi
    
    if [ -d "$bot_dir" ]; then
        print_info "Directory: $bot_dir ✓"
    else
        print_error "Directory: $bot_dir (NOT FOUND!)"
    fi
    
    print_info "Process: $bot_name"
}

show_summary() {
    echo -e "\n${PURPLE}=== SUMMARY ===${NC}"
    
    local running=0
    local stopped=0
    local fatal=0
    
    for bot_name in "${!BOTS[@]}"; do
        local status=$(get_bot_status "$bot_name")
        case $status in
            "RUNNING") ((running++)) ;;
            "STOPPED") ((stopped++)) ;;
            "FATAL") ((fatal++)) ;;
        esac
    done
    
    echo -e "Running: ${GREEN}$running${NC}"
    echo -e "Stopped: ${RED}$stopped${NC}"
    echo -e "Fatal: ${RED}$fatal${NC}"
    echo -e "Total: ${BLUE}${#BOTS[@]}${NC}"
}

restart_failed_bots() {
    echo -e "\n${YELLOW}Checking for failed bots...${NC}"
    
    for bot_name in "${!BOTS[@]}"; do
        local status=$(get_bot_status "$bot_name")
        local display_name=${BOT_DISPLAY_NAMES[$bot_name]}
        
        if [ "$status" = "STOPPED" ] || [ "$status" = "FATAL" ]; then
            print_warning "Restarting $display_name..."
            sudo supervisorctl restart "$bot_name" 2>/dev/null || print_error "Failed to restart $bot_name"
        fi
    done
}

show_recent_logs() {
    local bot_input=$1
    local lines=${2:-10}
    local bot_name=""
    local log_name=""
    
    # Find matching bot
    for name in "${!BOTS[@]}"; do
        local short_name=$(echo "$name" | sed 's/musicbots://' | sed 's/-musicbot//')
        if [[ "$short_name" == "$bot_input" ]] || [[ "$name" == "$bot_input" ]]; then
            bot_name="$name"
            log_name=$(echo "$name" | sed 's/musicbots://')
            break
        fi
    done
    
    if [[ -z "$bot_name" ]]; then
        echo "Unknown bot: $bot_input"
        echo "Available bots: $(for name in "${!BOTS[@]}"; do echo -n "$(echo "$name" | sed 's/musicbots://' | sed 's/-musicbot//') "; done)"
        return 1
    fi
    
    echo -e "\n${CYAN}=== Recent logs for ${BOT_DISPLAY_NAMES[$bot_name]} ===${NC}"
    local log_file="/var/log/supervisor/${log_name}.log"
    
    if [ -f "$log_file" ]; then
        tail -"$lines" "$log_file"
    else
        print_error "Log file not found: $log_file"
    fi
}

main() {
    print_header
    
    if ! pgrep supervisord > /dev/null; then
        print_error "Supervisor daemon is not running!"
        echo "Starting supervisor..."
        sudo systemctl start supervisor
        sleep 2
    fi
    
    for bot_name in "${!BOTS[@]}"; do
        monitor_single_bot "$bot_name" "${BOTS[$bot_name]}"
    done
    
    show_summary
    
    if [ "$1" = "auto-restart" ]; then
        restart_failed_bots
    fi
}

# Command line handling
case "$1" in
    "start")
        if [ -z "$2" ]; then
            sudo supervisorctl start musicbots:*
        elif [ "$2" = "all" ]; then
            sudo supervisorctl start musicbots:*
        else
            sudo supervisorctl start "musicbots:${2}-musicbot"
        fi
        ;;
    "stop")
        if [ -z "$2" ] || [ "$2" = "all" ]; then
            sudo supervisorctl stop musicbots:*
        else
            sudo supervisorctl stop "musicbots:${2}-musicbot"
        fi
        ;;
    "restart")
        if [ -z "$2" ] || [ "$2" = "all" ]; then
            sudo supervisorctl restart musicbots:*
        else
            sudo supervisorctl restart "musicbots:${2}-musicbot"
        fi
        ;;
    "status")
        sudo supervisorctl status musicbots:*
        ;;
    "logs")
        if [ -z "$2" ]; then
            echo "Usage: $0 logs <bot-name> [lines]"
            echo "Available bots: $(for name in "${!BOTS[@]}"; do echo -n "$(echo "$name" | sed 's/musicbots://' | sed 's/-musicbot//') "; done)"
        else
            show_recent_logs "$2" "$3"
        fi
        ;;
    "tail")
        if [ -z "$2" ]; then
            echo "Usage: $0 tail <bot-name>"
            echo "Available bots: $(for name in "${!BOTS[@]}"; do echo -n "$(echo "$name" | sed 's/musicbots://' | sed 's/-musicbot//') "; done)"
        else
            sudo supervisorctl tail -f "musicbots:${2}-musicbot"
        fi
        ;;
    "auto-restart")
        main auto-restart
        ;;
    "help")
        echo "Usage: $0 [command] [bot-name]"
        echo ""
        echo "Commands:"
        echo "  (no args)       - Show status of all bots"
        echo "  start [bot]     - Start bot or all bots"
        echo "  stop [bot]      - Stop bot or all bots"
        echo "  restart [bot]   - Restart bot or all bots"
        echo "  status          - Show supervisor status"
        echo "  logs <bot>      - Show recent logs"
        echo "  tail <bot>      - Follow logs in real-time"
        echo "  auto-restart    - Monitor and auto-restart failed bots"
        echo ""
        echo "Available bots: $(for name in "${!BOTS[@]}"; do echo -n "$(echo "$name" | sed 's/musicbots://' | sed 's/-musicbot//') "; done)"
        ;;
    *)
        main
        ;;
esac
MONITORING_SCRIPT_EOF
    
    chmod +x "$script_path"
    print_success "Monitoring script generated: $script_path"
}

# Setup cron jobs
setup_cron_jobs() {
    local bot_list_file="$1"
    print_info "Setting up cron jobs..."
    
    local retention_days="${LOG_RETENTION_DAYS:-$DEFAULT_LOG_RETENTION_DAYS}"
    local monitor_retention_days="${MONITOR_LOG_RETENTION_DAYS:-$DEFAULT_MONITOR_LOG_RETENTION_DAYS}"
    
    local crontab_content="# Music Bot Management Crontab Jobs

# Restart all bots at configured intervals
${RESTART_SCHEDULE:-0 0,6,12,18 * * *} /usr/bin/supervisorctl restart musicbots:* >> /var/log/bot_restart.log 2>&1

# Monitor all bots every hour and auto-restart failed ones
0 * * * * /root/monitor_all_bots.sh auto-restart >> /var/log/bot_monitor.log 2>&1

# Clean old supervisor logs weekly
0 0 * * 0 find /var/log/supervisor/ -name \"*musicbot*.log.*\" -mtime +$retention_days -delete

# Clean old monitoring logs monthly
0 1 1 * * find /var/log/ -name \"bot_*.log\" -mtime +$monitor_retention_days -delete
"
    
    # Backup existing crontab if it exists
    if crontab -l > /dev/null 2>&1; then
        crontab -l > /tmp/crontab_backup_$(date +%Y%m%d_%H%M%S)
        print_info "Existing crontab backed up"
    fi
    
    # Install new crontab
    echo "$crontab_content" | crontab -
    
    # Create log files
    touch /var/log/bot_restart.log /var/log/bot_monitor.log
    chmod 644 /var/log/bot_restart.log /var/log/bot_monitor.log
    
    print_success "Cron jobs configured successfully"
}

# Start and configure supervisor
setup_supervisor() {
    print_info "Configuring supervisor..."
    
    # Ensure supervisor directory exists
    mkdir -p /etc/supervisor/conf.d
    
    # Enable and start supervisor
    systemctl enable supervisor > /dev/null 2>&1 || true
    systemctl start supervisor
    
    # Reload supervisor configuration
    supervisorctl reread > /dev/null 2>&1
    supervisorctl update > /dev/null 2>&1
    
    sleep 2
    
    print_success "Supervisor configured and started"
}

# Kill existing tmux sessions
cleanup_existing_processes() {
    print_info "Cleaning up existing processes..."
    
    # Kill tmux sessions
    if command -v tmux >/dev/null 2>&1; then
        if tmux list-sessions >/dev/null 2>&1; then
            print_warning "Killing existing tmux sessions..."
            tmux kill-server 2>/dev/null || true
        fi
    fi
    
    # Kill existing music bot processes
    pkill -f "python.*AnonXMusic" 2>/dev/null || true
    pkill -f "python.*musicbot" 2>/dev/null || true
    
    sleep 2
    print_success "Cleanup completed"
}

# Generate setup summary
show_setup_summary() {
    local bot_list_file="$1"
    local bot_count=$(wc -l < "$bot_list_file")
    
    echo -e "\n${GREEN}================================================${NC}"
    echo -e "${GREEN}  🎉 SETUP COMPLETED SUCCESSFULLY! 🎉${NC}"
    echo -e "${GREEN}================================================${NC}"
    
    echo -e "\n${CYAN}📊 Setup Summary:${NC}"
    echo -e "  • Configured bots: ${YELLOW}$bot_count${NC}"
    echo -e "  • Supervisor: ${GREEN}✓ Running${NC}"
    echo -e "  • Monitoring: ${GREEN}✓ Enabled${NC}"
    echo -e "  • Cron jobs: ${GREEN}✓ Scheduled${NC}"
    echo -e "  • Log rotation: ${GREEN}✓ Configured${NC}"
    
    echo -e "\n${CYAN}🤖 Your Bots:${NC}"
    while IFS= read -r bot_config; do
        local bot_name=$(echo "$bot_config" | cut -d':' -f1)
        local bot_dir=$(echo "$bot_config" | cut -d':' -f2)
        echo -e "  • ${YELLOW}$bot_name${NC} -> $bot_dir"
    done < "$bot_list_file"
    
    echo -e "\n${CYAN}🔧 Quick Commands:${NC}"
    echo -e "  • Monitor all bots: ${YELLOW}/root/monitor_all_bots.sh${NC}"
    echo -e "  • Start all bots: ${YELLOW}/root/monitor_all_bots.sh start all${NC}"
    echo -e "  • Stop all bots: ${YELLOW}/root/monitor_all_bots.sh stop all${NC}"
    echo -e "  • View status: ${YELLOW}/root/monitor_all_bots.sh status${NC}"
    echo -e "  • View logs: ${YELLOW}/root/monitor_all_bots.sh logs <bot-name>${NC}"
    
    echo -e "\n${CYAN}📋 Log Files:${NC}"
    echo -e "  • Setup log: ${YELLOW}$LOG_FILE${NC}"
    echo -e "  • Bot restart log: ${YELLOW}/var/log/bot_restart.log${NC}"
    echo -e "  • Monitor log: ${YELLOW}/var/log/bot_monitor.log${NC}"
    
    echo -e "\n${GREEN}🚀 Your music bots are now running under supervisor!${NC}"
    echo -e "${GREEN}   They will automatically restart if they crash.${NC}\n"
}

# Main setup function
main_setup() {
    local bot_list_file=""
    
    print_header
    
    # Check prerequisites
    check_root
    check_system
    
    # Check for existing setup and offer management options
    check_existing_setup
    
    # Install dependencies
    install_dependencies
    
    # Cleanup existing processes
    cleanup_existing_processes
    
    # Determine configuration method
    if [[ "$1" == "--interactive" ]]; then
        configure_bots_interactive
        bot_list_file="/tmp/configured_bots.list"
    elif load_config_file; then
        bot_list_file="/tmp/configured_bots.list"
    elif detect_bot_directories; then
        bot_list_file="/tmp/detected_bots.list"
        print_info "Using selected bot configurations"
        echo -e "${YELLOW}If this is incorrect, run with --interactive or create bot-config.conf${NC}"
        sleep 3
    else
        print_error "No bot configurations found!"
        echo -e "${YELLOW}Options:${NC}"
        echo -e "  1. Run with --interactive: ${CYAN}$0 --interactive${NC}"
        echo -e "  2. Create bot-config.conf with your bot configurations"
        echo -e "  3. Ensure your bot directories are in /root with .venv folders"
        exit 1
    fi
    
    # Validate bot list
    if [[ ! -f "$bot_list_file" ]] || [[ ! -s "$bot_list_file" ]]; then
        print_error "No valid bot configurations found"
        exit 1
    fi
    
    # Generate configurations
    generate_supervisor_config "$bot_list_file"
    generate_monitoring_script "$bot_list_file"
    
    # Setup supervisor
    setup_supervisor
    
    # Setup cron jobs
    setup_cron_jobs "$bot_list_file"
    
    # Show final status
    sleep 2
    show_setup_summary "$bot_list_file"
    
    # Show current bot status
    echo -e "${CYAN}Current Bot Status:${NC}"
    supervisorctl status musicbots:* 2>/dev/null || print_warning "Some bots may still be starting..."
}

# Create config file template
create_config_template() {
    cat > "$CONFIG_FILE" << 'CONFIG_EOF'
#!/bin/bash
# Music Bot Configuration File
# Edit this file to customize your bot setup

# Bot configurations
# Format: "bot_name:directory_path"
BOTS=(
    "amiop:/root/amiop"
    "sri:/root/sri"
    # Add more bots here
    # "botname:/path/to/bot"
)

# Bot module name (usually AnonXMusic)
BOT_MODULE="AnonXMusic"

# Restart schedule (cron format)
# Default: Every 6 hours at 12 AM, 6 AM, 12 PM, 6 PM
RESTART_SCHEDULE="0 0,6,12,18 * * *"

# Log retention (days)
LOG_RETENTION_DAYS=7
MONITOR_LOG_RETENTION_DAYS=30
CONFIG_EOF
    
    echo -e "${GREEN}Configuration template created: $CONFIG_FILE${NC}"
    echo -e "${YELLOW}Edit this file and run the script again to use custom configuration${NC}"
}

# Script usage
show_usage() {
    echo -e "${CYAN}Usage:${NC}"
    echo -e "  $0                    - Auto-detect and setup"
    echo -e "  $0 --interactive      - Interactive configuration"
    echo -e "  $0 --create-config    - Create configuration template"
    echo -e "  $0 --help            - Show this help"
    echo ""
    echo -e "${CYAN}One-liner installation:${NC}"
    echo -e "  ${YELLOW}curl -sSL <script_url> | bash${NC}"
    echo ""
    echo -e "${CYAN}Custom configuration:${NC}"
    echo -e "  1. ${YELLOW}$0 --create-config${NC}"
    echo -e "  2. Edit bot-config.conf"
    echo -e "  3. ${YELLOW}$0${NC}"
}

# Script entry point
case "${1:-}" in
    "--interactive")
        main_setup --interactive
        ;;
    "--create-config")
        create_config_template
        ;;
    "--help"|"-h")
        print_header
        show_usage
        ;;
    "--version")
        echo "Music Bot Supervisor Setup v$SCRIPT_VERSION"
        ;;
    *)
        main_setup
        ;;
esac
