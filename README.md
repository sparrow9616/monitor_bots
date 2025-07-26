# 🎵 Music Bot Supervisor Setup - One-Click Deployment

A comprehensive solution for managing music bots across multiple VPS servers with supervisor, monitoring, and automated management.

**🚀 Quick start:** `curl -sSL https://raw.githubusercontent.com/sparrow9616/monitor_bots/main/setup-musicbot-supervisor.sh | sudo bash`

## 🚀 Quick Installation

### Method 1: Auto-Detection (Recommended for most users)
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

## 📋 What Gets Installed

- ✅ **Supervisor** - Process management
- ✅ **Auto-detection** - Finds your music bot directories
- ✅ **Monitoring script** - `/root/monitor_all_bots.sh`
- ✅ **Cron jobs** - Automatic restarts and monitoring
- ✅ **Log rotation** - Prevents disk space issues
- ✅ **Process cleanup** - Kills existing tmux sessions

## 🎯 Features

### 🔍 Automatic Detection
- Scans `/root` for directories with `.venv` and music bot files
- Detects AnonXMusic and similar bot structures
- Creates supervisor configurations automatically
- Supports multiple bot architectures

### 📊 Monitoring & Management  
- Real-time bot status monitoring with colorized output
- Memory usage tracking and alerts
- Error count monitoring and reporting
- Automatic restart of failed bots
- Process uptime tracking
- Log file management and rotation

### ⏰ Scheduled Operations
- **Every 6 hours**: Restart all bots (12 AM, 6 AM, 12 PM, 6 PM)
- **Every hour**: Health check and auto-restart failed bots
- **Weekly**: Clean old supervisor logs (>7 days)
- **Monthly**: Clean old monitoring logs (>30 days)

### 🔧 Process Management
- **Tmux Cleanup**: Automatically kills existing tmux sessions
- **Orphan Process Cleanup**: Removes leftover bot processes
- **Graceful Transitions**: Smooth migration to supervisor management
- **Zero Downtime**: Maintains bot availability during setup

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

### Option 1: Direct Download (Fastest)
On each VPS:
```bash
wget https://raw.githubusercontent.com/sparrow9616/monitor_bots/main/setup-musicbot-supervisor.sh
sudo bash setup-musicbot-supervisor.sh
```

### Option 2: Custom Configuration (Recommended for multiple similar setups)
1. Download the files:
```bash
wget https://raw.githubusercontent.com/sparrow9616/monitor_bots/main/setup-musicbot-supervisor.sh
wget https://raw.githubusercontent.com/sparrow9616/monitor_bots/main/bot-config.conf
```
2. Edit `bot-config.conf` with your bot configurations
3. Run: `sudo bash setup-musicbot-supervisor.sh`

### Option 3: Interactive Setup (For complex configurations)
```bash
sudo bash setup-musicbot-supervisor.sh --interactive
```

### Option 4: Bulk Deployment
For multiple VPS servers, you can create a deployment script:
```bash
#!/bin/bash
# Deploy to multiple servers
servers=("server1.com" "server2.com" "server3.com")

for server in "${servers[@]}"; do
    echo "Deploying to $server..."
    ssh root@$server "curl -sSL https://raw.githubusercontent.com/sparrow9616/monitor_bots/main/setup-musicbot-supervisor.sh | bash"
done
```

## 📧 Support

If you encounter issues:
1. Check the setup log: `/tmp/musicbot-setup.log`
2. Verify bot directories exist and have `.venv` folders
3. Ensure running as root
4. Check system compatibility (Ubuntu/Debian)
5. Create an issue on GitHub: [sparrow9616/monitor_bots](https://github.com/sparrow9616/monitor_bots/issues)

## 🔗 Repository

- **GitHub**: [sparrow9616/monitor_bots](https://github.com/sparrow9616/monitor_bots)
- **Issues**: [Report bugs or request features](https://github.com/sparrow9616/monitor_bots/issues)

## 🔖 Version Information

- **Version**: 1.0
- **Tested on**: Ubuntu 22.04, Ubuntu 20.04, Debian 11
- **Requirements**: Root access, systemd, supervisor
- **Compatible with**: AnonXMusic, YukkiMusic, and similar Python music bots

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📜 License

This project is open source and available under the [MIT License](LICENSE).

## ⭐ Show Your Support

If this project helped you, please give it a ⭐ on GitHub!

---

**Made with ❤️ for easy music bot deployment**
