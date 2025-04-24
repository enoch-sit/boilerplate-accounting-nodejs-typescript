# Docker Configuration Guide

This guide explains how Docker is used in the Simple Accounting authentication system, covering both development and production environments.

## Introduction to Docker

Docker is a platform that allows you to develop, ship, and run applications inside containers. Containers package an application with all its dependencies, ensuring it works consistently across different environments.

## Docker Components in This Project

The Simple Accounting system uses several Docker-related files:

1. **Dockerfile** - Configuration for building the production Docker image
2. **Dockerfile.dev** - Configuration for building the development Docker image
3. **docker-compose.dev.yml** - Configures multi-container development environment
4. **docker-compose.prod.yml** - Configures multi-container production environment
5. **rebuild_docker.sh** / **rebuild_docker.ps1** - Scripts to rebuild containers

## Development Environment

The development Docker setup provides a consistent environment with hot-reloading capabilities, making it easier to develop without worrying about dependency conflicts.

### Key Components

The `docker-compose.dev.yml` file defines several services:

1. **API Service**: Your Node.js application
2. **MongoDB**: Database for storing user information
3. **Mailhog**: SMTP testing service for email verification

### Running in Development Mode

To start the development environment:

```bash
# On Linux/macOS
docker-compose -f docker-compose.dev.yml up

# On Windows PowerShell
docker-compose -f docker-compose.dev.yml up
```

This command starts all services defined in the development compose file. Your application will be accessible at http://localhost:3000.

### Development Dockerfile Explained

The `Dockerfile.dev` contains instructions for creating a development container:

```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application
COPY . .

# Development mode with hot reloading
CMD ["npm", "run", "dev"]
```

Key aspects:
- Uses Node.js 18 Alpine (lightweight Linux distro)
- Sets up the working directory
- Installs dependencies
- Runs in development mode with hot reloading

## Production Environment

The production Docker setup is optimized for performance, security, and reliability.

### Key Components

The `docker-compose.prod.yml` file typically includes:

1. **API Service**: Your Node.js application (optimized build)
2. **MongoDB**: Database with persistence
3. **Nginx**: Web server for routing and SSL termination (if applicable)

### Running in Production Mode

To start the production environment:

```bash
# On Linux/macOS
docker-compose -f docker-compose.prod.yml up -d

# On Windows PowerShell
docker-compose -f docker-compose.prod.yml up -d
```

The `-d` flag runs containers in detached mode (background).

### Production Dockerfile Explained

The `Dockerfile` for production uses a multi-stage build process:

```dockerfile
# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

# Production stage
FROM node:18-alpine

WORKDIR /app

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY package*.json ./

# Run in production mode
CMD ["npm", "run", "start:prod"]
```

Key aspects:
- Multi-stage build for smaller final image
- Only includes production dependencies
- Compiles TypeScript code for better performance
- Runs optimized production code

## Environment Variables

Docker containers use environment variables for configuration. In this project:

- Development variables are set in `docker-compose.dev.yml`
- Production variables are set in `docker-compose.prod.yml`
- Sensitive variables should be stored in Docker secrets or environment-specific `.env` files

Important environment variables include:
- `MONGO_URI` - MongoDB connection string
- `PORT` - Application port
- `JWT_SECRET` - Secret for JWT tokens
- `CORS_ORIGIN` - Allowed origins for CORS

## Data Persistence

In Docker environments, data can be lost when containers are removed. To prevent this:

1. **Volumes**: Map container directories to host directories
2. **Named Volumes**: Create persistent data storage

For example, in `docker-compose.prod.yml`:

```yaml
services:
  mongodb:
    image: mongo:latest
    volumes:
      - mongodb_data:/data/db

volumes:
  mongodb_data:
```

This configuration ensures MongoDB data persists even if the container is recreated.

## Rebuilding Containers

When you make significant changes to dependencies or Docker configuration, you may need to rebuild containers using the provided scripts:

```bash
# On Linux/macOS
./rebuild_docker.sh

# On Windows
.\rebuild_docker.ps1
```

These scripts typically stop running containers, rebuild images, and restart services.

## Common Docker Commands

- **View running containers**: `docker ps`
- **View container logs**: `docker logs [container_id]`
- **Enter a container shell**: `docker exec -it [container_id] sh`
- **Stop all containers**: `docker-compose -f [compose_file] down`
- **Rebuild a specific service**: `docker-compose -f [compose_file] up -d --build [service_name]`

## Troubleshooting

### Issue: Container fails to start
**Solution**: Check logs with `docker logs [container_id]` to identify errors

### Issue: Database connection errors
**Solution**: Verify MongoDB container is running and network settings are correct

### Issue: Changes not reflected in container
**Solution**: For code changes, the hot reload should work; for dependency changes, rebuild the container

### Issue: Performance issues
**Solution**: Check resource allocation in Docker Desktop settings (CPU, RAM)

## Best Practices

1. **Use specific image tags** instead of `latest` for reproducible builds
2. **Keep images small** by using Alpine-based images and multi-stage builds
3. **Never store secrets in Dockerfiles** or repository; use environment variables or secrets management
4. **Use health checks** to ensure services are truly ready
5. **Implement proper logging** for debugging containerized applications

## Resources for Learning More

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Node.js Docker Best Practices](https://nodejs.org/en/docs/guides/nodejs-docker-webapp/)