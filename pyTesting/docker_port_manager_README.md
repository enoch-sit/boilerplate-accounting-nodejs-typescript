# Docker Port Conflict Manager

This Python script automates Docker environment management by:
1. Checking for port conflicts before running Docker
2. Automatically resolving port conflicts when possible
3. Rebuilding Docker containers with a clean cache
4. Clearing Docker cache to free up disk space

## Requirements

- Python 3.6+
- Docker and Docker Compose
- Required Python packages:
  - colorama
  - pyyaml

Install dependencies with:
```
pip install colorama pyyaml
```

## Usage

Basic usage to check for port conflicts:
```
python docker_port_manager.py
```

To check for conflicts and rebuild Docker containers:
```
python docker_port_manager.py --rebuild
```

To check for conflicts, clear Docker cache, and rebuild containers:
```
python docker_port_manager.py --rebuild --clear-cache
```

To only check for port conflicts without resolving them:
```
python docker_port_manager.py --check-only
```

To use a specific Docker Compose file:
```
python docker_port_manager.py --rebuild --compose-file docker-compose.mailhog-test.yml
```

## What It Does

1. **Port Conflict Detection**:
   - Checks if critical ports (MongoDB, MailHog SMTP/HTTP, Auth Service) are already in use
   - Provides clear visual feedback about which ports are available or in conflict

2. **Automatic Conflict Resolution**:
   - Identifies processes using the conflicting ports
   - Attempts to automatically terminate those processes to free up the ports

3. **Docker Management**:
   - Stops running Docker containers when needed
   - Rebuilds containers with the `--no-cache` option for clean builds
   - Clears Docker system and volume caches to free up disk space

4. **Logging**:
   - Creates detailed logs in the `logs` directory
   - Timestamps all actions for easier debugging

## Default Monitored Ports

| Service | Port | Notes |
|---------|------|-------|
| MongoDB | 27018 | Mapped to container port 27017 |
| MailHog SMTP | 1025 | For email sending |
| MailHog Web UI | 8025 | Web interface and API |
| Auth Service | 3000 | Main application |

## Tips

- Run this script before starting your development environment to ensure a clean start
- Use the `--rebuild` option after making changes to Dockerfiles or dependencies
- Use the `--clear-cache` option periodically to free up disk space
- Use the script in CI/CD pipelines to ensure clean test environments