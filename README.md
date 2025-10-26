# n8n Installation Script with SSL Certificate on Ubuntu VPS

🚀 **One-command installation script** to set up n8n workflow automation platform on Ubuntu VPS with Nginx reverse proxy and SSL certificate.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20|%2022.04%20|%2024.04-orange)](https://ubuntu.com/)
[![n8n](https://img.shields.io/badge/n8n-latest-blue)](https://n8n.io/)

## 📋 Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [What Gets Installed](#what-gets-installed)
- [Configuration](#configuration)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)
- [Backup & Restore](#backup--restore)
- [Updating n8n](#updating-n8n)
- [Uninstallation](#uninstallation)
- [Contributing](#contributing)
- [License](#license)

## ✨ Features

- 🐳 **Docker-based installation** - Isolated and easy to manage
- 🔒 **Automatic SSL certificate** - Free Let's Encrypt SSL with auto-renewal
- 🔄 **Nginx reverse proxy** - Professional HTTP/HTTPS setup on port 80/443
- 🛡️ **Firewall configuration** - UFW automatically configured
- 📦 **Optimized configuration** - All recommended n8n settings included
- 🔐 **Basic authentication** - Secure login out of the box
- 💾 **Automatic backups** - Daily backup script included
- ⚡ **Production-ready** - Task runners, connection pooling, and security hardening
- 📝 **Fully commented** - Every command explained in detail
- 🔧 **Error handling** - Robust installation with fallback options

## 🎯 Prerequisites

- **Ubuntu VPS** (20.04, 22.04, or 24.04)
- **Root or sudo access**
- **Domain name** pointed to your VPS IP address
- **Minimum 1GB RAM** (2GB recommended)
- **At least 10GB disk space**

## 🚀 Quick Start

### Step 1: Configure DNS

Before running the script, ensure your domain's A record points to your VPS IP:

```
Type: A
Name: n8n (or your subdomain)
Value: YOUR_VPS_IP
TTL: 3600
```

Verify DNS propagation:
```bash
dig n8n.yourdomain.com +short
# Should return your VPS IP
```

### Step 2: Download and Run the Script

```bash
# Download the script
wget https://raw.githubusercontent.com/Muminur/install-n8n-with-ssl-certificate-on-Ubuntu-VPS/main/install-n8n.sh

# Make it executable
chmod +x install-n8n.sh

# Run the script as root
sudo bash install-n8n.sh
```

### Step 3: Follow the Prompts

The script will ask for:
- Domain name (e.g., `n8n.yourdomain.com`)
- VPS IP address (e.g., `74.208.132.120`)
- Email address (for SSL certificate notifications)
- n8n admin username (default: `admin`)
- n8n admin password
- Timezone (default: `Asia/Dhaka`)

### Step 4: Access n8n

After installation completes, access n8n at:
- **URL:** `https://n8n.yourdomain.com`
- **Username:** Your chosen username
- **Password:** Your chosen password

## 📦 What Gets Installed

The script automatically installs and configures:

1. **Docker** - Latest stable version
2. **Docker Compose** - Latest version from GitHub releases
3. **n8n** - Latest version via Docker
4. **Nginx** - Web server and reverse proxy
5. **Certbot** - SSL certificate management
6. **UFW Firewall** - Ports 80, 443, and 22 configured
7. **Backup Script** - Automated daily backups at 2 AM

## ⚙️ Configuration

### Default Configuration

The installation includes these optimized settings:

```yaml
Environment Variables:
- N8N_BASIC_AUTH_ACTIVE=true
- N8N_PROTOCOL=https
- DB_SQLITE_POOL_SIZE=3
- N8N_RUNNERS_ENABLED=true
- N8N_BLOCK_ENV_ACCESS_IN_NODE=false
- N8N_GIT_NODE_DISABLE_BARE_REPOS=true
```

### Installation Directory

All n8n files are located at:
```
/root/n8n/
├── docker-compose.yml
└── data/
    └── (n8n data files)
```

### Nginx Configuration

Located at: `/etc/nginx/sites-available/n8n`

### SSL Certificates

Located at: `/etc/letsencrypt/live/yourdomain.com/`

## 📚 Usage

### Useful Commands

```bash
# View n8n logs
cd /root/n8n && docker compose logs -f

# Restart n8n
cd /root/n8n && docker compose restart

# Stop n8n
cd /root/n8n && docker compose down

# Start n8n
cd /root/n8n && docker compose up -d

# Update n8n to latest version
cd /root/n8n && docker compose pull && docker compose up -d

# Manual backup
/usr/local/bin/n8n-backup.sh

# Check Nginx configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx

# Renew SSL certificate manually
sudo certbot renew

# Check SSL certificates
sudo certbot certificates
```

### Accessing Logs

```bash
# n8n logs
docker logs n8n -f

# Nginx access logs
tail -f /var/log/nginx/access.log

# Nginx error logs
tail -f /var/log/nginx/error.log

# System logs
journalctl -u nginx -f
```

## 🔧 Troubleshooting

### SSL Certificate Installation Failed

If SSL installation fails during setup:

1. **Verify DNS is correct:**
   ```bash
   dig yourdomain.com +short
   ```

2. **Retry SSL installation manually:**
   ```bash
   sudo certbot --nginx -d yourdomain.com
   ```

3. **Check Certbot logs:**
   ```bash
   sudo cat /var/log/letsencrypt/letsencrypt.log
   ```

### n8n Container Not Starting

```bash
# Check container status
docker ps -a

# View container logs
docker logs n8n

# Check permissions
ls -la /root/n8n/data
sudo chown -R 1000:1000 /root/n8n/data
```

### Port Already in Use

```bash
# Check what's using port 5678
sudo netstat -tulpn | grep 5678

# Check what's using port 80
sudo netstat -tulpn | grep :80

# Stop conflicting service
sudo systemctl stop apache2  # if Apache is running
```

### Cannot Access n8n

1. **Check firewall:**
   ```bash
   sudo ufw status
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   ```

2. **Check Nginx:**
   ```bash
   sudo systemctl status nginx
   sudo nginx -t
   ```

3. **Check n8n container:**
   ```bash
   docker ps | grep n8n
   ```

4. **Check cloud provider firewall** (AWS Security Groups, DigitalOcean Firewall, etc.)

### Webhooks Not Working

If webhooks aren't triggering:

1. Ensure `WEBHOOK_URL` is correctly set in `/root/n8n/docker-compose.yml`
2. Restart n8n: `cd /root/n8n && docker compose restart`
3. Check webhook URL in n8n matches your domain

## 🔐 Security Best Practices

### Change Default Credentials

After installation, change your admin password:

1. Log in to n8n
2. Go to Settings → Users
3. Update your password

### Update docker-compose.yml

Edit `/root/n8n/docker-compose.yml` to change credentials:
```bash
sudo nano /root/n8n/docker-compose.yml
# Change N8N_BASIC_AUTH_PASSWORD
cd /root/n8n && docker compose down && docker compose up -d
```

### Additional Security Measures

1. **Disable root login via SSH:**
   ```bash
   sudo nano /etc/ssh/sshd_config
   # Set: PermitRootLogin no
   sudo systemctl restart sshd
   ```

2. **Enable fail2ban:**
   ```bash
   sudo apt install fail2ban -y
   sudo systemctl enable fail2ban
   ```

3. **Regular updates:**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

## 💾 Backup & Restore

### Automatic Backups

Backups run daily at 2 AM and are stored in `/var/backups/n8n/`

### Manual Backup

```bash
# Run backup script
/usr/local/bin/n8n-backup.sh

# Backups are stored at
ls -lh /var/backups/n8n/
```

### Restore from Backup

```bash
# Stop n8n
cd /root/n8n && docker compose down

# Extract backup
tar -xzf /var/backups/n8n/n8n-data-YYYYMMDD_HHMMSS.tar.gz -C /root/n8n/

# Fix permissions
sudo chown -R 1000:1000 /root/n8n/data

# Start n8n
docker compose up -d
```

### Backup to Remote Location

Add to crontab for remote backups:
```bash
# Example: Backup to S3
0 3 * * * aws s3 cp /var/backups/n8n/ s3://your-bucket/n8n-backups/ --recursive
```

## 🔄 Updating n8n

### Update to Latest Version

```bash
cd /root/n8n
docker compose pull
docker compose up -d
```

### Update to Specific Version

Edit `/root/n8n/docker-compose.yml`:
```yaml
services:
  n8n:
    image: n8nio/n8n:1.0.0  # Specify version
```

Then:
```bash
cd /root/n8n
docker compose up -d
```

### Check Current Version

```bash
docker exec n8n n8n --version
```

## 🗑️ Uninstallation

To completely remove n8n:

```bash
# Stop and remove containers
cd /root/n8n
docker compose down

# Remove n8n directory
rm -rf /root/n8n

# Remove Docker images
docker rmi n8nio/n8n

# Remove Nginx configuration
sudo rm /etc/nginx/sites-available/n8n
sudo rm /etc/nginx/sites-enabled/n8n
sudo systemctl reload nginx

# Remove SSL certificate (optional)
sudo certbot delete --cert-name yourdomain.com

# Remove backup script
sudo rm /usr/local/bin/n8n-backup.sh
crontab -e  # Remove backup cron job

# Optional: Remove Docker completely
sudo apt remove docker docker-compose nginx certbot -y
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 Changelog

### Version 1.0.0 (2025-01-XX)
- Initial release
- Docker-based n8n installation
- Nginx reverse proxy configuration
- SSL certificate with Let's Encrypt
- Automatic daily backups
- Comprehensive error handling

## 🐛 Bug Reports

Found a bug? Please open an issue on GitHub with:
- Your Ubuntu version
- Error messages (if any)
- Steps to reproduce
- Expected vs actual behavior

## 💬 Support

- **Issues:** [GitHub Issues](https://github.com/Muminur/install-n8n-with-ssl-certificate-on-Ubuntu-VPS/issues)
- **n8n Community:** [n8n Community Forum](https://community.n8n.io/)
- **n8n Documentation:** [n8n Docs](https://docs.n8n.io/)

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [n8n](https://n8n.io/) - Workflow automation platform
- [Docker](https://www.docker.com/) - Containerization platform
- [Nginx](https://nginx.org/) - Web server
- [Let's Encrypt](https://letsencrypt.org/) - Free SSL certificates
- [Certbot](https://certbot.eff.org/) - SSL certificate management

## ⭐ Star History

If this script helped you, please consider giving it a star! ⭐

---

**Made with ❤️ by [Muminur](https://github.com/Muminur)**

**Need help?** Open an issue or reach out!
