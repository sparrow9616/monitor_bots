# 🎵 Music Bot All-in-One Manager

Complete solution for deploying, managing, and monitoring Telegram music bots with supervisor integration.

## 🔥 Recent Updates (v2.1)

- **🐛 Fixed Critical Status Bug** - Resolved issue where bots showed "ERROR" instead of "RUNNING"
- **🔧 Enhanced Supervisor Integration** - Smart detection with multiple naming conventions
- **🎯 Improved Bot Detection** - Compatible with existing supervisor configurations
- **✅ Comprehensive Testing** - Added integration testing and validation tools
- **📚 Complete Documentation** - Enhanced guides and troubleshooting

## ✨ Features

- **🚀 New VPS Setup** - Automated system setup with all dependencies
- **🎵 Single Bot Deployment** - Interactive deployment of individual bots
- **📦 Batch Deployment** - Deploy multiple bots from configuration file
- **🔧 Supervisor Integration** - Automatic process management and monitoring
- **📊 Real-time Monitoring** - Beautiful dashboard for bot status
- **🤖 Bot Management** - Start/stop/restart individual bots
- **📝 Configuration Management** - Easy .env file editing
- **📄 Log Viewing** - Access bot logs and system information
- **🛠️ Smart Detection** - Multi-format bot name recognition
- **🔄 Auto-Compatibility** - Works with existing supervisor setups

## 🚀 Quick Start

### 1. Download and Setup
```bash
# Download the manager (as root)
wget https://raw.githubusercontent.com/path/musicbot-manager.sh
chmod +x musicbot-manager.sh

# Run the all-in-one manager
sudo ./musicbot-manager.sh
```

### 2. First Time Setup (New VPS)
1. Select **"1. New VPS Setup"** from the menu
2. Install system dependencies automatically
3. Follow the prompts to deploy your first bot

### 3. Deploy Your First Bot
1. Select **"2. Deploy Single Bot"**
2. Enter bot name (e.g., `mybot`)
3. Enter repository URL
4. Set up supervisor integration
5. Edit the generated `.env` file

## 📋 Menu Options

### 1. 🚀 New VPS Setup
- Installs Python 3, pip, venv
- Installs FFmpeg, Git, build tools
- Configures Supervisor service
- Sets up monitoring tools

### 2. 🎵 Deploy Single Bot
- Interactive bot deployment
- Repository cloning with branch selection
- Virtual environment setup
- Dependency installation
- .env template generation

### 3. 📦 Batch Deploy Bots
- Deploy multiple bots from config file
- Support for GitHub private repositories
- Complete .env configuration
- Automated batch processing

### 4. 📝 Create Config Template
- Generates comprehensive config template
- GitHub credentials support
- Multiple bot examples
- Complete .env settings

### 5. 🔧 Supervisor Management
- Setup supervisor for all bots
- Start/stop/restart all bots
- Individual bot supervisor config
- Supervisor status monitoring

### 6. 📊 Monitor Bots
- Real-time monitoring dashboard
- Bot status overview
- System resource usage
- Log file access

### 7. 🤖 Bot Management
- Individual bot control
- Start/stop/restart specific bots
- Edit .env files
- View bot-specific logs

### 8. 💻 System Info
- Deployment summary
- System resource usage
- Quick command reference
- Bot status overview
- **Smart Status Detection** - Shows correct RUNNING/ERROR status

### 9. 🧪 Exit
- Clean exit from the manager

## 🛠️ Bug Fixes & Improvements

### Critical Bug Fixes (v2.1)
- **Fixed Status Detection**: Resolved issue where all bots showed "ERROR" status instead of "RUNNING"
- **Supervisor Integration**: Enhanced compatibility with existing supervisor configurations
- **Smart Bot Detection**: Added multi-format bot name recognition:
  - Group format: `musicbots:botname-musicbot`
  - Simple format: `botname`
  - Alternative format: `botname-musicbot`

### Enhanced Features
- **Integration Testing**: Added comprehensive testing script (`test-integration.sh`)
- **Improved Error Handling**: Better error messages and fallback options
- **Documentation**: Complete guides and troubleshooting sections
- **Validation Tools**: Built-in system validation and health checks

## 📝 Configuration File Format

Create `musicbots-config.txt` for batch deployment:

```ini
# GitHub Credentials (for private repositories)
[GITHUB]
USERNAME=your_github_username
PASSWORD=your_github_password_or_token

# Bot 1 Configuration
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
DURATION_LIMIT_MIN=60
QUEUE_LIMIT=10
OWNER_ID=123456789
SUDO_USERS=123456789,987654321
AUTO_LEAVING_ASSISTANT=True
ASSISTANT_PREFIX=!

# Bot 2 Configuration
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
DURATION_LIMIT_MIN=60
QUEUE_LIMIT=10
OWNER_ID=123456789
SUDO_USERS=123456789,987654321
AUTO_LEAVING_ASSISTANT=True
ASSISTANT_PREFIX=/
```

## 🔧 Command Line Usage

```bash
# Interactive menu (recommended)
sudo ./musicbot-manager.sh

# The script automatically detects missing dependencies
# and guides you through the setup process

# Integration testing (verify all components)
chmod +x test-integration.sh
./test-integration.sh
```

## 🧪 Validation & Testing

### Integration Testing
The manager includes comprehensive testing tools:

```bash
# Run integration tests
./test-integration.sh
```

Test Coverage:
- ✅ Supervisor service status
- ✅ Bot detection and counting
- ✅ Status display accuracy
- ✅ Monitoring script functionality
- ✅ Directory structure validation

### Expected Results
After successful deployment and bug fixes:
```
✅ Supervisor is running
✅ Found X bot(s) in supervisor  
✅ System info shows bot status correctly
✅ Monitoring script exists and is executable
✅ Bot directories exist with proper structure
```

## 📁 Directory Structure

After deployment, your bots will be organized as:

```
/root/
├── bot1/
│   ├── .venv/          # Virtual environment
│   ├── .env            # Bot configuration
│   ├── main.py         # Bot main file
│   └── ...             # Bot files
├── bot2/
│   ├── .venv/
│   ├── .env
│   └── ...
└── monitor_all_bots.sh # Monitoring dashboard
```

## 📊 Monitoring Dashboard

The manager creates a real-time monitoring dashboard:

```bash
# Run the monitoring dashboard
/root/monitor_all_bots.sh
```

Features:
- Live bot status updates
- System resource monitoring
- Uptime tracking
- Quick command reference
- Auto-refresh every 5 seconds

## 🔧 Supervisor Integration

Automatic supervisor configuration provides:
- **Auto-start**: Bots start automatically on boot
- **Auto-restart**: Automatic restart on crashes
- **Log management**: Centralized logging
- **Process monitoring**: Real-time status tracking

### Supervisor Commands
```bash
# View all bot status
supervisorctl status

# Start/stop/restart specific bot
supervisorctl start botname
supervisorctl stop botname
supervisorctl restart botname

# Start/stop/restart all bots
supervisorctl start all
supervisorctl stop all
supervisorctl restart all

# View logs
tail -f /var/log/supervisor/botname.out.log
tail -f /var/log/supervisor/botname.err.log
```

## 📋 Requirements

### System Requirements
- Ubuntu/Debian Linux
- Root access
- Internet connection
- 1GB+ RAM (recommended)
- 10GB+ disk space

### Bot Requirements
- Telegram API credentials (API_ID, API_HASH)
- Bot token from @BotFather
- MongoDB (optional, for some bots)

## 🆘 Troubleshooting

### Recent Bug Fixes

1. **Bot Status Shows "ERROR" Instead of "RUNNING"** ✅ FIXED
   - **Issue**: Status detection incompatible with supervisor group format
   - **Solution**: Enhanced smart detection with multiple naming conventions
   - **Result**: Now correctly shows "RUNNING - uptime" for active bots

2. **Supervisor Integration Issues** ✅ FIXED
   - **Issue**: Mismatch between manager and existing supervisor setup
   - **Solution**: Multi-format bot name detection and fallback options
   - **Result**: Full compatibility with existing configurations

### Common Issues

1. **Permission Denied**
   ```bash
   sudo chmod +x musicbot-manager.sh
   sudo ./musicbot-manager.sh
   ```

2. **Repository Access Issues**
   - For private repos, configure GitHub credentials in config file
   - Ensure repository URL is correct and accessible

3. **Bot Won't Start**
   - Check .env file configuration
   - Verify bot token and API credentials
   - View logs: `tail -f /var/log/supervisor/botname.err.log`

4. **Dependencies Not Installing**
   - Run "New VPS Setup" to install system dependencies
   - Check Python virtual environment activation

5. **Status Still Shows ERROR** (If issues persist)
   ```bash
   # Check supervisor status directly
   supervisorctl status
   
   # Verify bot processes
   ps aux | grep python | grep -v grep
   
   # Run integration test
   ./test-integration.sh
   ```

### Log Locations
- Supervisor logs: `/var/log/supervisor/`
- Manager logs: `/tmp/musicbot-manager.log`
- Individual bot logs: `/var/log/supervisor/botname.out.log`
- Integration test logs: Console output

### Validation Commands
```bash
# Check if all components are working
./test-integration.sh

# Manual supervisor check
supervisorctl status | grep -E "(RUNNING|STOPPED|ERROR)"

# Check system info menu
sudo ./musicbot-manager.sh # Then select option 8
```

## 🎯 Advanced Usage

### Multiple Bot Management
1. Use batch deployment for multiple bots
2. Configure supervisor for all bots
3. Use monitoring dashboard for overview
4. Individual management through bot menu

### Private Repository Support
1. Add GitHub credentials to config file
2. Use HTTPS repository URLs
3. Manager handles authentication automatically

### Custom Configuration
1. Edit .env files after deployment
2. Restart bots to apply changes
3. Use bot management menu for easy access

## 📚 Examples

### Deploy Single Bot
1. Run manager: `sudo ./musicbot-manager.sh`
2. Select option 2 (Deploy Single Bot)
3. Enter bot name: `mybot`
4. Enter repo URL: `https://github.com/user/musicbot`
5. Configure supervisor and edit .env

### Batch Deploy Multiple Bots
1. Create config: Select option 4 (Create Config Template)
2. Edit `musicbots-config.txt` with your bot configurations
3. Deploy: Select option 3 (Batch Deploy Bots)
4. Setup supervisor: Select option 5 (Supervisor Management)

### Monitor and Manage
1. Monitor: Select option 6 or run `/root/monitor_all_bots.sh`
2. Manage: Select option 7 for individual bot control
3. System info: Select option 8 for overview

## 🏆 Best Practices

1. **Always backup .env files** before making changes
2. **Use unique bot names** to avoid conflicts
3. **Monitor system resources** for optimal performance
4. **Keep repositories updated** for security
5. **Use supervisor commands** for production management
6. **Run integration tests** after major changes
7. **Check status regularly** using the system info menu
8. **Validate deployments** with the testing tools

## 📈 Version History

### v2.1 (Current) - Bug Fix Release
- ✅ Fixed critical status detection bug
- ✅ Enhanced supervisor integration
- ✅ Added comprehensive testing tools
- ✅ Improved error handling and compatibility
- ✅ Complete documentation overhaul

### v2.0 - All-in-One Release
- 🚀 Initial all-in-one manager release
- 📦 Batch deployment support
- 🔧 Supervisor integration
- 📊 Monitoring dashboard
- 🤖 Individual bot management

## 🤝 Support

For issues or questions:
1. **First**: Run integration test: `./test-integration.sh`
2. Check the troubleshooting section above
3. Review log files for error details
4. Ensure system requirements are met
5. Verify bot configuration and credentials
6. Check recent bug fixes section for known issues

---

**Happy botting! 🎵** This all-in-one manager simplifies the entire process from VPS setup to bot monitoring, making music bot deployment and management effortless. Version 2.1 includes critical bug fixes ensuring perfect supervisor integration and accurate status reporting.
