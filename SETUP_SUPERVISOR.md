# 🎵 Music Bot Supervisor Setup

One-click deployment for music bot management with supervisor monitoring and automated restarts.

**🚀 Quick start:** `curl -sSL https://raw.githubusercontent.com/sparrow9616/monitor_bots/main/setup-musicbot-supervisor.sh | sudo bash`

## ✨ Features

- **🎯 Interactive Bot Selection** - Choose which bots to deploy
- **🛠 Setup Management** - Add/remove bots from existing setups
- **🔍 Smart Detection** - Auto-finds and validates bot directories
- **📊 Real-time Monitoring** - Beautiful dashboard with status and metrics
- **🔄 Auto-restart** - Handles crashes and scheduled maintenance

## 🚀 Installation

```bash
# Auto-detection with interactive selection (recommended)
wget https://raw.githubusercontent.com/sparrow9616/monitor_bots/main/setup-musicbot-supervisor.sh
chmod +x setup-musicbot-supervisor.sh
sudo ./setup-musicbot-supervisor.sh

# One-liner installation
curl -sSL https://raw.githubusercontent.com/sparrow9616/monitor_bots/main/setup-musicbot-supervisor.sh | sudo bash

# Interactive configuration
sudo ./setup-musicbot-supervisor.sh --interactive
```

## 🛠 Management

### Fresh Installation
1. Auto-detects bot directories with `.venv` and `.env` files
2. Shows interactive selection menu
3. Validates configuration (API_ID, BOT_TOKEN, etc.)
4. Sets up supervisor, monitoring, and cron jobs

### Existing Setup Management
```
Setup Management Options:
  1 - Add new bots to existing setup
  2 - Remove existing bots  
  3 - Completely reinstall (remove all and start fresh)
  4 - Continue with current setup (no changes)
  5 - Exit
```

## 📊 Monitoring Dashboard

```
🎵 Music Bot Monitor - Real-time Status 🎵
═══════════════════════════════════════════════════════════

Bot: amiop
├─ Status: ✅ RUNNING (PID: 12345, Uptime: 2h 15m)
├─ Memory: 🟢 45.2MB (Normal)
├─ Errors: 🟡 3 recent errors
└─ Last Check: 2025-01-26 18:15:30

� System Summary:
   • Total Bots: 2
   • Running: 2 ✅
   • Memory Total: 83.9MB
   • System Load: 0.15
```

## � Quick Commands

```bash
# Monitor all bots
/root/monitor_all_bots.sh

# Control bots
/root/monitor_all_bots.sh start <bot-name>
/root/monitor_all_bots.sh stop <bot-name>
/root/monitor_all_bots.sh restart <bot-name>

# Bulk operations
/root/monitor_all_bots.sh start all
/root/monitor_all_bots.sh stop all

# View logs
/root/monitor_all_bots.sh logs <bot-name>
/root/monitor_all_bots.sh tail <bot-name>

# Direct supervisor commands
sudo supervisorctl status musicbots:*
sudo supervisorctl restart musicbots:*
```

## ⏰ Automated Features

- **🔄 Auto-restart**: Every 6 hours to prevent memory leaks
- **📊 Health monitoring**: Every hour with logging
- **🧹 Log cleanup**: Automatic rotation and old file removal
- **📝 Error tracking**: Monitors and logs bot issues

## � Troubleshooting

```bash
# Check bot status
sudo supervisorctl status

# View setup logs
tail -f /tmp/musicbot-setup.log

# Test bot manually
cd /root/botname
source .venv/bin/activate
python -m AnonXMusic

# Restart supervisor
sudo systemctl restart supervisor
```

## 📋 Requirements

- **OS**: Ubuntu/Debian with root access
- **Bot Structure**: Directories with `.venv` and `.env` files
- **Configuration**: .env must contain API_ID, BOT_TOKEN, SESSION, DATABASE

## 📂 Key Files

- **Supervisor Config**: `/etc/supervisor/conf.d/musicbots.conf`
- **Monitoring Script**: `/root/monitor_all_bots.sh`
- **Logs**: `/var/log/supervisor/botname-musicbot.log`

---

**GitHub**: [sparrow9616/monitor_bots](https://github.com/sparrow9616/monitor_bots)
