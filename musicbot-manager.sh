#!/bin/bash
# Music Bot All-in-One Manager
# Complete solution for deployment, management, and monitoring
# Author: GitHub Copilot
# Version: 2.0

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
SCRIPT_VERSION="2.0"
LOG_FILE="/tmp/musicbot-manager.log"
DEPLOY_BASE_DIR="/root"
SUPERVISOR_CONFIG_DIR="/etc/supervisor/conf.d"

# GitHub credentials for private repositories
GITHUB_USERNAME=""
GITHUB_PASSWORD=""

print_header() {
    clear
    echo -e "${PURPLE}======================================================${NC}"
    echo -e "${PURPLE}  🎵 MUSIC BOT ALL-IN-ONE MANAGER v${SCRIPT_VERSION} 🎵  ${NC}"
    echo -e "${PURPLE}======================================================${NC}"
    echo -e "${CYAN}  Complete solution for bot deployment & management${NC}"
    echo -e "${CYAN}  $(date)${NC}"
    echo -e "${PURPLE}======================================================${NC}\n"
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

print_progress() {
    echo -e "${CYAN}[→] $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Main menu
show_main_menu() {
    print_header
    echo -e "${CYAN}🚀 Select an option:${NC}\n"
    
    echo -e "${YELLOW}1.${NC} ${GREEN}New VPS Setup${NC} - Complete VPS setup with system dependencies"
    echo -e "${YELLOW}2.${NC} ${GREEN}Deploy Single Bot${NC} - Interactive deployment of one bot"
    echo -e "${YELLOW}3.${NC} ${GREEN}Batch Deploy Bots${NC} - Deploy multiple bots from config file"
    echo -e "${YELLOW}4.${NC} ${GREEN}Create Config Template${NC} - Generate batch deployment config"
    echo -e "${YELLOW}5.${NC} ${GREEN}Supervisor Management${NC} - Manage bot supervisor services"
    echo -e "${YELLOW}6.${NC} ${GREEN}Monitor Bots${NC} - View bot status and monitoring dashboard"
    echo -e "${YELLOW}7.${NC} ${GREEN}Bot Management${NC} - Start/stop/restart individual bots"
    echo -e "${YELLOW}8.${NC} ${GREEN}System Info${NC} - Show deployment summary and system status"
    echo -e "${YELLOW}9.${NC} ${GREEN}Exit${NC} - Exit the manager"
    
    echo -e "\n${CYAN}Enter your choice (1-9):${NC} "
    read -r choice
    
    case $choice in
        1) new_vps_setup_menu ;;
        2) deploy_single_bot_menu ;;
        3) batch_deploy_menu ;;
        4) create_config_template ;;
        5) supervisor_management_menu ;;
        6) monitor_bots_menu ;;
        7) bot_management_menu ;;
        8) system_info_menu ;;
        9) exit_manager ;;
        *) 
            print_error "Invalid choice. Please select 1-9."
            sleep 2
            show_main_menu
            ;;
    esac
}

# Setup system dependencies for new VPS
setup_new_vps() {
    print_info "Setting up new VPS with required dependencies..."
    
    # Update system
    print_progress "Updating system packages..."
    apt-get update > /dev/null 2>&1
    print_success "System packages updated"
    
    print_progress "Upgrading system packages..."
    apt-get upgrade -y > /dev/null 2>&1
    print_success "System packages upgraded"
    
    # Install required packages
    local packages=("python3-pip" "python3-venv" "python3-dev" "ffmpeg" "git" "curl" "wget" "build-essential" "supervisor" "bc" "htop" "nano" "screen")
    local missing_packages=()
    
    print_progress "Checking required packages..."
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            missing_packages+=("$package")
        fi
    done
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        print_progress "Installing missing packages: ${missing_packages[*]}"
        apt-get install -y "${missing_packages[@]}" > /dev/null 2>&1
        print_success "Required packages installed"
    else
        print_success "All required packages already installed"
    fi
    
    # Upgrade pip
    print_progress "Upgrading pip..."
    python3 -m pip install --upgrade pip > /dev/null 2>&1
    print_success "Pip upgraded successfully"
    
    # Setup supervisor
    print_progress "Configuring supervisor..."
    systemctl enable supervisor > /dev/null 2>&1
    systemctl start supervisor > /dev/null 2>&1
    print_success "Supervisor configured and started"
    
    print_success "VPS setup completed successfully!"
}

# Validate bot repository
validate_repo() {
    local repo_url="$1"
    print_progress "Validating repository: $repo_url"
    
    if git ls-remote "$repo_url" >/dev/null 2>&1; then
        print_success "Repository is accessible"
        return 0
    else
        print_error "Repository is not accessible or doesn't exist"
        return 1
    fi
}

# Clone bot repository
clone_bot_repo() {
    local bot_name="$1"
    local repo_url="$2"
    local branch="${3:-main}"
    local bot_dir="$DEPLOY_BASE_DIR/$bot_name"
    
    print_progress "Cloning $bot_name from $repo_url (branch: $branch)..."
    
    # Remove existing directory if it exists
    if [[ -d "$bot_dir" ]]; then
        print_warning "Directory $bot_dir already exists. Removing..."
        rm -rf "$bot_dir"
    fi
    
    # Prepare repository URL with credentials if provided
    local clone_url="$repo_url"
    if [[ -n "$GITHUB_USERNAME" && -n "$GITHUB_PASSWORD" && "$repo_url" =~ github\.com ]]; then
        clone_url=$(echo "$repo_url" | sed "s|https://github.com|https://${GITHUB_USERNAME}:${GITHUB_PASSWORD}@github.com|")
        print_info "Using GitHub credentials for private repository"
    fi
    
    # Clone repository
    if git clone -b "$branch" "$clone_url" "$bot_dir" > /dev/null 2>&1; then
        print_success "Repository cloned successfully to $bot_dir"
        return 0
    else
        # Try with master branch if main fails
        if [[ "$branch" == "main" ]]; then
            print_warning "Main branch failed, trying master branch..."
            if git clone -b "master" "$clone_url" "$bot_dir" > /dev/null 2>&1; then
                print_success "Repository cloned successfully to $bot_dir (master branch)"
                return 0
            fi
        fi
        print_error "Failed to clone repository"
        return 1
    fi
}

# Setup virtual environment
setup_virtual_env() {
    local bot_dir="$1"
    local bot_name="$2"
    
    print_progress "Setting up virtual environment for $bot_name..."
    
    cd "$bot_dir"
    
    # Create virtual environment
    if python3 -m venv .venv > /dev/null 2>&1; then
        print_success "Virtual environment created"
    else
        print_error "Failed to create virtual environment"
        return 1
    fi
    
    # Activate and upgrade pip
    source .venv/bin/activate
    pip install --upgrade pip > /dev/null 2>&1
    
    print_success "Virtual environment setup completed"
    return 0
}

# Install bot dependencies
install_dependencies() {
    local bot_dir="$1"
    local bot_name="$2"
    
    print_progress "Installing dependencies for $bot_name..."
    
    cd "$bot_dir"
    source .venv/bin/activate
    
    # Check for requirements file
    if [[ -f "requirements.txt" ]]; then
        print_progress "Installing from requirements.txt..."
        if pip install -r requirements.txt > /dev/null 2>&1; then
            print_success "Dependencies installed successfully"
        else
            print_error "Failed to install dependencies from requirements.txt"
            return 1
        fi
    elif [[ -f "req.txt" ]]; then
        print_progress "Installing from req.txt..."
        if pip install -r req.txt > /dev/null 2>&1; then
            print_success "Dependencies installed successfully"
        else
            print_error "Failed to install dependencies from req.txt"
            return 1
        fi
    else
        print_warning "No requirements file found. Installing common dependencies..."
        # Install common music bot dependencies
        local common_deps=("pyrogram" "py-tgcalls" "youtube-dl" "yt-dlp" "python-dotenv" "psutil" "motor" "dnspython")
        for dep in "${common_deps[@]}"; do
            pip install "$dep" > /dev/null 2>&1 || true
        done
        print_success "Common dependencies installed"
    fi
    
    return 0
}

# Generate .env template
generate_env_template() {
    local bot_dir="$1"
    local bot_name="$2"
    
    print_progress "Generating .env template for $bot_name..."
    
    local env_file="$bot_dir/.env"
    
    # Check if .env already exists
    if [[ -f "$env_file" ]]; then
        print_warning ".env file already exists. Creating backup..."
        cp "$env_file" "$env_file.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Generate comprehensive .env template
    cat > "$env_file" << EOF
# $bot_name Bot Configuration
# Fill in the required values below

# Required Bot Configuration
API_ID=123456                    # Get from my.telegram.org
API_HASH=your_api_hash_here     # Get from my.telegram.org
BOT_TOKEN=123456:ABC-DEF123456  # Get from @BotFather
BOT_USERNAME=YourBot_Username   # Bot username without @

# Database Configuration
DATABASE_URL=mongodb://localhost:27017/musicbot  # MongoDB connection string
DATABASE_NAME=musicbot                           # Database name

# Session Configuration
SESSION_NAME=$bot_name           # Session name for pyrogram
STRING_SESSION=                  # Generate using string session bot

# Music Configuration
DURATION_LIMIT_MIN=60           # Maximum duration for music (minutes)
QUEUE_LIMIT=10                  # Maximum queue limit
SPOTIFY_CLIENT_ID=              # Spotify client ID (optional)
SPOTIFY_CLIENT_SECRET=          # Spotify client secret (optional)

# Admin Configuration
OWNER_ID=123456789              # Your Telegram user ID
SUDO_USERS=123456789,987654321  # Comma-separated admin user IDs

# Optional Configuration
LOG_GROUP_ID=                   # Log group ID (optional)
SUPPORT_CHANNEL=                # Support channel username (optional)
SUPPORT_CHAT=                   # Support chat username (optional)
AUTO_LEAVING_ASSISTANT=True     # Auto leave from inactive groups
ASSISTANT_PREFIX=!              # Assistant command prefix
EOF
    
    print_success ".env template generated at $env_file"
    print_warning "Please edit $env_file and fill in your bot configuration before running!"
    
    return 0
}

# Create supervisor configuration for bot
create_supervisor_config() {
    local bot_name="$1"
    local bot_dir="$DEPLOY_BASE_DIR/$bot_name"
    local config_file="$SUPERVISOR_CONFIG_DIR/$bot_name.conf"
    
    if [[ ! -d "$bot_dir" ]]; then
        print_error "Bot directory not found: $bot_dir"
        return 1
    fi
    
    local start_command=""
    local working_dir="$bot_dir"
    
    # First priority: Check for 'start' file
    if [[ -f "$bot_dir/start" ]]; then
        print_progress "Found start file for $bot_name, extracting command..."
        
        # Read the start file and extract the Python command
        local start_content=$(cat "$bot_dir/start")
        
        # Look for python3 commands (excluding commented lines)
        local python_cmd=$(echo "$start_content" | grep -v "^#" | grep -E "python3?.*-m|python3.*\.py" | head -1 | sed 's/^[[:space:]]*//')
        
        if [[ -n "$python_cmd" ]]; then
            # Convert python3 to full venv path and handle -m module syntax
            if [[ "$python_cmd" =~ python3[[:space:]]+-m[[:space:]]+([^[:space:]]+) ]]; then
                # Handle "python3 -m ModuleName" format
                local module_name="${BASH_REMATCH[1]}"
                start_command="$bot_dir/.venv/bin/python -m $module_name"
                print_info "Using module command: python -m $module_name"
            elif [[ "$python_cmd" =~ python3[[:space:]]+([^[:space:]]+\.py) ]]; then
                # Handle "python3 filename.py" format
                local py_file="${BASH_REMATCH[1]}"
                start_command="$bot_dir/.venv/bin/python $py_file"
                print_info "Using Python file: $py_file"
            else
                # Generic python3 command
                start_command=$(echo "$python_cmd" | sed "s|python3|$bot_dir/.venv/bin/python|")
                print_info "Using generic command: $start_command"
            fi
        fi
    fi
    
    # Second priority: Look for common main files if no start command found
    if [[ -z "$start_command" ]]; then
        print_progress "No start file or command found, checking for common main files..."
        
        local main_file=""
        local common_files=("main.py" "app.py" "bot.py" "run.py" "${bot_name}.py")
        
        for file in "${common_files[@]}"; do
            if [[ -f "$bot_dir/$file" ]]; then
                main_file="$file"
                break
            fi
        done
        
        # Try to find any .py file as last resort
        if [[ -z "$main_file" ]]; then
            main_file=$(find "$bot_dir" -maxdepth 1 -name "*.py" | head -1 | xargs basename 2>/dev/null || echo "")
        fi
        
        if [[ -n "$main_file" ]]; then
            start_command="$bot_dir/.venv/bin/python $main_file"
            print_info "Using main file: $main_file"
        else
            print_error "No suitable startup file found for $bot_name"
            return 1
        fi
    fi
    
    print_progress "Creating supervisor config for $bot_name..."
    print_info "Start command: $start_command"
    print_info "Working directory: $working_dir"
    
    cat > "$config_file" << EOF
[program:$bot_name]
command=$start_command
directory=$working_dir
user=root
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/$bot_name.err.log
stdout_logfile=/var/log/supervisor/$bot_name.out.log
environment=PATH="$bot_dir/.venv/bin"
stopasgroup=true
killasgroup=true
EOF
    
    print_success "Supervisor config created: $config_file"
    print_info "Command: $start_command"
    return 0
}

# Setup all bot supervisors
setup_all_supervisors() {
    print_info "Setting up supervisor configurations for all deployed bots..."
    
    local deployed_bots=()
    local success_count=0
    
    # Find deployed bots
    for dir in "$DEPLOY_BASE_DIR"/*; do
        if [[ -d "$dir/.venv" && -f "$dir/.env" ]]; then
            local bot_name=$(basename "$dir")
            deployed_bots+=("$bot_name")
        fi
    done
    
    if [[ ${#deployed_bots[@]} -eq 0 ]]; then
        print_warning "No deployed bots found"
        return 1
    fi
    
    print_info "Found ${#deployed_bots[@]} deployed bot(s): ${deployed_bots[*]}"
    
    # Create supervisor configs
    for bot_name in "${deployed_bots[@]}"; do
        if create_supervisor_config "$bot_name"; then
            ((success_count++))
        fi
    done
    
    # Reload supervisor
    print_progress "Reloading supervisor configuration..."
    supervisorctl reread > /dev/null 2>&1
    supervisorctl update > /dev/null 2>&1
    
    print_success "Supervisor setup completed: $success_count/${#deployed_bots[@]} bots configured"
    
    # Create monitoring script
    create_monitoring_script
    
    return 0
}

# Deploy single bot function
deploy_single_bot() {
    local bot_name="$1"
    local repo_url="$2"
    local branch="${3:-main}"
    
    print_info "Starting deployment of $bot_name..."
    
    # Validate repository first
    if ! validate_repo "$repo_url"; then
        print_error "Cannot access repository: $repo_url"
        return 1
    fi
    
    # Clone repository
    if ! clone_bot_repo "$bot_name" "$repo_url" "$branch"; then
        print_error "Failed to clone repository"
        return 1
    fi
    
    # Setup virtual environment
    if ! setup_virtual_env "$DEPLOY_BASE_DIR/$bot_name" "$bot_name"; then
        print_error "Failed to setup virtual environment"
        return 1
    fi
    
    # Install dependencies
    if ! install_dependencies "$DEPLOY_BASE_DIR/$bot_name" "$bot_name"; then
        print_error "Failed to install dependencies"
        return 1
    fi
    
    # Generate .env template
    if ! generate_env_template "$DEPLOY_BASE_DIR/$bot_name" "$bot_name"; then
        print_error "Failed to generate .env template"
        return 1
    fi
    
    print_success "Bot $bot_name deployed successfully!"
    print_warning "Please edit $DEPLOY_BASE_DIR/$bot_name/.env with your configuration"
    return 0
}

# Parse configuration file
parse_config_file() {
    local config_file="$1"
    local current_section=""
    local current_bot=""
    local github_username=""
    local github_password=""
    
    print_info "Parsing configuration file: $config_file"
    
    # Arrays to store bot configurations
    declare -g -A bot_configs
    declare -g -A bot_env_vars
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Remove leading/trailing whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Check for section headers
        if [[ "$line" =~ ^\[([^\]]+)\]$ ]]; then
            local section="${BASH_REMATCH[1]}"
            
            if [[ "$section" == "GITHUB" ]]; then
                current_section="GITHUB"
                current_bot=""
            elif [[ "$section" =~ ^BOT:(.+)$ ]]; then
                current_bot="${BASH_REMATCH[1]}"
                current_section="BOT"
                bot_configs["$current_bot,REPO"]=""
                bot_configs["$current_bot,BRANCH"]="main"
            elif [[ "$section" == "ENV" && -n "$current_bot" ]]; then
                current_section="ENV"
            fi
            continue
        fi
        
        # Parse key=value pairs
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Remove quotes from value
            value=$(echo "$value" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
            
            case "$current_section" in
                "GITHUB")
                    if [[ "$key" == "USERNAME" ]]; then
                        github_username="$value"
                        GITHUB_USERNAME="$value"
                    elif [[ "$key" == "PASSWORD" ]]; then
                        github_password="$value"
                        GITHUB_PASSWORD="$value"
                    fi
                    ;;
                "BOT")
                    if [[ -n "$current_bot" ]]; then
                        bot_configs["$current_bot,$key"]="$value"
                    fi
                    ;;
                "ENV")
                    if [[ -n "$current_bot" ]]; then
                        bot_env_vars["$current_bot,$key"]="$value"
                    fi
                    ;;
            esac
        fi
    done < "$config_file"
    
    # Set global GitHub credentials
    export GITHUB_USERNAME GITHUB_PASSWORD
    
    return 0
}

# Deploy all bots from configuration
batch_deploy() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "Configuration file not found: $config_file"
        return 1
    fi
    
    print_info "Starting batch deployment from $config_file"
    
    # Parse configuration file
    if ! parse_config_file "$config_file"; then
        print_error "Failed to parse configuration file"
        return 1
    fi
    
    # Get list of bots from configuration
    local bots=()
    for key in "${!bot_configs[@]}"; do
        if [[ "$key" =~ ^([^,]+),REPO$ ]]; then
            local bot_name="${BASH_REMATCH[1]}"
            if [[ -n "${bot_configs["$bot_name,REPO"]}" ]]; then
                bots+=("$bot_name")
            fi
        fi
    done
    
    if [[ ${#bots[@]} -eq 0 ]]; then
        print_warning "No bot configurations found in $config_file"
        return 1
    fi
    
    print_info "Found ${#bots[@]} bot(s) to deploy: ${bots[*]}"
    
    local success_count=0
    local total_count=${#bots[@]}
    
    # Deploy each bot
    for bot_name in "${bots[@]}"; do
        local repo_url="${bot_configs["$bot_name,REPO"]}"
        local branch="${bot_configs["$bot_name,BRANCH"]:-main}"
        
        print_info "Deploying bot $bot_name ($((success_count + 1))/$total_count)..."
        
        if deploy_single_bot "$bot_name" "$repo_url" "$branch"; then
            # Apply environment variables from config
            local env_file="$DEPLOY_BASE_DIR/$bot_name/.env"
            if [[ -f "$env_file" ]]; then
                print_progress "Applying environment configuration for $bot_name..."
                
                # Backup original .env
                cp "$env_file" "$env_file.template.backup"
                
                # Create new .env with config values
                : > "$env_file"  # Clear file
                
                # Add header
                echo "# $bot_name Bot Configuration (Auto-generated from batch config)" >> "$env_file"
                echo "# Generated on: $(date)" >> "$env_file"
                echo "" >> "$env_file"
                
                # Add environment variables from config
                for key in "${!bot_env_vars[@]}"; do
                    if [[ "$key" =~ ^${bot_name},(.+)$ ]]; then
                        local env_key="${BASH_REMATCH[1]}"
                        local env_value="${bot_env_vars["$key"]}"
                        echo "$env_key=$env_value" >> "$env_file"
                    fi
                done
                
                print_success "Environment configuration applied for $bot_name"
            fi
            
            ((success_count++))
            print_success "Bot $bot_name deployed successfully ($success_count/$total_count)"
        else
            print_error "Failed to deploy bot $bot_name"
        fi
        
        echo ""
    done
    
    print_info "Batch deployment completed: $success_count/$total_count bots deployed successfully"
    
    if [[ $success_count -gt 0 ]]; then
        print_info "Setting up supervisor configurations..."
        setup_all_supervisors
        
        echo -e "\n${GREEN}Batch deployment summary:${NC}"
        echo -e "  • Successfully deployed: ${GREEN}$success_count${NC} bots"
        echo -e "  • Failed: ${RED}$((total_count - success_count))${NC} bots"
        echo -e "  • Supervisor configs created"
        echo -e "  • Monitoring script ready"
        
        return 0
    else
        print_error "No bots were deployed successfully"
        return 1
    fi
}

# Create monitoring script
create_monitoring_script() {
    local monitor_script="/root/monitor_all_bots.sh"
    
    # Check if a working monitoring script already exists
    if [[ -f "$monitor_script" ]]; then
        print_info "Monitoring script already exists at $monitor_script"
        
        # Test if it's working with current supervisor setup
        if timeout 5 bash "$monitor_script" --test 2>/dev/null || grep -q "musicbots:" "$monitor_script" 2>/dev/null; then
            print_success "Existing monitoring script appears to be compatible"
            return 0
        else
            print_warning "Existing monitoring script may not be compatible. Creating backup..."
            cp "$monitor_script" "${monitor_script}.backup.$(date +%Y%m%d_%H%M%S)"
        fi
    fi
    
    print_info "Creating new monitoring script..."
    
    cat > "$monitor_script" << 'MONITOR_EOF'
#!/bin/bash
# Bot Monitoring Dashboard (All-in-One Manager Compatible)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    clear
    echo -e "${PURPLE}===============================================${NC}"
    echo -e "${PURPLE}  🎵 MUSIC BOT MONITORING DASHBOARD 🎵  ${NC}"
    echo -e "${PURPLE}===============================================${NC}"
    echo -e "${CYAN}  Real-time bot status and monitoring${NC}"
    echo -e "${CYAN}  $(date)${NC}"
    echo -e "${PURPLE}===============================================${NC}\n"
}

show_bot_status() {
    local bot_name="$1"
    local status=$(supervisorctl status "$bot_name" 2>/dev/null | awk '{print $2}')
    local uptime=""
    
    # Extract display name for better formatting
    local display_name="$bot_name"
    if [[ "$bot_name" =~ ^musicbots:(.+)-musicbot$ ]]; then
        display_name="${BASH_REMATCH[1]}"
    elif [[ "$bot_name" =~ ^(.+)-musicbot$ ]]; then
        display_name="${BASH_REMATCH[1]}"
    fi
    
    if [[ "$status" == "RUNNING" ]]; then
        uptime=$(supervisorctl status "$bot_name" | grep -o 'uptime [^,]*' | cut -d' ' -f2-)
        echo -e "  ${GREEN}● $display_name${NC} - ${GREEN}RUNNING${NC} (uptime: $uptime)"
    elif [[ "$status" == "STOPPED" ]]; then
        echo -e "  ${RED}● $display_name${NC} - ${RED}STOPPED${NC}"
    elif [[ "$status" == "FATAL" ]]; then
        echo -e "  ${RED}● $display_name${NC} - ${RED}FATAL ERROR${NC}"
    else
        echo -e "  ${YELLOW}● $display_name${NC} - ${YELLOW}UNKNOWN${NC}"
    fi
}

# Handle command line arguments
if [[ "$1" == "--test" ]]; then
    echo "Monitoring script test successful"
    exit 0
fi

while true; do
    print_header
    
    echo -e "${CYAN}📊 Bot Status Overview:${NC}\n"
    
    bots=$(supervisorctl status | grep -E "^[a-zA-Z0-9_:-]+\s+" | awk '{print $1}' | sort)
    
    if [[ -n "$bots" ]]; then
        for bot in $bots; do
            show_bot_status "$bot"
        done
    else
        echo -e "  ${YELLOW}No bots found in supervisor${NC}"
    fi
    
    echo -e "\n${CYAN}💾 System Resources:${NC}"
    echo -e "  ${BLUE}CPU Usage:${NC} $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
    echo -e "  ${BLUE}Memory Usage:${NC} $(free | grep Mem | awk '{printf("%.1f%%", $3/$2 * 100.0)}')"
    echo -e "  ${BLUE}Disk Usage:${NC} $(df -h / | awk 'NR==2{print $5}')"
    
    echo -e "\n${CYAN}🔧 Quick Commands:${NC}"
    echo -e "  ${YELLOW}Ctrl+C${NC} - Exit monitoring"
    echo -e "  ${YELLOW}supervisorctl status${NC} - Detailed status"
    echo -e "  ${YELLOW}supervisorctl restart <bot>${NC} - Restart specific bot"
    
    echo -e "\n${PURPLE}Auto-refreshing every 5 seconds...${NC}"
    sleep 5
done
MONITOR_EOF
    
    chmod +x "$monitor_script"
    print_success "Monitoring script created: $monitor_script"
}

# Menu functions
new_vps_setup_menu() {
    print_header
    echo -e "${CYAN}🚀 New VPS Setup${NC}\n"
    
    print_info "This will install all required system dependencies for music bots"
    echo -e "\n${YELLOW}Packages to be installed:${NC}"
    echo -e "  • Python 3, pip, venv"
    echo -e "  • FFmpeg, Git, Build tools"
    echo -e "  • Supervisor, htop, nano, screen"
    
    echo -e "\n${CYAN}Do you want to proceed? (y/n):${NC} "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        setup_new_vps
        echo -e "\n${GREEN}VPS setup completed!${NC}"
        
        echo -e "\n${CYAN}What would you like to do next?${NC}"
        echo -e "${YELLOW}1.${NC} Deploy a single bot"
        echo -e "${YELLOW}2.${NC} Create batch config template"
        echo -e "${YELLOW}3.${NC} Return to main menu"
        echo -e "\n${CYAN}Enter your choice (1-3):${NC} "
        read -r next_choice
        
        case $next_choice in
            1) deploy_single_bot_menu ;;
            2) create_config_template ;;
            3) show_main_menu ;;
            *) show_main_menu ;;
        esac
    else
        show_main_menu
    fi
}

deploy_single_bot_menu() {
    print_header
    echo -e "${CYAN}🎵 Deploy Single Bot${NC}\n"
    
    # Get bot name
    while true; do
        echo -e "${CYAN}Enter bot name (e.g., mybot, amiop):${NC} "
        read -r bot_name
        if [[ "$bot_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            break
        else
            print_error "Invalid bot name. Use only letters, numbers, underscore, and hyphen."
        fi
    done
    
    # Get repository URL
    while true; do
        echo -e "${CYAN}Enter repository URL:${NC} "
        read -r repo_url
        if validate_repo "$repo_url"; then
            break
        fi
    done
    
    # Get branch (optional)
    echo -e "${CYAN}Enter branch name (default: main):${NC} "
    read -r branch
    branch="${branch:-main}"
    
    # Deploy the bot
    if deploy_single_bot "$bot_name" "$repo_url" "$branch"; then
        echo -e "\n${GREEN}Bot deployed successfully!${NC}"
        
        echo -e "\n${CYAN}What would you like to do next?${NC}"
        echo -e "${YELLOW}1.${NC} Setup supervisor for this bot"
        echo -e "${YELLOW}2.${NC} Deploy another bot"
        echo -e "${YELLOW}3.${NC} Return to main menu"
        echo -e "\n${CYAN}Enter your choice (1-3):${NC} "
        read -r next_choice
        
        case $next_choice in
            1) 
                if create_supervisor_config "$bot_name"; then
                    supervisorctl reread > /dev/null 2>&1
                    supervisorctl update > /dev/null 2>&1
                    print_success "Supervisor setup completed for $bot_name"
                fi
                echo -e "\n${CYAN}Press Enter to continue...${NC}"
                read -r
                show_main_menu
                ;;
            2) deploy_single_bot_menu ;;
            3) show_main_menu ;;
            *) show_main_menu ;;
        esac
    else
        print_error "Bot deployment failed"
        echo -e "\n${CYAN}Press Enter to continue...${NC}"
        read -r
        show_main_menu
    fi
}

create_config_template() {
    print_header
    echo -e "${CYAN}📝 Create Batch Config Template${NC}\n"
    
    local config_file="musicbots-config.txt"
    
    cat > "$config_file" << 'CONFIG_EOF'
# Music Bot Batch Deployment Configuration
# Complete configuration file for deploying multiple bots

# GitHub Credentials (for private repositories)
[GITHUB]
USERNAME=your_github_username
PASSWORD=your_github_password_or_token

# Bot Configuration Examples:
# [BOT:bot_name]
# REPO=repository_url
# BRANCH=branch_name (optional, defaults to main)
# [ENV]
# ... all .env variables here ...

# Example Bot 1
[BOT:amiop]
REPO=https://github.com/AnonymousX1025/AnonXMusic
BRANCH=main
[ENV]
API_ID=123456
API_HASH=your_api_hash_here
BOT_TOKEN=123456:ABC-DEF123456
BOT_USERNAME=AmiBot_Username
DATABASE_URL=mongodb://localhost:27017/amiop
DATABASE_NAME=amiop
SESSION_NAME=amiop
STRING_SESSION=
DURATION_LIMIT_MIN=60
QUEUE_LIMIT=10
OWNER_ID=123456789
SUDO_USERS=123456789,987654321
AUTO_LEAVING_ASSISTANT=True
ASSISTANT_PREFIX=!

# Example Bot 2
[BOT:mybot]
REPO=https://github.com/yourusername/your-musicbot
BRANCH=main
[ENV]
API_ID=123456
API_HASH=your_api_hash_here
BOT_TOKEN=123456:XYZ-GHI789012
BOT_USERNAME=MyBot_Username
DATABASE_URL=mongodb://localhost:27017/mybot
DATABASE_NAME=mybot
SESSION_NAME=mybot
STRING_SESSION=
DURATION_LIMIT_MIN=60
QUEUE_LIMIT=10
OWNER_ID=123456789
SUDO_USERS=123456789,987654321
AUTO_LEAVING_ASSISTANT=True
ASSISTANT_PREFIX=/
CONFIG_EOF
    
    print_success "Batch config template created: $config_file"
    print_info "Edit this file with your bot configurations"
    
    echo -e "\n${CYAN}What would you like to do next?${NC}"
    echo -e "${YELLOW}1.${NC} Edit the config file now (nano)"
    echo -e "${YELLOW}2.${NC} Return to main menu"
    echo -e "\n${CYAN}Enter your choice (1-2):${NC} "
    read -r choice
    
    case $choice in
        1) 
            nano "$config_file"
            show_main_menu
            ;;
        2) show_main_menu ;;
        *) show_main_menu ;;
    esac
}

batch_deploy_menu() {
    print_header
    echo -e "${CYAN}📦 Batch Deploy Bots${NC}\n"
    
    # List available config files (only in root directory, exclude hidden files and common patterns)
    local config_files=()
    
    # Look for common config file patterns in root directory only
    for pattern in "musicbots-config.txt" "*-config.txt" "bots-config.txt" "config.txt" "*.conf"; do
        while IFS= read -r -d '' file; do
            # Only add if it's a regular file and not hidden
            if [[ -f "$file" && ! "$file" =~ ^\./\. ]]; then
                config_files+=("$file")
            fi
        done < <(find . -maxdepth 1 -name "$pattern" -type f -print0 2>/dev/null)
    done
    
    # Remove duplicates and limit to 10
    local unique_files=($(printf '%s\n' "${config_files[@]}" | sort -u | head -10))
    
    if [[ ${#unique_files[@]} -gt 0 ]]; then
        echo -e "${CYAN}Available config files:${NC}"
        for i in "${!unique_files[@]}"; do
            echo -e "  ${YELLOW}$((i+1)).${NC} ${unique_files[i]}"
        done
        echo -e "  ${YELLOW}0.${NC} Enter custom path"
        
        echo -e "\n${CYAN}Select config file (0-${#unique_files[@]}):${NC} "
        read -r choice
        
        if [[ "$choice" -eq 0 ]]; then
            echo -e "${CYAN}Enter config file path:${NC} "
            read -r config_file
        elif [[ "$choice" -ge 1 && "$choice" -le ${#unique_files[@]} ]]; then
            config_file="${unique_files[$((choice-1))]}"
        else
            print_error "Invalid choice"
            batch_deploy_menu
            return
        fi
    else
        echo -e "${CYAN}Enter config file path:${NC} "
        read -r config_file
    fi
    
    if [[ -f "$config_file" ]]; then
        print_info "Starting batch deployment from $config_file"
        
        if batch_deploy "$config_file"; then
            echo -e "\n${GREEN}Batch deployment completed successfully!${NC}"
            
            echo -e "\n${CYAN}What would you like to do next?${NC}"
            echo -e "${YELLOW}1.${NC} Monitor deployed bots"
            echo -e "${YELLOW}2.${NC} Setup supervisor for all bots"
            echo -e "${YELLOW}3.${NC} Return to main menu"
            echo -e "\n${CYAN}Enter your choice (1-3):${NC} "
            read -r next_choice
            
            case $next_choice in
                1) monitor_bots_menu ;;
                2) supervisor_management_menu ;;
                3) show_main_menu ;;
                *) show_main_menu ;;
            esac
        else
            print_error "Batch deployment failed"
            echo -e "\n${CYAN}Press Enter to continue...${NC}"
            read -r
            show_main_menu
        fi
    else
        print_error "Config file not found: $config_file"
        echo -e "\n${CYAN}Press Enter to continue...${NC}"
        read -r
        show_main_menu
    fi
}

supervisor_management_menu() {
    print_header
    echo -e "${CYAN}🔧 Supervisor Management${NC}\n"
    
    echo -e "${YELLOW}1.${NC} Setup supervisor for all deployed bots"
    echo -e "${YELLOW}2.${NC} Setup supervisor for specific bot"
    echo -e "${YELLOW}3.${NC} Start all bots"
    echo -e "${YELLOW}4.${NC} Stop all bots"
    echo -e "${YELLOW}5.${NC} Restart all bots"
    echo -e "${YELLOW}6.${NC} Show supervisor status"
    echo -e "${YELLOW}7.${NC} Return to main menu"
    
    echo -e "\n${CYAN}Enter your choice (1-7):${NC} "
    read -r choice
    
    case $choice in
        1)
            setup_all_supervisors
            echo -e "\n${CYAN}Press Enter to continue...${NC}"
            read -r
            supervisor_management_menu
            ;;
        2)
            echo -e "${CYAN}Enter bot name:${NC} "
            read -r bot_name
            if create_supervisor_config "$bot_name"; then
                supervisorctl reread > /dev/null 2>&1
                supervisorctl update > /dev/null 2>&1
                print_success "Supervisor setup completed for $bot_name"
            fi
            echo -e "\n${CYAN}Press Enter to continue...${NC}"
            read -r
            supervisor_management_menu
            ;;
        3)
            print_progress "Starting all bots..."
            # Try different approaches for starting all bots
            if supervisorctl status | grep -q "musicbots:"; then
                supervisorctl start musicbots:*
            else
                supervisorctl start all
            fi
            echo -e "\n${CYAN}Press Enter to continue...${NC}"
            read -r
            supervisor_management_menu
            ;;
        4)
            print_progress "Stopping all bots..."
            # Try different approaches for stopping all bots
            if supervisorctl status | grep -q "musicbots:"; then
                supervisorctl stop musicbots:*
            else
                supervisorctl stop all
            fi
            echo -e "\n${CYAN}Press Enter to continue...${NC}"
            read -r
            supervisor_management_menu
            ;;
        5)
            print_progress "Restarting all bots..."
            # Try different approaches for restarting all bots
            if supervisorctl status | grep -q "musicbots:"; then
                supervisorctl restart musicbots:*
            else
                supervisorctl restart all
            fi
            echo -e "\n${CYAN}Press Enter to continue...${NC}"
            read -r
            supervisor_management_menu
            ;;
        6)
            echo -e "\n${CYAN}📊 Supervisor Status:${NC}\n"
            supervisorctl status
            echo -e "\n${CYAN}Press Enter to continue...${NC}"
            read -r
            supervisor_management_menu
            ;;
        7) show_main_menu ;;
        *) supervisor_management_menu ;;
    esac
}

monitor_bots_menu() {
    print_header
    echo -e "${CYAN}📊 Monitor Bots${NC}\n"
    
    echo -e "${YELLOW}1.${NC} Start real-time monitoring dashboard"
    echo -e "${YELLOW}2.${NC} Show current bot status"
    echo -e "${YELLOW}3.${NC} View bot logs"
    echo -e "${YELLOW}4.${NC} System resource usage"
    echo -e "${YELLOW}5.${NC} Return to main menu"
    
    echo -e "\n${CYAN}Enter your choice (1-5):${NC} "
    read -r choice
    
    case $choice in
        1)
            if [[ -f "/root/monitor_all_bots.sh" ]]; then
                /root/monitor_all_bots.sh
            else
                print_warning "Monitoring script not found. Setting up supervisors will create it."
                echo -e "\n${CYAN}Press Enter to continue...${NC}"
                read -r
            fi
            monitor_bots_menu
            ;;
        2)
            echo -e "\n${CYAN}📊 Current Bot Status:${NC}\n"
            
            # Enhanced status display similar to the monitoring script
            local bots=($(supervisorctl status | awk '{print $1}' | sort))
            
            if [[ ${#bots[@]} -gt 0 ]]; then
                for bot_name in "${bots[@]}"; do
                    local status_line=$(supervisorctl status "$bot_name" 2>/dev/null)
                    local status=$(echo "$status_line" | awk '{print $2}')
                    local pid=""
                    local uptime=""
                    
                    if [[ "$status" == "RUNNING" ]]; then
                        pid=$(echo "$status_line" | grep -o 'pid [0-9]*' | awk '{print $2}' || echo "")
                        uptime=$(echo "$status_line" | grep -o 'uptime [^,]*' | cut -d' ' -f2- || echo "")
                        
                        # Get memory usage if possible
                        local memory=""
                        if [[ -n "$pid" ]]; then
                            memory=$(ps -p "$pid" -o rss= 2>/dev/null | awk '{printf "%.1fMB", $1/1024}' || echo "")
                        fi
                        
                        echo -e "  ${GREEN}● $bot_name${NC} - ${GREEN}RUNNING${NC}"
                        if [[ -n "$pid" ]]; then echo -e "    ├─ PID: $pid"; fi
                        if [[ -n "$uptime" ]]; then echo -e "    ├─ Uptime: $uptime"; fi
                        if [[ -n "$memory" ]]; then echo -e "    └─ Memory: $memory"; fi
                    elif [[ "$status" == "STOPPED" ]]; then
                        echo -e "  ${RED}● $bot_name${NC} - ${RED}STOPPED${NC}"
                    elif [[ "$status" == "FATAL" ]]; then
                        echo -e "  ${RED}● $bot_name${NC} - ${RED}FATAL ERROR${NC}"
                        echo -e "    └─ Check logs: tail -f /var/log/supervisor/$bot_name.err.log"
                    else
                        echo -e "  ${YELLOW}● $bot_name${NC} - ${YELLOW}$status${NC}"
                    fi
                    echo ""
                done
            else
                echo -e "  ${YELLOW}No bots found in supervisor${NC}"
            fi
            
            echo -e "\n${CYAN}Press Enter to continue...${NC}"
            read -r
            monitor_bots_menu
            ;;
        3)
            echo -e "${CYAN}Enter bot name to view logs:${NC} "
            read -r bot_name
            echo -e "\n${CYAN}📄 Recent logs for $bot_name:${NC}\n"
            tail -50 "/var/log/supervisor/$bot_name.out.log" 2>/dev/null || print_error "Log file not found"
            echo -e "\n${CYAN}Press Enter to continue...${NC}"
            read -r
            monitor_bots_menu
            ;;
        4)
            echo -e "\n${CYAN}💾 System Resources:${NC}\n"
            echo -e "  ${BLUE}CPU Usage:${NC} $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
            echo -e "  ${BLUE}Memory Usage:${NC} $(free | grep Mem | awk '{printf("%.1f%%", $3/$2 * 100.0)}')"
            echo -e "  ${BLUE}Disk Usage:${NC} $(df -h / | awk 'NR==2{print $5}')"
            echo -e "  ${BLUE}Load Average:${NC} $(uptime | awk -F'load average:' '{print $2}')"
            echo -e "\n${CYAN}Press Enter to continue...${NC}"
            read -r
            monitor_bots_menu
            ;;
        5) show_main_menu ;;
        *) monitor_bots_menu ;;
    esac
}

bot_management_menu() {
    print_header
    echo -e "${CYAN}🤖 Bot Management${NC}\n"
    
    # Get all supervisor programs and extract bot names
    local all_programs=($(supervisorctl status | awk '{print $1}' | sort))
    local available_bots=()
    local bot_to_supervisor=()
    
    # Extract actual bot names from supervisor program names
    for program in "${all_programs[@]}"; do
        if [[ "$program" =~ ^musicbots:(.+)-musicbot$ ]]; then
            # Group format: musicbots:botname-musicbot
            local bot_name="${BASH_REMATCH[1]}"
            available_bots+=("$bot_name")
            bot_to_supervisor+=("$bot_name:$program")
        elif [[ "$program" =~ ^(.+)-musicbot$ ]]; then
            # Alternative format: botname-musicbot
            local bot_name="${BASH_REMATCH[1]}"
            available_bots+=("$bot_name")
            bot_to_supervisor+=("$bot_name:$program")
        else
            # Simple format or other programs
            if [[ -d "$DEPLOY_BASE_DIR/$program" ]]; then
                available_bots+=("$program")
                bot_to_supervisor+=("$program:$program")
            fi
        fi
    done
    
    if [[ ${#available_bots[@]} -eq 0 ]]; then
        print_warning "No bots found in supervisor"
        echo -e "\n${CYAN}Press Enter to continue...${NC}"
        read -r
        show_main_menu
        return
    fi
    
    echo -e "${CYAN}Available bots:${NC}"
    for i in "${!available_bots[@]}"; do
        local bot_name="${available_bots[i]}"
        # Find supervisor name for this bot
        local supervisor_name=""
        for mapping in "${bot_to_supervisor[@]}"; do
            if [[ "$mapping" =~ ^${bot_name}:(.+)$ ]]; then
                supervisor_name="${BASH_REMATCH[1]}"
                break
            fi
        done
        
        local status=$(supervisorctl status "$supervisor_name" 2>/dev/null | awk '{print $2}' || echo "UNKNOWN")
        if [[ "$status" == "RUNNING" ]]; then
            echo -e "  ${YELLOW}$((i+1)).${NC} ${bot_name} - ${GREEN}RUNNING${NC}"
        else
            echo -e "  ${YELLOW}$((i+1)).${NC} ${bot_name} - ${RED}$status${NC}"
        fi
    done
    
    echo -e "\n${CYAN}Select bot (1-${#available_bots[@]}):${NC} "
    read -r choice
    
    if [[ "$choice" -ge 1 && "$choice" -le ${#available_bots[@]} ]]; then
        local selected_bot="${available_bots[$((choice-1))]}"
        # Find supervisor name for selected bot
        local supervisor_name=""
        for mapping in "${bot_to_supervisor[@]}"; do
            if [[ "$mapping" =~ ^${selected_bot}:(.+)$ ]]; then
                supervisor_name="${BASH_REMATCH[1]}"
                break
            fi
        done
        individual_bot_menu "$selected_bot" "$supervisor_name"
    else
        print_error "Invalid choice"
        bot_management_menu
    fi
}

individual_bot_menu() {
    local bot_name="$1"
    local supervisor_name="$2"
    
    print_header
    echo -e "${CYAN}🤖 Managing Bot: ${YELLOW}$bot_name${NC}\n"
    echo -e "${BLUE}Supervisor Name: ${YELLOW}$supervisor_name${NC}\n"
    
    local status=$(supervisorctl status "$supervisor_name" 2>/dev/null | awk '{print $2}' || echo "UNKNOWN")
    echo -e "${CYAN}Current Status:${NC} "
    if [[ "$status" == "RUNNING" ]]; then
        echo -e "${GREEN}$status${NC}"
    else
        echo -e "${RED}$status${NC}"
    fi
    
    echo -e "\n${YELLOW}1.${NC} Start bot"
    echo -e "${YELLOW}2.${NC} Stop bot"
    echo -e "${YELLOW}3.${NC} Restart bot"
    echo -e "${YELLOW}4.${NC} View logs"
    echo -e "${YELLOW}5.${NC} Edit .env file"
    echo -e "${YELLOW}6.${NC} Back to bot list"
    echo -e "${YELLOW}7.${NC} Return to main menu"
    
    echo -e "\n${CYAN}Enter your choice (1-7):${NC} "
    read -r choice
    
    case $choice in
        1)
            supervisorctl start "$supervisor_name"
            echo -e "\n${CYAN}Press Enter to continue...${NC}"
            read -r
            individual_bot_menu "$bot_name" "$supervisor_name"
            ;;
        2)
            supervisorctl stop "$supervisor_name"
            echo -e "\n${CYAN}Press Enter to continue...${NC}"
            read -r
            individual_bot_menu "$bot_name" "$supervisor_name"
            ;;
        3)
            supervisorctl restart "$supervisor_name"
            echo -e "\n${CYAN}Press Enter to continue...${NC}"
            read -r
            individual_bot_menu "$bot_name" "$supervisor_name"
            ;;
        4)
            echo -e "\n${CYAN}📄 Recent logs for $bot_name:${NC}\n"
            # Try different log file naming conventions
            local log_files=(
                "/var/log/supervisor/${bot_name}-musicbot.log"
                "/var/log/supervisor/${supervisor_name}.log"
                "/var/log/supervisor/${bot_name}.out.log"
            )
            
            local log_found=false
            for log_file in "${log_files[@]}"; do
                if [[ -f "$log_file" ]]; then
                    tail -50 "$log_file"
                    log_found=true
                    break
                fi
            done
            
            if [[ "$log_found" == false ]]; then
                print_error "Log file not found. Tried: ${log_files[*]}"
            fi
            
            echo -e "\n${CYAN}Press Enter to continue...${NC}"
            read -r
            individual_bot_menu "$bot_name" "$supervisor_name"
            ;;
        5)
            if [[ -f "$DEPLOY_BASE_DIR/$bot_name/.env" ]]; then
                nano "$DEPLOY_BASE_DIR/$bot_name/.env"
                echo -e "\n${YELLOW}Restart the bot to apply changes${NC}"
            else
                print_error ".env file not found at $DEPLOY_BASE_DIR/$bot_name/.env"
            fi
            echo -e "\n${CYAN}Press Enter to continue...${NC}"
            read -r
            individual_bot_menu "$bot_name" "$supervisor_name"
            ;;
        6) bot_management_menu ;;
        7) show_main_menu ;;
        *) individual_bot_menu "$bot_name" "$supervisor_name" ;;
    esac
}

system_info_menu() {
    print_header
    echo -e "${CYAN}💻 System Information${NC}\n"
    
    # Show deployed bots
    local deployed_bots=()
    for dir in "$DEPLOY_BASE_DIR"/*; do
        if [[ -d "$dir/.venv" && -f "$dir/.env" ]]; then
            local bot_name=$(basename "$dir")
            deployed_bots+=("$bot_name")
        fi
    done
    
    echo -e "${CYAN}📊 Deployed Bots:${NC}"
    if [[ ${#deployed_bots[@]} -gt 0 ]]; then
        for bot_name in "${deployed_bots[@]}"; do
            local bot_dir="$DEPLOY_BASE_DIR/$bot_name"
            
            # Try different supervisor naming conventions
            local supervisor_names=(
                "musicbots:${bot_name}-musicbot"    # Group format from setup-musicbot-supervisor.sh
                "${bot_name}"                        # Simple format
                "${bot_name}-musicbot"               # Alternative format
            )
            
            local status_line=""
            local found_name=""
            
            # Find which naming convention works
            for supervisor_name in "${supervisor_names[@]}"; do
                status_line=$(supervisorctl status "$supervisor_name" 2>/dev/null || echo "")
                if [[ -n "$status_line" ]]; then
                    found_name="$supervisor_name"
                    break
                fi
            done
            
            if [[ -n "$status_line" && -n "$found_name" ]]; then
                local status=$(echo "$status_line" | awk '{print $2}')
                local uptime=""
                
                if [[ "$status" == "RUNNING" ]]; then
                    uptime=$(echo "$status_line" | grep -o 'uptime [^,]*' | cut -d' ' -f2- || echo "")
                    if [[ -n "$uptime" ]]; then
                        echo -e "  • ${YELLOW}$bot_name${NC} -> $bot_dir (${GREEN}RUNNING${NC} - $uptime)"
                    else
                        echo -e "  • ${YELLOW}$bot_name${NC} -> $bot_dir (${GREEN}RUNNING${NC})"
                    fi
                elif [[ "$status" == "STOPPED" ]]; then
                    echo -e "  • ${YELLOW}$bot_name${NC} -> $bot_dir (${RED}STOPPED${NC})"
                elif [[ "$status" == "FATAL" ]]; then
                    echo -e "  • ${YELLOW}$bot_name${NC} -> $bot_dir (${RED}FATAL ERROR${NC})"
                else
                    echo -e "  • ${YELLOW}$bot_name${NC} -> $bot_dir (${YELLOW}$status${NC})"
                fi
            else
                echo -e "  • ${YELLOW}$bot_name${NC} -> $bot_dir (${YELLOW}NOT_IN_SUPERVISOR${NC})"
            fi
        done
    else
        echo -e "  ${YELLOW}No bots deployed${NC}"
    fi
    
    # Show bot statistics
    local running_count=0
    local stopped_count=0
    local total_count=${#deployed_bots[@]}
    
    for bot_name in "${deployed_bots[@]}"; do
        # Try different supervisor naming conventions
        local supervisor_names=(
            "musicbots:${bot_name}-musicbot"    # Group format
            "${bot_name}"                        # Simple format
            "${bot_name}-musicbot"               # Alternative format
        )
        
        local status=""
        for supervisor_name in "${supervisor_names[@]}"; do
            status=$(supervisorctl status "$supervisor_name" 2>/dev/null | awk '{print $2}' || echo "")
            if [[ -n "$status" ]]; then
                break
            fi
        done
        
        if [[ "$status" == "RUNNING" ]]; then
            ((running_count++))
        else
            ((stopped_count++))
        fi
    done
    
    if [[ $total_count -gt 0 ]]; then
        echo -e "\n${CYAN}📈 Bot Statistics:${NC}"
        echo -e "  • Total Bots: ${YELLOW}$total_count${NC}"
        echo -e "  • Running: ${GREEN}$running_count${NC} ✅"
        echo -e "  • Stopped/Issues: ${RED}$stopped_count${NC} ⚠️"
    fi
    
    echo -e "\n${CYAN}💾 System Resources:${NC}"
    echo -e "  • ${BLUE}CPU Usage:${NC} $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
    echo -e "  • ${BLUE}Memory Usage:${NC} $(free | grep Mem | awk '{printf("%.1f%%", $3/$2 * 100.0)}')"
    echo -e "  • ${BLUE}Disk Usage:${NC} $(df -h / | awk 'NR==2{print $5}')"
    echo -e "  • ${BLUE}Uptime:${NC} $(uptime -p)"
    
    echo -e "\n${CYAN}🔧 Quick Commands:${NC}"
    echo -e "  • Monitor all bots: ${YELLOW}/root/monitor_all_bots.sh${NC}"
    echo -e "  • Supervisor control: ${YELLOW}supervisorctl status${NC}"
    echo -e "  • View logs: ${YELLOW}tail -f /var/log/supervisor/botname.out.log${NC}"
    
    echo -e "\n${CYAN}Press Enter to continue...${NC}"
    read -r
    show_main_menu
}

# Main execution
main() {
    check_root
    show_main_menu
}

# Exit function
exit_manager() {
    print_header
    echo -e "${GREEN}Thank you for using Music Bot Manager!${NC}\n"
    echo -e "${CYAN}📋 Quick Reference:${NC}"
    echo -e "  • Monitor bots: ${YELLOW}/root/monitor_all_bots.sh${NC}"
    echo -e "  • Supervisor control: ${YELLOW}supervisorctl status${NC}"
    echo -e "  • Run manager again: ${YELLOW}./musicbot-manager.sh${NC}"
    echo -e "\n${PURPLE}Happy botting! 🎵${NC}\n"
    exit 0
}

# Script entry point
main "$@"
