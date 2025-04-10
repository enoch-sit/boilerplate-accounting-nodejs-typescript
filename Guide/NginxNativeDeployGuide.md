# Deployment Guide: TypeScript Authentication System

This guide provides detailed step-by-step instructions for deploying the TypeScript Authentication System on a Linux server with Nginx as a reverse proxy.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Server Preparation](#server-preparation)
3. [Application Deployment](#application-deployment)
4. [Database Setup](#database-setup)
5. [Environment Configuration](#environment-configuration)
6. [Email Server Configuration](#email-server-configuration)
7. [Process Management with PM2](#process-management-with-pm2)
8. [Nginx Configuration](#nginx-configuration)
9. [SSL Certificate Setup](#ssl-certificate-setup)
10. [Firewall Configuration](#firewall-configuration)
11. [Testing the Deployment](#testing-the-deployment)
12. [Troubleshooting](#troubleshooting)
13. [Maintenance and Updates](#maintenance-and-updates)

## Prerequisites

Before starting the deployment process, ensure you have:

- A Linux server (Ubuntu 20.04 LTS or later recommended)
- Root or sudo access to the server
- Domain name (ai.example.ai) with DNS pointing to your server
- Basic knowledge of Linux command line
- SSH access to your server

## Server Preparation

### 1. Update Your System

Begin by updating your system packages:

```bash
sudo apt update
sudo apt upgrade -y
```

### 2. Install Required Dependencies

Install the necessary dependencies:

```bash
# Install Node.js and npm
sudo apt install -y curl
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Verify installation
node -v  # Should show v18.x.x
npm -v   # Should show 8.x.x or later

# Install build tools (needed for some npm packages)
sudo apt install -y build-essential

# Install MongoDB
sudo apt install -y gnupg
wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
sudo apt update
sudo apt install -y mongodb-org

# Start MongoDB and enable it to start on boot
sudo systemctl start mongod
sudo systemctl enable mongod

# Verify MongoDB is running
sudo systemctl status mongod

# Install Nginx
sudo apt install -y nginx

# Start Nginx and enable it to start on boot
sudo systemctl start nginx
sudo systemctl enable nginx

# Install Certbot for SSL
sudo apt install -y certbot python3-certbot-nginx
```

### 3. Create a Non-root User for Application Deployment

Create a dedicated user for running the application:

```bash
# Create a new user
sudo adduser appuser

# Add the user to the sudo group (optional)
sudo usermod -aG sudo appuser

# Switch to the new user
su - appuser
```

## Application Deployment

### 1. Clone the Repository

Clone your application code to the server:

```bash
# Create application directory
mkdir -p ~/apps
cd ~/apps

# Clone the repository
git clone https://github.com/yourusername/typescript_auth_simple.git
cd typescript_auth_simple
```

### 2. Install Application Dependencies

Install the required npm packages:

```bash
npm install
```

### 3. Build the Application

Compile the TypeScript code:

```bash
npm run build
```

## Database Setup

### 1. Create a MongoDB Database

Create a dedicated database and user for your application:

```bash
# Connect to MongoDB shell
mongosh

# Create database and switch to it
use auth_db

# Create database user with password
db.createUser({
  user: "authuser",
  pwd: "your_secure_password",
  roles: [{ role: "readWrite", db: "auth_db" }]
})

# Exit MongoDB shell
exit
```

### 2. Enable MongoDB Authentication

Edit the MongoDB configuration file to enable authentication:

```bash
sudo nano /etc/mongod.conf
```

Add or modify the security section:

```yaml
security:
  authorization: enabled
```

Restart MongoDB to apply changes:

```bash
sudo systemctl restart mongod
```

### 3. Import Initial Data (Optional)

If you have initial data to import:

```bash
# Import collections (if you have existing data)
mongorestore --db auth_db --username authuser --password your_secure_password /path/to/dump/auth_db
```

## Environment Configuration

### 1. Create Production Environment File

Create a production environment file:

```bash
cd ~/apps/typescript_auth_simple
nano .env.production
```

Add the following configuration, adjusting values as needed:

```dotenv
PORT=3000
NODE_ENV=production
MONGO_URI=mongodb://authuser:your_secure_password@localhost:27017/auth_db
JWT_ACCESS_SECRET=your_very_secure_jwt_access_secret
JWT_REFRESH_SECRET=your_very_secure_jwt_refresh_secret
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d
EMAIL_SERVICE=smtp
EMAIL_HOST=smtp.your-email-provider.com
EMAIL_PORT=587
EMAIL_USER=your-email@example.com
EMAIL_PASS=your_email_password
EMAIL_FROM=noreply@ai.example.ai
PASSWORD_RESET_EXPIRES_IN=1h
VERIFICATION_CODE_EXPIRES_IN=15m
FRONTEND_URL=https://ai.example.ai
CORS_ORIGIN=https://ai.example.ai
LOG_LEVEL=error
```

Make sure to generate strong random secrets for JWT tokens:

```bash
# Generate secure random strings for JWT tokens
openssl rand -base64 32  # Use output for JWT_ACCESS_SECRET
openssl rand -base64 32  # Use output for JWT_REFRESH_SECRET
```

## Email Server Configuration

### 1. Using an External SMTP Service (Recommended)

Update your `.env.production` with the SMTP settings from your provider (Gmail, SendGrid, AWS SES, etc.).

### 2. Setting Up a Local Mail Server (Optional)

If you prefer a local mail server, you can install Postfix:

```bash
sudo apt install -y postfix
```

When prompted, select "Internet Site" and enter your domain name.

Configure Postfix for SMTP:

```bash
sudo nano /etc/postfix/main.cf
```

Update settings as needed, then restart Postfix:

```bash
sudo systemctl restart postfix
```

## Process Management with PM2

### 1. Install PM2 Globally

```bash
sudo npm install -g pm2
```

### 2. Create PM2 Configuration File

Create a PM2 ecosystem file:

```bash
cd ~/apps/typescript_auth_simple
nano ecosystem.config.js
```

Add the following configuration:

```javascript
module.exports = {
  apps: [
    {
      name: "auth-service",
      script: "dist/app.js",
      instances: "max",
      exec_mode: "cluster",
      env_production: {
        NODE_ENV: "production",
        PORT: 3000
      },
      max_memory_restart: "300M",
      log_date_format: "YYYY-MM-DD HH:mm:ss",
      combine_logs: true
    }
  ]
};
```

### 3. Start the Application with PM2

```bash
# Start the application
pm2 start ecosystem.config.js --env production

# Save the PM2 configuration to start on reboot
pm2 save

# Set up PM2 to start on system boot
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u appuser --hp /home/appuser
```

## Nginx Configuration

### 1. Create Nginx Server Block Configuration

Create a new Nginx configuration file:

```bash
sudo nano /etc/nginx/sites-available/ai.example.ai
```

Add the following configuration:

```nginx
server {
    listen 80;
    server_name ai.example.ai www.ai.example.ai;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Additional security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
    add_header Content-Security-Policy "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; connect-src 'self';";

    # Logging configuration
    access_log /var/log/nginx/ai.example.ai.access.log;
    error_log /var/log/nginx/ai.example.ai.error.log;
}
```

### 2. Enable the Server Block

Create a symbolic link to enable the site:

```bash
sudo ln -s /etc/nginx/sites-available/ai.example.ai /etc/nginx/sites-enabled/
```

### 3. Test Nginx Configuration

Verify the configuration:

```bash
sudo nginx -t
```

### 4. Restart Nginx

Apply the new configuration:

```bash
sudo systemctl restart nginx
```

## SSL Certificate Setup

### 1. Obtain SSL Certificate with Certbot

```bash
sudo certbot --nginx -d ai.example.ai -d www.ai.example.ai
```

Follow the prompts to complete the process. Certbot will automatically update your Nginx configuration.

### 2. Test Auto-renewal

Ensure the auto-renewal process works:

```bash
sudo certbot renew --dry-run
```

## Firewall Configuration

### 1. Configure UFW (Uncomplicated Firewall)

```bash
# Allow SSH
sudo ufw allow 22/tcp

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable the firewall
sudo ufw enable

# Check status
sudo ufw status
```

## Testing the Deployment

### 1. Verify the API is Running

Test the API endpoints using curl:

```bash
# Health check endpoint
curl -i https://ai.example.ai/health

# Try an API endpoint
curl -i https://ai.example.ai/api/auth/signup -H "Content-Type: application/json" -d '{"username":"testuser","email":"test@example.com","password":"Test123!"}'
```

### 2. Monitor Logs

Check application logs for any errors:

```bash
# Check PM2 logs
pm2 logs

# Check Nginx access logs
sudo tail -f /var/log/nginx/ai.example.ai.access.log

# Check Nginx error logs
sudo tail -f /var/log/nginx/ai.example.ai.error.log
```

## Troubleshooting

### Common Issues and Solutions

1. **Application not starting**:
   - Check application logs: `pm2 logs`
   - Verify environment variables are set correctly
   - Ensure MongoDB is running: `sudo systemctl status mongod`

2. **MongoDB connection issues**:
   - Check MongoDB is running: `sudo systemctl status mongod`
   - Verify MongoDB connection string in `.env.production`
   - Check MongoDB authentication settings

3. **Nginx proxy issues**:
   - Check Nginx configuration: `sudo nginx -t`
   - Verify Nginx is running: `sudo systemctl status nginx`
   - Check Nginx error logs: `sudo tail -f /var/log/nginx/error.log`

4. **SSL certificate issues**:
   - Verify certificate files exist: `ls -l /etc/letsencrypt/live/ai.example.ai/`
   - Renew certificates if expired: `sudo certbot renew`

## Maintenance and Updates

### 1. Update Application Code

To deploy updates:

```bash
cd ~/apps/typescript_auth_simple
git pull
npm install
npm run build
pm2 restart auth-service
```

### 2. Database Backups

Set up automated MongoDB backups:

```bash
# Create backup script
nano ~/backup_mongodb.sh
```

Add the following content:

```bash
#!/bin/bash
BACKUP_DIR="/home/appuser/backups/mongodb"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="auth_db_backup_$TIMESTAMP"

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Create backup
mongodump --db auth_db --username authuser --password "your_secure_password" --out $BACKUP_DIR/$BACKUP_NAME

# Compress backup
cd $BACKUP_DIR
tar -zcvf $BACKUP_NAME.tar.gz $BACKUP_NAME
rm -rf $BACKUP_NAME

# Delete backups older than 14 days
find $BACKUP_DIR -name "*.tar.gz" -type f -mtime +14 -delete
```

Make the script executable:

```bash
chmod +x ~/backup_mongodb.sh
```

Set up a cron job to run the backup script daily:

```bash
crontab -e
```

Add the following line:

```
0 3 * * * /home/appuser/backup_mongodb.sh > /home/appuser/backups/mongodb/backup.log 2>&1
```

### 3. System Updates

Regularly update your system:

```bash
sudo apt update
sudo apt upgrade -y
```

### 4. Monitor System Health

Install basic monitoring tools:

```bash
sudo apt install -y htop iotop
```

For more comprehensive monitoring, consider setting up:
- Prometheus and Grafana for metrics
- Graylog or ELK Stack for log aggregation

---

## Security Best Practices

1. **Keep software up to date**:
   - Regularly update Node.js, MongoDB, and Nginx
   - Apply security patches promptly

2. **Secure MongoDB**:
   - Use strong passwords
   - Bind MongoDB to localhost only
   - Enable authentication

3. **Implement rate limiting**:
   - Configure rate limiting in Nginx:

```nginx
http {
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
    
    server {
        location /api/ {
            limit_req zone=api_limit burst=20 nodelay;
            # other settings...
        }
    }
}
```

4. **Set up monitoring and alerts**:
   - Monitor server resources (CPU, memory, disk)
   - Set up alerts for unusual activity

5. **Regular backups**:
   - Automate database backups
   - Store backups securely off-server

By following this deployment guide, you will have a secure, production-ready authentication system running on your Linux server with Nginx as a reverse proxy, accessible at https://ai.example.ai.