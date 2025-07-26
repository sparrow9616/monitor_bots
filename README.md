# 🎵 Music Bot Supervisor Setup - One-Click Deployment

A comprehensive solution for managing music bots across multiple VPS servers with supervisor, monitoring, and automated management. Now with **interactive bot selection** and **management features** for existing setups.

**🚀 Quick start:** `curl -sSL https://raw.githubusercontent.com/sparrow9616/monitor_bots/main/setup-musicbot-supervisor.sh | sudo bash`

## ✨ New Features v1.0

- **🎯 Interactive Bot Selection** - Choose which bots to deploy during installation
- **🛠 Setup Management** - Add, remove, or reinstall bots on existing setups
- **🔍 Smart Detection** - Validates .env files before deployment
- **📊 Real-time Status** - Shows current bot status and management options
- **🔄 Complete Management** - Remove individual bots or entire setup

## 🚀 Quick Installation

### Method 1: Auto-Detection with Selection (Recommended)
```bash
# Download and run the setup script
wget https://raw.githubusercontent.com/sparrow9616/monitor_bots/main/setup-musicbot-supervisor.sh
chmod +x setup-musicbot-supervisor.sh
sudo ./setup-musicbot-supervisor.sh
```

### Method 2: One-liner Installation
```bash
curl -sSL https://raw.githubusercontent.com/sparrow9616/monitor_bots/main/setup-musicbot-supervisor.sh | sudo bash
```

### Method 3: Interactive Configuration
```bash
sudo ./setup-musicbot-supervisor.sh --interactive
```

### Method 4: Custom Configuration
```bash
# Create configuration template
sudo ./setup-musicbot-supervisor.sh --create-config

# Edit the configuration file
nano bot-config.conf

# Run setup with custom config
sudo ./setup-musicbot-supervisor.sh
```

## 🛠 Management Interface

### Fresh Installation
When running on a clean system:
1. **Detects bot directories** with .venv and .env files
2. **Shows selection menu** - choose which bots to deploy
3. **Validates configuration** - checks for essential bot settings
4. **Sets up everything** - supervisor, monitoring, cron jobs

### Existing Installation Management
When running on a system with existing setup:

```
Setup Management Options:
  1 - Add new bots to existing setup
  2 - Remove existing bots  
  3 - Completely reinstall (remove all and start fresh)
  4 - Continue with current setup (no changes)
  5 - Exit
```

#### Option 1: Add New Bots
- Detects new bot directories
- Shows interactive selection menu
- Adds selected bots to existing supervisor config
- Updates monitoring script and cron jobs

#### Option 2: Remove Existing Bots
```
Current bots:
[1] amiop (Status: RUNNING)
[2] sri (Status: RUNNING)

Remove bots:
  1,2,3 - Remove specific bots (comma-separated)
  all - Remove all bots
  cancel - Cancel and exit
```

#### Option 3: Complete Reinstall
- Stops all bots
- Removes supervisor configuration
- Cleans up monitoring script and cron jobs
- Starts fresh installation process

## 🎯 Smart Bot Detection & Selection

### Detection Criteria
The script finds bot directories by checking for:
- ✅ `.venv` folder (Python virtual environment)
- ✅ `.env` file with essential configuration
- ✅ Required keys: `API_ID`, `BOT_TOKEN`, `SESSION`, `DATABASE`
- ✅ Valid directory structure in `/root` or `/home`

### Selection Interface
```
Detected bots:
[1] amiop (/root/amiop)
    ✓ Configuration looks valid
[2] sri (/root/sri) 
    ✓ Configuration looks valid
[3] testbot (/root/testbot)
    ⚠ Configuration may be incomplete

Options:
  a - Deploy ALL bots
  1,2,3 - Deploy specific bots (comma-separated)
  n - Skip auto-detection, configure manually

Your choice: 1,2
```

## 📋 What Gets Installed

- ✅ **Supervisor** - Process management with auto-restart
- ✅ **Smart Detection** - Finds and validates bot directories
- ✅ **Interactive Selection** - Choose which bots to deploy
- ✅ **Monitoring Script** - `/root/monitor_all_bots.sh` with real-time status
- ✅ **Cron Jobs** - Automatic restarts and monitoring every hour
- ✅ **Log Management** - Rotation and cleanup to prevent disk issues
- ✅ **Process Cleanup** - Kills existing tmux/screen sessions

## 📊 Monitoring Commands

The script generates `/root/monitor_all_bots.sh` with these features:

```bash
# Real-time monitoring with colors
/root/monitor_all_bots.sh

# Bot control commands
/root/monitor_all_bots.sh start <bot-name>
/root/monitor_all_bots.sh stop <bot-name>
/root/monitor_all_bots.sh restart <bot-name>

# Bulk operations
/root/monitor_all_bots.sh start all
/root/monitor_all_bots.sh stop all
/root/monitor_all_bots.sh restart all

# Log viewing
/root/monitor_all_bots.sh logs <bot-name>
/root/monitor_all_bots.sh logs <bot-name> 50  # Last 50 lines

# Status check
/root/monitor_all_bots.sh status
```

## ⏰ Automated Maintenance

Configured cron jobs handle:
- **🔄 Bot Restart**: Every 6 hours (prevents memory leaks)
- **📊 Status Monitoring**: Every hour with logging
- **🧹 Log Cleanup**: Automatic old log removal
- **📝 Error Tracking**: Monitors and logs bot issues

```bash
# View current cron jobs
crontab -l | grep musicbot

# Temporarily disable automation
crontab -l | grep -v musicbot | crontab -

# Re-enable (re-run setup script)
```

## 📁 Configuration File Format

Create `bot-config.conf` for advanced configurations:

```bash
#!/bin/bash
# Music Bot Configuration File

# Bot configurations (name:directory:module:restart_schedule:log_retention)
BOTS=(
    "amiop:/root/amiop:AnonXMusic:0 */6 * * *:7"
    "sri:/root/sri:AnonXMusic:0 */6 * * *:7"
    "mybot:/home/user/mybot:CustomBot:0 4 * * *:14"
)

# Global settings
DEFAULT_BOT_MODULE="AnonXMusic"
DEFAULT_LOG_RETENTION_DAYS=7
DEFAULT_MONITOR_LOG_RETENTION_DAYS=30
RESTART_SCHEDULE="0 */6 * * *"  # Every 6 hours
MONITOR_SCHEDULE="0 * * * *"    # Every hour
```

## 🔧 Manual Supervisor Commands

```bash
# Check status
sudo supervisorctl status

# Control all music bots
sudo supervisorctl start musicbots:*
sudo supervisorctl stop musicbots:*
sudo supervisorctl restart musicbots:*

# Control specific bot
sudo supervisorctl start musicbots:amiop-musicbot
sudo supervisorctl stop musicbots:sri-musicbot
sudo supervisorctl restart musicbots:amiop-musicbot

# View real-time logs
sudo supervisorctl tail -f musicbots:amiop-musicbot

# Reload configuration
sudo supervisorctl reread
sudo supervisorctl update
```

## 🐛 Troubleshooting

### Bot Not Starting After Auto-Detection
```bash
# Check if bot was properly detected
sudo supervisorctl status

# Check .env file validation
cat /root/botname/.env | grep -E "(API_ID|BOT_TOKEN|SESSION|DATABASE)"

# View supervisor logs
sudo supervisorctl tail musicbots:botname-musicbot

# Manually test the bot
cd /root/botname
source .venv/bin/activate
python -m AnonXMusic
```

### Re-running with Different Options
```bash
# Run script again to access management menu
sudo ./setup-musicbot-supervisor.sh

# Options available:
# 1 - Add newly detected bots
# 2 - Remove specific bots from current setup  
# 3 - Complete fresh installation
# 4 - Keep current setup unchanged
```

### Supervisor Issues
```bash
# Restart supervisor service
sudo systemctl restart supervisor

# Check supervisor status
sudo systemctl status supervisor

# View supervisor logs
sudo journalctl -u supervisor -f
```

### Configuration Problems
```bash
# Validate supervisor configuration
sudo supervisorctl avail

# Check for syntax errors
sudo supervisorctl reread

# View detailed setup logs
tail -f /tmp/musicbot-setup.log
```

## 📂 Important File Locations

- **Supervisor Config**: `/etc/supervisor/conf.d/musicbots.conf`
- **Monitoring Script**: `/root/monitor_all_bots.sh`
- **Setup Log**: `/tmp/musicbot-setup.log`
- **Bot Restart Log**: `/var/log/bot_restart.log`
- **Monitor Log**: `/var/log/bot_monitor.log`
- **Individual Bot Logs**: `/tmp/musicbot-<botname>.log`

## 🔐 System Requirements

- **Root Access**: Script must run with sudo privileges
- **Linux Distribution**: Ubuntu/Debian (tested on Ubuntu 22.04)
- **Bot Structure**: Directories with `.venv` and configured `.env` files
- **Python Environment**: Working virtual environments for each bot
- **Essential Config**: .env files must contain API_ID, BOT_TOKEN, SESSION, DATABASE

## 🌟 Advanced Features

### Multi-Bot Management
- **Unlimited Bots**: Handle as many bots as your system can support
- **Independent Processes**: Each bot runs separately with own logs
- **Selective Management**: Add/remove individual bots without affecting others
- **Batch Operations**: Start/stop/restart all bots with single commands

### Smart Configuration Validation
- **Pre-deployment Checks**: Validates .env files before creating supervisor config
- **Missing Config Warnings**: Shows which bots have incomplete configuration
- **Interactive Selection**: Skip problematic bots during deployment
- **Configuration Status**: Real-time display of which bots are properly configured

### Resource Monitoring
- **Memory Tracking**: Monitor memory usage per bot
- **Error Counting**: Track errors from bot logs
- **Performance Metrics**: CPU and uptime monitoring
- **Automated Restart**: Restart bots based on resource thresholds

### Deployment Flexibility
- **Multiple Installation Methods**: Direct download, one-liner, git clone
- **Configuration Options**: Auto-detect, interactive, or custom config file
- **Environment Support**: Works across different VPS providers and configurations
- **Update Management**: Easy re-running for configuration changes

## 🔄 Common Use Cases

### Setting Up New VPS
1. Deploy bots to fresh server
2. Script auto-detects valid bot directories
3. Choose which bots to deploy from interactive menu
4. Everything configured automatically

### Adding New Bot to Existing Setup
1. Run script on server with existing bots
2. Choose "Add new bots to existing setup"
3. Script detects new bot directories
4. Select additional bots to deploy

### Removing Problematic Bot
1. Run script on existing server
2. Choose "Remove existing bots"
3. Select specific bot to remove from numbered list
4. Bot stopped and removed from all configurations

### Complete Setup Refresh
1. Run script on existing server
2. Choose "Completely reinstall"
3. All bots stopped and configurations cleared
4. Fresh installation process starts

## 📊 Monitoring Dashboard

The monitoring script provides a comprehensive dashboard:

```
🎵 Music Bot Monitor - Real-time Status 🎵
═══════════════════════════════════════════════════════════

Bot: amiop
├─ Status: ✅ RUNNING (PID: 12345, Uptime: 2h 15m)
├─ Memory: 🟢 45.2MB (Normal)
├─ Errors: 🟡 3 recent errors
└─ Last Check: 2025-01-26 18:15:30

Bot: sri  
├─ Status: ✅ RUNNING (PID: 12346, Uptime: 2h 15m)
├─ Memory: 🟢 38.7MB (Normal)
├─ Errors: 🟢 0 recent errors
└─ Last Check: 2025-01-26 18:15:30

📊 System Summary:
   • Total Bots: 2
   • Running: 2 ✅
   • Stopped: 0 ⭐
   • Memory Total: 83.9MB
   • System Load: 0.15
```

## 🤝 Support & Contributing

- **GitHub Repository**: [sparrow9616/monitor_bots](https://github.com/sparrow9616/monitor_bots)
- **Issues & Bugs**: Submit via GitHub Issues
- **Feature Requests**: Enhancement requests welcome
- **Documentation**: README updates and improvements appreciated

## 📝 Changelog

### v1.0 - Management & Selection Features
- ➕ Interactive bot selection during deployment
- ➕ Management interface for existing setups  
- ➕ Smart .env configuration validation
- ➕ Bot removal functionality
- ➕ Complete setup reinstall option
- ➕ Enhanced bot detection with validation feedback
- 🔧 Improved error handling and user feedback
- 🔧 Better configuration validation and warnings

### v0.9 - Initial Release
- ✅ Auto-detection of bot directories
- ✅ Supervisor configuration and management
- ✅ Real-time monitoring with colored output
- ✅ Automated cron jobs for maintenance
- ✅ Log rotation and cleanup
- ✅ Multi-VPS deployment support

---

**Made with ❤️ for the music bot community**
