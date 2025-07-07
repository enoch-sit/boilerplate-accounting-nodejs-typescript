#!/bin/bash

# Setup script for Linux Docker environment
# This script helps configure Docker permissions and environment

echo "🔧 Setting up Docker environment for Linux..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed!"
    echo "📋 Please install Docker first:"
    echo "   https://docs.docker.com/engine/install/ubuntu/"
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose is not available!"
    echo "📋 Please install Docker Compose:"
    echo "   sudo apt-get update"
    echo "   sudo apt-get install docker-compose-plugin"
    exit 1
fi

echo "✅ Docker and Docker Compose are installed"

# Check Docker permissions
if ! docker info >/dev/null 2>&1; then
    echo ""
    echo "🔐 Setting up Docker permissions..."
    echo "📋 Adding user to docker group..."
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    echo "✅ User added to docker group"
    echo ""
    echo "⚠️ IMPORTANT: You need to log out and log back in for the changes to take effect."
    echo "   Or run: newgrp docker"
    echo ""
    echo "After fixing permissions, run: ./rebuild_docker_samehost_linux.sh"
    
    # Try to apply group membership without logout
    echo "🔄 Attempting to apply group membership..."
    if newgrp docker << 'EOF'
        echo "✅ Docker permissions applied successfully"
        docker info >/dev/null 2>&1 && echo "✅ Docker access confirmed"
EOF
    then
        echo "✅ Docker permissions are now working"
    else
        echo "⚠️ Please log out and log back in, then run the rebuild script"
        exit 1
    fi
else
    echo "✅ Docker permissions are already configured"
fi

# Check if .env.samehost exists
if [ ! -f ".env.samehost" ]; then
    echo ""
    echo "📋 Creating .env.samehost file..."
    
    # Create default .env.samehost file
    cat > .env.samehost << 'EOF'
# Environment Configuration for Samehost Development
NODE_ENV=samehost

# JWT Configuration
JWT_ACCESS_SECRET=your-super-secret-jwt-access-key-change-this-in-production
JWT_REFRESH_SECRET=your-super-secret-jwt-refresh-key-change-this-in-production
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d

# Database Configuration
MONGODB_URI=mongodb://mongodb:27017/auth_db

# Email Configuration
EMAIL_HOST=mailhog
EMAIL_PORT=1025
EMAIL_USER=
EMAIL_PASS=
EMAIL_FROM=noreply@example.com

# Application Configuration
HOST_URL=http://localhost:3000
CORS_ORIGIN=http://localhost:3000
PORT=3000
LOG_LEVEL=debug

# Security Configuration
PASSWORD_RESET_EXPIRES_IN=1h
VERIFICATION_CODE_EXPIRES_IN=24h
EOF
    
    echo "✅ Created .env.samehost with default values"
    echo "🔐 Please update JWT secrets before production use!"
else
    echo "✅ .env.samehost file already exists"
fi

# Make scripts executable
echo ""
echo "🔧 Making scripts executable..."
chmod +x rebuild_docker_samehost_linux.sh
chmod +x check_network.sh
chmod +x quickCreateAdminPySamehost/*.sh 2>/dev/null || true

echo "✅ Scripts are now executable"

echo ""
echo "🎉 Setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Edit .env.samehost and update JWT secrets"
echo "2. Run: ./rebuild_docker_samehost_linux.sh"
echo "3. Test: ./check_network.sh"
echo "4. Create users: cd quickCreateAdminPySamehost && python3 create_users.py"
echo ""
echo "🔧 Troubleshooting:"
echo "- If Docker permissions fail, log out and log back in"
echo "- Check logs: docker compose -f docker-compose.samehost.yml logs"
echo "- Stop services: docker compose -f docker-compose.samehost.yml down"
