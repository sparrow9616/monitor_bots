# 🎵 Music Bot Supervisor Setup - One-Click Deployment

A comprehensive solution for managing music bots across multiple VPS servers with supervisor, monitoring, and automated management.

## 🚀 Quick Installation

### Method 1: Auto-Detection (Recommended for most users)
```bash
# Download and run the setup script
wget https://raw.githubusercontent.com/your-repo/setup-musicbot-supervisor.sh
chmod +x setup-musicbot-supervisor.sh
sudo ./setup-musicbot-supervisor.sh
```

### Method 2: One-liner Installation
```bash
curl -sSL https://raw.githubusercontent.com/your-repo/setup-musicbot-supervisor.sh | sudo bash
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

## 📋 What Gets Installed

- ✅ **Supervisor** - Process management
- ✅ **Auto-detection** - Finds your music bot directories
- ✅ **Monitoring script** - `/root/monitor_all_bots.sh`
- ✅ **Cron jobs** - Automatic restarts and monitoring
- ✅ **Log rotation** - Prevents disk space issues
- ✅ **Process cleanup** - Kills existing tmux sessions

## 🎯 Features

### Automatic Detection
- Scans `/root` for directories with `.venv` and music bot files
- Detects AnonXMusic and similar bot structures
- Creates supervisor configurations automatically

### Monitoring & Management
- Real-time bot status monitoring
- Memory usage tracking
- Error count monitoring
- Automatic restart of failed bots
- Colorized output with status indicators

### Scheduled Operations
- **Every 6 hours**: Restart all bots (12 AM, 6 AM, 12 PM, 6 PM)
- **Every hour**: Check and restart failed bots
- **Weekly**: Clean old supervisor logs (>7 days)
- **Monthly**: Clean old monitoring logs (>30 days)

### Command Line Interface
```bash
# Monitor all bots
/root/monitor_all_bots.sh

# Start/stop/restart bots
/root/monitor_all_bots.sh start all
/root/monitor_all_bots.sh stop botname
/root/monitor_all_bots.sh restart all

# View logs
/root/monitor_all_bots.sh logs botname
/root/monitor_all_bots.sh tail botname

# Auto-restart failed bots
/root/monitor_all_bots.sh auto-restart
```

## ⚙️ Configuration Options

### Bot Configuration Format
In `bot-config.conf`:
```bash
BOTS=(
    "botname1:/root/botname1"
    "botname2:/root/botname2"
    "mybotname:/home/user/mybotname"
)
```

### Customizable Settings
- **BOT_MODULE**: Python module name (default: AnonXMusic)
- **RESTART_SCHEDULE**: Cron schedule for restarts
- **LOG_RETENTION_DAYS**: Days to keep supervisor logs
- **MONITOR_LOG_RETENTION_DAYS**: Days to keep monitoring logs

## 📁 File Structure

```
/etc/supervisor/conf.d/musicbots.conf    # Supervisor configuration
/root/monitor_all_bots.sh                # Monitoring script
/var/log/supervisor/                     # Bot logs
/var/log/bot_restart.log                 # Restart log
/var/log/bot_monitor.log                 # Monitoring log
/tmp/musicbot-setup.log                  # Setup log
```

## 🔧 Troubleshooting

### Check Setup Log
```bash
tail -f /tmp/musicbot-setup.log
```

### Manual Supervisor Commands
```bash
# Check status
supervisorctl status

# Start all bots
supervisorctl start musicbots:*

# Restart specific bot
supervisorctl restart musicbots:botname-musicbot

# View real-time logs
supervisorctl tail -f musicbots:botname-musicbot
```

### Check Cron Jobs
```bash
# View installed cron jobs
crontab -l

# Check cron logs
tail -f /var/log/bot_monitor.log
tail -f /var/log/bot_restart.log
```

## 🎉 Success Indicators

After successful installation, you should see:
- ✅ All bots showing as "RUNNING" in supervisor
- ✅ Monitoring script working without errors
- ✅ Cron jobs scheduled
- ✅ Log files being created

## 🔄 Deployment Across Multiple VPS

### Option 1: Direct Download
On each VPS:
```bash
wget https://your-server.com/setup-musicbot-supervisor.sh
sudo bash setup-musicbot-supervisor.sh
```

### Option 2: Custom Configuration
1. Create your custom `bot-config.conf`
2. Upload both files to each VPS
3. Run: `sudo bash setup-musicbot-supervisor.sh`

### Option 3: Interactive Setup
```bash
sudo bash setup-musicbot-supervisor.sh --interactive
```

## 📧 Support

If you encounter issues:
1. Check the setup log: `/tmp/musicbot-setup.log`
2. Verify bot directories exist and have `.venv` folders
3. Ensure running as root
4. Check system compatibility (Ubuntu/Debian)

## 🔖 Version Information

- **Version**: 1.0
- **Tested on**: Ubuntu 22.04, Ubuntu 20.04, Debian 11
- **Requirements**: Root access, systemd, supervisor

---

**Made with ❤️ for easy music bot deployment**
