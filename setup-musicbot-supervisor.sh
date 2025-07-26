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

# Auto-detect music bot directories
detect_bot_directories() {
    print_info "Auto-detecting music bot directories..."
    
    local bot_dirs=()
    local search_paths=("/root" "/home")
    
    for search_path in "${search_paths[@]}"; do
        if [[ -d "$search_path" ]]; then
            # Look for directories with .venv and AnonXMusic or similar patterns
            while IFS= read -r -d '' dir; do
                local dirname=$(basename "$dir")
                if [[ -d "$dir/.venv" ]] && [[ -f "$dir/.env" || -d "$dir/AnonXMusic" || -f "$dir/requirements.txt" ]]; then
                    bot_dirs+=("$dirname:$dir")
                    print_success "Found bot directory: $dirname -> $dir"
                fi
            done < <(find "$search_path" -maxdepth 1 -type d -print0 2>/dev/null)
        fi
    done
    
    if [[ ${#bot_dirs[@]} -eq 0 ]]; then
        print_warning "No music bot directories auto-detected"
        return 1
    fi
    
    # Store detected bots for later use
    printf '%s\n' "${bot_dirs[@]}" > /tmp/detected_bots.list
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
            echo "${memory}MB"
            if (( $(echo "$memory > 500" | bc -l) )); then
                return 1
            fi
        else
            echo "N/A"
        fi
    else
        echo "N/A"
    fi
    return 0
}

check_bot_errors() {
    local bot_name=$1
    local log_name=$(echo "$bot_name" | sed 's/musicbots://')
    local log_file="/var/log/supervisor/${log_name}.log"
    
    if [ -f "$log_file" ]; then
        local error_count=$(tail -100 "$log_file" 2>/dev/null | grep -c -i "error\|exception\|traceback" || echo "0")
        echo "$error_count"
        
        if [ "$error_count" -gt 10 ]; then
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
    local memory=$(check_bot_memory "$bot_name")
    local errors=$(check_bot_errors "$bot_name")
    
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
    
    if [ "$memory" != "N/A" ]; then
        if check_bot_memory "$bot_name"; then
            print_info "Memory: $memory"
        else
            print_warning "Memory: $memory (HIGH!)"
        fi
    else
        print_warning "Memory: $memory"
    fi
    
    if [ "$errors" -gt 10 ]; then
        print_warning "Recent errors: $errors (HIGH!)"
    else
        print_info "Recent errors: $errors"
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
        print_info "Using auto-detected bot configurations"
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
