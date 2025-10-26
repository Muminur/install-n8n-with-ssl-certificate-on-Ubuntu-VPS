#!/bin/bash

################################################################################
# n8n Installation Script with Nginx Reverse Proxy and SSL
# 
# This script automates the installation of n8n using Docker with:
# - Docker and Docker Compose installation
# - n8n container setup with optimized configuration
# - Nginx reverse proxy on port 80/443
# - Let's Encrypt SSL certificate
#
# Based on successful commands from the conversation:
# - Docker installed with get.docker.com script
# - Docker Compose installed from GitHub releases
# - Nginx reverse proxy configured successfully
# - SSL attempted (manual installation required if auto fails)
#
# Usage: sudo bash install-n8n.sh
################################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root (use sudo)"
   exit 1
fi

################################################################################
# STEP 1: Collect User Input
################################################################################

echo "================================================"
echo "   n8n Installation Script"
echo "================================================"
echo ""

# Get domain name
read -p "Enter your domain name (e.g., n8n.yourdomain.com): " DOMAIN_NAME
if [[ -z "$DOMAIN_NAME" ]]; then
    print_error "Domain name cannot be empty"
    exit 1
fi

# Get VPS IP address
read -p "Enter your VPS IP address (e.g., 74.208.132.120): " VPS_IP
if [[ -z "$VPS_IP" ]]; then
    print_error "VPS IP address cannot be empty"
    exit 1
fi

# Get email for SSL certificate
read -p "Enter your email address (for SSL certificate notifications): " SSL_EMAIL
if [[ -z "$SSL_EMAIL" ]]; then
    print_error "Email address cannot be empty"
    exit 1
fi

# Get n8n admin credentials
read -p "Enter n8n admin username [default: admin]: " N8N_USERNAME
N8N_USERNAME=${N8N_USERNAME:-admin}

read -sp "Enter n8n admin password: " N8N_PASSWORD
echo ""
if [[ -z "$N8N_PASSWORD" ]]; then
    print_error "Password cannot be empty"
    exit 1
fi

# Get timezone (default to Asia/Dhaka based on conversation)
read -p "Enter your timezone [default: Asia/Dhaka]: " TIMEZONE
TIMEZONE=${TIMEZONE:-Asia/Dhaka}

echo ""
print_info "Configuration Summary:"
echo "  Domain: $DOMAIN_NAME"
echo "  VPS IP: $VPS_IP"
echo "  Email: $SSL_EMAIL"
echo "  Username: $N8N_USERNAME"
echo "  Timezone: $TIMEZONE"
echo ""
read -p "Continue with installation? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    print_error "Installation cancelled"
    exit 1
fi

################################################################################
# STEP 2: Verify DNS Resolution
################################################################################

print_info "Checking DNS resolution for $DOMAIN_NAME..."
RESOLVED_IP=$(dig +short "$DOMAIN_NAME" | tail -n1)

if [[ -z "$RESOLVED_IP" ]]; then
    print_error "Domain $DOMAIN_NAME does not resolve to any IP address"
    print_info "Please configure your DNS A record to point to $VPS_IP"
    read -p "Continue anyway? (y/n): " DNS_CONTINUE
    if [[ "$DNS_CONTINUE" != "y" && "$DNS_CONTINUE" != "Y" ]]; then
        exit 1
    fi
elif [[ "$RESOLVED_IP" != "$VPS_IP" ]]; then
    print_error "Domain resolves to $RESOLVED_IP but you specified $VPS_IP"
    print_info "Please verify your DNS settings"
    read -p "Continue anyway? (y/n): " DNS_CONTINUE
    if [[ "$DNS_CONTINUE" != "y" && "$DNS_CONTINUE" != "Y" ]]; then
        exit 1
    fi
else
    print_success "DNS configured correctly: $DOMAIN_NAME → $VPS_IP"
fi

################################################################################
# STEP 3: Update System and Install Prerequisites
################################################################################

print_info "Updating system packages..."
apt update
apt upgrade -y
print_success "System updated"

# Install required packages
print_info "Installing prerequisites..."
apt install -y curl wget git ufw nginx certbot python3-certbot-nginx
print_success "Prerequisites installed"

################################################################################
# STEP 4: Install Docker
# Based on conversation: Used curl -fsSL https://get.docker.com
################################################################################

print_info "Installing Docker..."
if command -v docker &> /dev/null; then
    print_success "Docker already installed"
    docker --version
else
    # Download and run Docker installation script
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    
    # Start and enable Docker service
    systemctl start docker
    systemctl enable docker
    
    print_success "Docker installed successfully"
    docker --version
fi

################################################################################
# STEP 5: Install Docker Compose
# Based on conversation: Installed from GitHub releases (not apt package)
################################################################################

print_info "Installing Docker Compose..."
if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    print_success "Docker Compose already installed"
else
    # Install Docker Compose from GitHub releases
    # This worked in the conversation, not the apt package
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Also install as Docker plugin (v2 method)
    mkdir -p /root/.docker/cli-plugins
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /root/.docker/cli-plugins/docker-compose
    chmod +x /root/.docker/cli-plugins/docker-compose
    
    print_success "Docker Compose installed successfully"
fi

# Verify installation
docker compose version || docker-compose version

################################################################################
# STEP 6: Configure Firewall
# Based on conversation: Opened ports 80, 443, and initially 5678
################################################################################

print_info "Configuring firewall..."

# Enable UFW if not already enabled
if ! ufw status | grep -q "Status: active"; then
    # Allow SSH first to avoid lockout
    ufw allow 22/tcp
    print_success "SSH port allowed"
fi

# Allow HTTP and HTTPS
ufw allow 80/tcp
ufw allow 443/tcp
print_success "HTTP and HTTPS ports allowed"

# Enable UFW
ufw --force enable
print_success "Firewall configured and enabled"

################################################################################
# STEP 7: Create n8n Directory and Configuration
# Based on conversation: Created ~/n8n directory with data subdirectory
################################################################################

print_info "Creating n8n directory structure..."
N8N_DIR="/root/n8n"
mkdir -p "$N8N_DIR/data"

# Set proper permissions for n8n data directory
# Based on conversation: Fixed permission error with chown 1000:1000
chown -R 1000:1000 "$N8N_DIR/data"
chmod -R 755 "$N8N_DIR/data"
print_success "n8n directory created with proper permissions"

################################################################################
# STEP 8: Create Docker Compose Configuration
# Based on conversation: Final working configuration without version attribute
# and with all recommended environment variables
################################################################################

print_info "Creating Docker Compose configuration..."

cat > "$N8N_DIR/docker-compose.yml" << EOF
services:
  n8n:
    image: n8nio/n8n
    container_name: n8n
    restart: always
    user: "1000:1000"
    ports:
      # Bind to localhost only since Nginx will proxy
      - "127.0.0.1:5678:5678"
    environment:
      # Basic authentication
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=${N8N_USERNAME}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_PASSWORD}
      
      # Host and protocol configuration
      - N8N_HOST=${DOMAIN_NAME}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://${DOMAIN_NAME}/
      
      # Timezone configuration
      - GENERIC_TIMEZONE=${TIMEZONE}
      - TZ=${TIMEZONE}
      
      # Database configuration (fixes deprecation warnings from conversation)
      - DB_SQLITE_POOL_SIZE=3
      
      # Task runners (recommended to enable, fixes deprecation warning)
      - N8N_RUNNERS_ENABLED=true
      
      # Security settings (fixes deprecation warnings)
      - N8N_BLOCK_ENV_ACCESS_IN_NODE=false
      - N8N_GIT_NODE_DISABLE_BARE_REPOS=true
      
    volumes:
      - ./data:/home/node/.n8n
EOF

print_success "Docker Compose configuration created"

################################################################################
# STEP 9: Configure Nginx Reverse Proxy
# Based on conversation: Successfully configured Nginx on port 80
################################################################################

print_info "Configuring Nginx reverse proxy..."

# Create Nginx configuration file
cat > /etc/nginx/sites-available/n8n << EOF
# HTTP server block - will be upgraded to HTTPS by Certbot
server {
    listen 80;
    server_name ${DOMAIN_NAME};

    # For Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        proxy_pass http://localhost:5678;
        proxy_http_version 1.1;
        
        # WebSocket support
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        
        # Proxy headers
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts for long-running workflows
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }
}
EOF

# Enable the site by creating symbolic link
ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n

# Remove default site if it exists
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
if nginx -t; then
    print_success "Nginx configuration is valid"
else
    print_error "Nginx configuration test failed"
    exit 1
fi

# Reload Nginx
systemctl reload nginx
print_success "Nginx configured and reloaded"

################################################################################
# STEP 10: Start n8n Container
# Based on conversation: Used docker compose (not docker-compose with hyphen)
################################################################################

print_info "Starting n8n container..."
cd "$N8N_DIR"

# Pull the latest n8n image
docker compose pull

# Start n8n in detached mode
docker compose up -d

# Wait for n8n to start
print_info "Waiting for n8n to initialize..."
sleep 10

# Check if container is running
if docker ps | grep -q n8n; then
    print_success "n8n container started successfully"
else
    print_error "Failed to start n8n container"
    print_info "Check logs with: docker compose logs"
    exit 1
fi

################################################################################
# STEP 11: Install SSL Certificate
# Based on conversation: Certbot had issues, so we try multiple methods
################################################################################

print_info "Installing SSL certificate..."

# Method 1: Try automatic nginx mode first
if certbot --nginx -d "$DOMAIN_NAME" --email "$SSL_EMAIL" --agree-tos --non-interactive --redirect; then
    print_success "SSL certificate installed successfully via nginx mode"
    SSL_SUCCESS=true
else
    print_error "Nginx mode failed, trying standalone mode..."
    
    # Method 2: Try standalone mode
    systemctl stop nginx
    if certbot certonly --standalone -d "$DOMAIN_NAME" --email "$SSL_EMAIL" --agree-tos --non-interactive; then
        print_success "SSL certificate obtained via standalone mode"
        
        # Manually configure SSL in Nginx
        cat > /etc/nginx/sites-available/n8n << EOF
# HTTP redirect to HTTPS
server {
    listen 80;
    server_name ${DOMAIN_NAME};
    return 301 https://\$server_name\$request_uri;
}

# HTTPS server block
server {
    listen 443 ssl http2;
    server_name ${DOMAIN_NAME};

    # SSL certificate configuration
    ssl_certificate /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem;
    
    # SSL protocols and ciphers
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # For Let's Encrypt renewal
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        proxy_pass http://localhost:5678;
        proxy_http_version 1.1;
        
        # WebSocket support
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        
        # Proxy headers
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts for long-running workflows
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }
}
EOF
        
        systemctl start nginx
        nginx -t && systemctl reload nginx
        print_success "SSL manually configured in Nginx"
        SSL_SUCCESS=true
    else
        print_error "Failed to obtain SSL certificate"
        systemctl start nginx
        SSL_SUCCESS=false
    fi
fi

# Update n8n configuration based on SSL status
if [[ "$SSL_SUCCESS" = true ]]; then
    print_info "Updating n8n configuration for HTTPS..."
    # Configuration already set to HTTPS in docker-compose.yml
    docker compose down
    docker compose up -d
    print_success "n8n restarted with HTTPS configuration"
else
    print_error "SSL installation failed. Configuring for HTTP only..."
    
    # Update docker-compose.yml for HTTP
    cat > "$N8N_DIR/docker-compose.yml" << EOF
services:
  n8n:
    image: n8nio/n8n
    container_name: n8n
    restart: always
    user: "1000:1000"
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=${N8N_USERNAME}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_PASSWORD}
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - NODE_ENV=production
      - WEBHOOK_URL=http://${DOMAIN_NAME}/
      - GENERIC_TIMEZONE=${TIMEZONE}
      - TZ=${TIMEZONE}
      - DB_SQLITE_POOL_SIZE=3
      - N8N_RUNNERS_ENABLED=true
      - N8N_BLOCK_ENV_ACCESS_IN_NODE=false
      - N8N_GIT_NODE_DISABLE_BARE_REPOS=true
      - N8N_SECURE_COOKIE=false
    volumes:
      - ./data:/home/node/.n8n
EOF
    
    docker compose down
    docker compose up -d
    print_success "n8n configured for HTTP access"
fi

################################################################################
# STEP 12: Setup Auto-Renewal for SSL Certificate
################################################################################

if [[ "$SSL_SUCCESS" = true ]]; then
    print_info "Setting up SSL certificate auto-renewal..."
    
    # Test renewal process
    if certbot renew --dry-run; then
        print_success "SSL auto-renewal configured successfully"
    else
        print_error "SSL auto-renewal test failed"
    fi
fi

################################################################################
# STEP 13: Create Backup Script
# Good practice for production deployments
################################################################################

print_info "Creating backup script..."

cat > /usr/local/bin/n8n-backup.sh << 'EOF'
#!/bin/bash
# n8n Backup Script

BACKUP_DIR="/var/backups/n8n"
DATE=$(date +%Y%m%d_%H%M%S)
N8N_DIR="/root/n8n"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup n8n data directory
echo "Backing up n8n data..."
tar -czf "$BACKUP_DIR/n8n-data-$DATE.tar.gz" -C "$N8N_DIR" data

# Keep only last 7 days of backups
find "$BACKUP_DIR" -name "n8n-data-*.tar.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR/n8n-data-$DATE.tar.gz"
EOF

chmod +x /usr/local/bin/n8n-backup.sh

# Add to crontab for daily backups at 2 AM
(crontab -l 2>/dev/null | grep -v n8n-backup; echo "0 2 * * * /usr/local/bin/n8n-backup.sh >> /var/log/n8n-backup.log 2>&1") | crontab -

print_success "Backup script created and scheduled"

################################################################################
# STEP 14: Final Checks and Summary
################################################################################

echo ""
echo "================================================"
echo "   Installation Complete!"
echo "================================================"
echo ""

# Check container status
if docker ps | grep -q n8n; then
    print_success "n8n container is running"
else
    print_error "n8n container is not running - check logs with: docker compose logs"
fi

# Check Nginx status
if systemctl is-active --quiet nginx; then
    print_success "Nginx is running"
else
    print_error "Nginx is not running"
fi

# Display access information
echo ""
echo "Access Information:"
echo "-------------------"
if [[ "$SSL_SUCCESS" = true ]]; then
    echo "  URL: https://${DOMAIN_NAME}"
else
    echo "  URL: http://${DOMAIN_NAME}"
fi
echo "  Username: ${N8N_USERNAME}"
echo "  Password: ${N8N_PASSWORD}"
echo ""

# Display useful commands
echo "Useful Commands:"
echo "-------------------"
echo "  View logs:           cd $N8N_DIR && docker compose logs -f"
echo "  Restart n8n:         cd $N8N_DIR && docker compose restart"
echo "  Stop n8n:            cd $N8N_DIR && docker compose down"
echo "  Start n8n:           cd $N8N_DIR && docker compose up -d"
echo "  Update n8n:          cd $N8N_DIR && docker compose pull && docker compose up -d"
echo "  Backup n8n:          /usr/local/bin/n8n-backup.sh"
echo "  Check Nginx:         sudo nginx -t"
echo "  Reload Nginx:        sudo systemctl reload nginx"
echo "  Renew SSL:           sudo certbot renew"
echo ""

# SSL certificate information
if [[ "$SSL_SUCCESS" = true ]]; then
    print_info "SSL certificate will auto-renew via cron job"
    echo "  Check certificates:  sudo certbot certificates"
else
    print_error "SSL certificate installation failed"
    echo ""
    echo "To retry SSL certificate installation manually:"
    echo "  1. Ensure DNS is properly configured"
    echo "  2. Run: sudo certbot --nginx -d ${DOMAIN_NAME}"
    echo ""
fi

# Warning about changing from HTTP to HTTPS
if [[ "$SSL_SUCCESS" = false ]]; then
    echo "⚠️  IMPORTANT: When you add SSL later, update the docker-compose.yml:"
    echo "   - Change N8N_PROTOCOL=http to N8N_PROTOCOL=https"
    echo "   - Change WEBHOOK_URL to use https://"
    echo "   - Remove N8N_SECURE_COOKIE=false line"
    echo "   - Change port binding from 5678:5678 to 127.0.0.1:5678:5678"
    echo "   - Then restart: docker compose down && docker compose up -d"
    echo ""
fi

print_success "Installation script completed!"
echo ""
