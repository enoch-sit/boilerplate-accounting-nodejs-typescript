# JWT Environment Variables Guide for Samehost Configuration

This guide explains how to properly configure JWT-related environment variables for the samehost Docker Compose setup.

## Table of Contents
1. [Overview](#overview)
2. [Current Environment Variable Setup](#current-environment-variable-setup)
3. [Changing JWT Secrets](#changing-jwt-secrets)
4. [Security Best Practices](#security-best-practices)
5. [Troubleshooting](#troubleshooting)
6. [Testing Your Configuration](#testing-your-configuration)

## Overview

The `docker-compose.samehost.yml` configuration uses environment variables for JWT secrets instead of hardcoded values. This provides better security and flexibility for different deployment scenarios.

### Environment Files Used

- **`.env.samehost`**: Contains ALL environment variables for the samehost configuration ✅
- **Application Code**: Now directly loads `.env.samehost` when `NODE_ENV=samehost` ✅
- **Docker Compose**: Also loads `.env.samehost` and passes variables to container ✅

## Current Environment Variable Setup

### How Environment Variables Are Loaded

The application now supports loading `.env.samehost` directly. Here's the updated flow:

1. **Application Code** (`src/app.ts`) checks `NODE_ENV` and loads the appropriate .env file:
   - `NODE_ENV=production` → loads `.env.production`
   - `NODE_ENV=samehost` → loads `.env.samehost` ✅
   - `NODE_ENV=development` → loads `.env.development`

2. **Docker Compose** also loads `.env.samehost` and passes variables to the container

3. **Container Environment** receives variables from both sources (Docker Compose takes precedence)

### In docker-compose.samehost.yml
```yaml
environment:
  - NODE_ENV=samehost
  - JWT_ACCESS_SECRET=${JWT_ACCESS_SECRET}
  - JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET}
  # ... other variables from .env.samehost
```

### In .env.samehost
```bash
JWT_ACCESS_SECRET=samehost_secure_access_secret_key_change_this_before_production
JWT_REFRESH_SECRET=samehost_secure_refresh_secret_key_change_this_before_production
```

## Changing JWT Secrets

### Step 1: Generate Secure Secrets

**Option A: Using OpenSSL (Recommended)**
```bash
# Generate a 32-byte base64 encoded secret for access tokens
openssl rand -base64 32

# Generate a 32-byte base64 encoded secret for refresh tokens
openssl rand -base64 32
```

**Option B: Using Node.js**
```bash
# Access token secret
node -e "console.log('JWT_ACCESS_SECRET=' + require('crypto').randomBytes(32).toString('base64'))"

# Refresh token secret
node -e "console.log('JWT_REFRESH_SECRET=' + require('crypto').randomBytes(32).toString('base64'))"
```

**Option C: Using Python**
```bash
# Access token secret
python -c "import secrets; print('JWT_ACCESS_SECRET=' + secrets.token_urlsafe(32))"

# Refresh token secret
python -c "import secrets; print('JWT_REFRESH_SECRET=' + secrets.token_urlsafe(32))"
```

### Step 2: Update .env.samehost File

1. Open `.env.samehost` in your text editor
2. Replace the default values with your generated secrets:

```bash
# Example with generated secrets (DO NOT USE THESE EXACT VALUES)
JWT_ACCESS_SECRET=your_generated_access_secret_here
JWT_REFRESH_SECRET=your_generated_refresh_secret_here
```

### Step 3: Restart the Services

```bash
# Use the rebuild script
./rebuild_docker_samehost.sh

# Or manually restart
docker-compose -f docker-compose.samehost.yml --env-file .env.samehost down
docker-compose -f docker-compose.samehost.yml --env-file .env.samehost up -d
```

## Security Best Practices

### JWT Secret Requirements
- **Length**: At least 32 characters (256 bits)
- **Complexity**: Use random, unpredictable strings
- **Uniqueness**: Different secrets for access and refresh tokens
- **Environment Specific**: Different secrets for different environments

### Example of Strong Secrets
```bash
# Good examples (but don't use these exact ones)
JWT_ACCESS_SECRET=K8mF2kP9nQ7sR4tV6wX8yZ1aC3eG5jL7mN0pQ2sT4vW6yZ9bC1dF3gH5jK7mN9pQ
JWT_REFRESH_SECRET=R2sT4vW6yZ9bC1dF3gH5jK7mN0pQ2sT4vW6yZ9bC1dF3gH5jK7mN0pQ2sT4vW6y
```

### Security Checklist
- ✅ Use unique secrets for each environment
- ✅ Never commit secrets to version control
- ✅ Store secrets securely (environment variables, secret management)
- ✅ Rotate secrets periodically
- ✅ Use different secrets for access and refresh tokens
- ✅ Ensure secrets are at least 32 characters long

## Troubleshooting

### Problem: "Invalid token" errors
**Possible Causes:**
- JWT secrets have changed but existing tokens were signed with old secrets
- Mismatch between secrets in .env.samehost and running container

**Solution:**
1. Check that .env.samehost contains the correct secrets
2. Restart the containers to apply new environment variables
3. Clear any existing tokens/cookies in your client application

### Problem: Container fails to start
**Possible Causes:**
- Missing .env.samehost file
- Invalid characters in environment variables

**Solution:**
1. Ensure .env.samehost exists in the project root
2. Check for special characters that might need escaping
3. Use `docker-compose logs auth-service` to check error messages

### Problem: Environment variables not loaded
**Possible Causes:**
- Not using the `--env-file` flag with docker-compose
- .env.samehost file in wrong location

**Solution:**
1. Always use: `docker-compose -f docker-compose.samehost.yml --env-file .env.samehost up`
2. Ensure .env.samehost is in the same directory as docker-compose.samehost.yml

## Testing Your Configuration

### Verify Environment Variables are Loaded
```bash
# Check environment variables in running container
docker exec auth-service-dev printenv | grep JWT

# Expected output:
# JWT_ACCESS_SECRET=your_access_secret
# JWT_REFRESH_SECRET=your_refresh_secret
```

### Test Token Generation
1. Start the services with your new configuration
2. Register a new user or login
3. Verify you receive valid tokens
4. Test protected endpoints to ensure tokens work

### Validate Configuration
Use the JWT verification tool:
```bash
# Check environment secrets
python tests/JWT_verification.py check-env --env dev

# Extract from running container
python tests/JWT_verification.py extract --docker-container auth-service-dev
```

## Common Commands

### Start with new environment
```bash
docker-compose -f docker-compose.samehost.yml --env-file .env.samehost up -d
```

### Restart services
```bash
docker-compose -f docker-compose.samehost.yml --env-file .env.samehost restart
```

### View logs
```bash
docker-compose -f docker-compose.samehost.yml logs -f auth-service
```

### Stop services
```bash
docker-compose -f docker-compose.samehost.yml down
```

## Example Workflow for Production Setup

1. **Generate Production Secrets**
   ```bash
   echo "JWT_ACCESS_SECRET=$(openssl rand -base64 32)" > .env.samehost.prod
   echo "JWT_REFRESH_SECRET=$(openssl rand -base64 32)" >> .env.samehost.prod
   ```

2. **Review and Backup Secrets**
   ```bash
   cat .env.samehost.prod
   # Store these secrets securely (password manager, vault, etc.)
   ```

3. **Deploy with Production Secrets**
   ```bash
   cp .env.samehost.prod .env.samehost
   ./rebuild_docker_samehost.sh
   ```

4. **Verify Deployment**
   ```bash
   docker-compose -f docker-compose.samehost.yml ps
   curl http://localhost:3000/health
   ```

## Notes

- The samehost configuration is designed for environments where multiple Docker Compose applications need to communicate on the same network
- JWT secrets are the most critical security component - protect them accordingly
- Consider using a proper secret management solution for production deployments
- Regular secret rotation is recommended for high-security environments

---

**Important**: Always test your configuration in a development environment before deploying to production!
