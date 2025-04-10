#!/usr/bin/env python3
"""
Docker Port Conflict Manager

This script checks for port conflicts, rebuilds Docker containers, and clears Docker cache.
It helps ensure that your Docker environment starts cleanly without port conflicts.

Usage:
    python docker_port_manager.py [--rebuild] [--clear-cache] [--check-only]

Author: Auth System Team
Date: April 10, 2025
"""

import argparse
import logging
import os
import socket
import subprocess
import sys
import time
import yaml
from pathlib import Path
from datetime import datetime
from colorama import Fore, Style, init

# Initialize colorama
init(autoreset=True)

# Configure logging
log_dir = Path("./logs")
log_dir.mkdir(exist_ok=True)
log_file = log_dir / f"docker_port_manager_{datetime.now().strftime('%Y-%m-%d_%H-%M-%S')}.log"

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S',
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

# Define important Docker ports for our services
CRITICAL_PORTS = {
    "MongoDB": 27018,  # Host port mapped to container port 27017
    "MailHog SMTP": 1025,
    "MailHog Web UI": 8025,
    "Auth Service": 3000
}

def is_port_in_use(port, host='localhost'):
    """Check if a port is in use."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex((host, port)) == 0

def check_port_conflicts():
    """Check for port conflicts and return list of conflicting ports."""
    conflicts = []
    
    logger.info(f"{Fore.CYAN}Checking for port conflicts...{Style.RESET_ALL}")
    print(f"{Fore.CYAN}Checking for port conflicts...{Style.RESET_ALL}")
    
    for service, port in CRITICAL_PORTS.items():
        if is_port_in_use(port):
            logger.warning(f"Port conflict detected: {service} port {port} is already in use")
            conflicts.append((service, port))
            print(f"{Fore.RED}✘ Conflict: {service} port {port} is already in use{Style.RESET_ALL}")
        else:
            print(f"{Fore.GREEN}✓ Available: {service} port {port} is free{Style.RESET_ALL}")
    
    return conflicts

def parse_docker_compose_ports(filepath):
    """Parse Docker Compose file to extract all port mappings."""
    try:
        with open(filepath, 'r') as file:
            compose_data = yaml.safe_load(file)
            
        if not compose_data or 'services' not in compose_data:
            logger.warning(f"No services found in {filepath}")
            return []
            
        port_mappings = []
        for service_name, service_config in compose_data['services'].items():
            if 'ports' in service_config:
                for port_mapping in service_config['ports']:
                    # Parse port mapping string like "1025:1025" or "27018:27017"
                    parts = port_mapping.split(':')
                    if len(parts) == 2:
                        host_port = int(parts[0])
                        container_port = int(parts[1])
                        port_mappings.append({
                            'service': service_name,
                            'host_port': host_port,
                            'container_port': container_port
                        })
        
        return port_mappings
                    
    except Exception as e:
        logger.error(f"Error parsing Docker Compose file {filepath}: {e}")
        return []

def check_all_docker_compose_ports(root_dir="."):
    """Check all Docker Compose files for port conflicts."""
    root_path = Path(root_dir)
    compose_files = list(root_path.glob("docker-compose*.yml"))
    
    all_ports = []
    for compose_file in compose_files:
        logger.info(f"Checking ports in {compose_file}")
        ports = parse_docker_compose_ports(compose_file)
        all_ports.extend(ports)
        
    conflicts = []
    for port_mapping in all_ports:
        host_port = port_mapping['host_port']
        if is_port_in_use(host_port):
            conflicts.append((
                f"{port_mapping['service']} (from {compose_file.name})", 
                host_port
            ))
            
    return conflicts, all_ports

def run_command(command, description=None):
    """Run a shell command and log the output."""
    if description:
        logger.info(f"{description}")
        print(f"{Fore.CYAN}{description}{Style.RESET_ALL}")
        
    try:
        logger.debug(f"Running command: {command}")
        process = subprocess.Popen(
            command,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        # Process output in real-time
        while True:
            stdout_line = process.stdout.readline()
            stderr_line = process.stderr.readline()
            
            if not stdout_line and not stderr_line and process.poll() is not None:
                break
                
            if stdout_line:
                logger.info(stdout_line.strip())
                print(stdout_line.strip())
                
            if stderr_line:
                logger.error(stderr_line.strip())
                print(f"{Fore.RED}{stderr_line.strip()}{Style.RESET_ALL}")
                
        returncode = process.wait()
        
        if returncode != 0:
            logger.error(f"Command failed with exit code {returncode}")
            return False
            
        return True
        
    except Exception as e:
        logger.error(f"Error executing command: {e}")
        return False

def stop_docker_containers():
    """Stop running Docker containers."""
    return run_command("docker-compose down", "Stopping Docker containers...")

def rebuild_docker_containers(compose_file="docker-compose.dev.yml"):
    """Rebuild Docker containers."""
    # First build with no-cache option
    success = run_command(
        f"docker-compose -f {compose_file} build --no-cache",
        "Rebuilding Docker containers (no cache)..."
    )
    
    if not success:
        logger.error("Failed to rebuild Docker containers")
        return False
        
    # Then up with detached mode
    success = run_command(
        f"docker-compose -f {compose_file} up -d",
        "Starting Docker containers..."
    )
    
    if not success:
        logger.error("Failed to start Docker containers")
        return False
        
    logger.info("Docker containers rebuilt and started successfully")
    return True

def clear_docker_cache():
    """Clear Docker cache."""
    commands = [
        "docker system prune -f",  # Remove all stopped containers, networks, dangling images
        "docker volume prune -f",   # Remove all unused volumes
    ]
    
    logger.info("Clearing Docker cache...")
    print(f"{Fore.CYAN}Clearing Docker cache...{Style.RESET_ALL}")
    
    for cmd in commands:
        success = run_command(cmd)
        if not success:
            logger.warning(f"Command '{cmd}' failed")
    
    return True

def find_and_kill_process_on_port(port):
    """Find and kill the process using a specific port."""
    try:
        if os.name == 'nt':  # Windows
            # Find PID using netstat
            cmd = f"netstat -ano | findstr :{port}"
            result = subprocess.check_output(cmd, shell=True).decode()
            lines = result.strip().split('\n')
            
            if not lines:
                logger.warning(f"No process found using port {port}")
                return False
                
            # Extract PID from the last column
            for line in lines:
                parts = [p for p in line.split() if p]
                if len(parts) >= 5:
                    pid = parts[4]
                    # Kill the process
                    kill_cmd = f"taskkill /F /PID {pid}"
                    logger.info(f"Killing process {pid} on port {port}")
                    print(f"{Fore.YELLOW}Killing process {pid} on port {port}{Style.RESET_ALL}")
                    subprocess.call(kill_cmd, shell=True)
                    return True
            
            return False
                
        else:  # Unix/Linux/Mac
            # Find PID using lsof
            cmd = f"lsof -i :{port} | grep LISTEN"
            result = subprocess.check_output(cmd, shell=True).decode()
            lines = result.strip().split('\n')
            
            if not lines:
                logger.warning(f"No process found using port {port}")
                return False
                
            # Extract PID from the second column
            for line in lines:
                parts = line.split()
                if len(parts) >= 2:
                    pid = parts[1]
                    # Kill the process
                    kill_cmd = f"kill -9 {pid}"
                    logger.info(f"Killing process {pid} on port {port}")
                    print(f"{Fore.YELLOW}Killing process {pid} on port {port}{Style.RESET_ALL}")
                    subprocess.call(kill_cmd, shell=True)
                    return True
                    
            return False
            
    except subprocess.CalledProcessError:
        logger.warning(f"No process found using port {port}")
        return False
    except Exception as e:
        logger.error(f"Error while trying to kill process on port {port}: {e}")
        return False

def resolve_port_conflicts(conflicts):
    """Attempt to resolve port conflicts by killing processes."""
    if not conflicts:
        return True
        
    logger.info("Attempting to resolve port conflicts...")
    print(f"{Fore.YELLOW}Attempting to resolve port conflicts...{Style.RESET_ALL}")
    
    for service, port in conflicts:
        logger.info(f"Resolving conflict for {service} on port {port}")
        find_and_kill_process_on_port(port)
        
    # Check if conflicts are resolved
    remaining_conflicts = []
    for service, port in conflicts:
        if is_port_in_use(port):
            logger.warning(f"Conflict for {service} on port {port} could not be resolved")
            remaining_conflicts.append((service, port))
        else:
            logger.info(f"Conflict for {service} on port {port} was resolved")
            print(f"{Fore.GREEN}Resolved: {service} port {port} is now free{Style.RESET_ALL}")
            
    return len(remaining_conflicts) == 0

def main():
    parser = argparse.ArgumentParser(description='Docker Port Conflict Manager')
    parser.add_argument('--rebuild', action='store_true', help='Rebuild Docker containers')
    parser.add_argument('--clear-cache', action='store_true', help='Clear Docker cache')
    parser.add_argument('--check-only', action='store_true', help='Only check for port conflicts without resolving')
    parser.add_argument('--compose-file', type=str, default='docker-compose.dev.yml', 
                       help='Docker compose file to use (default: docker-compose.dev.yml)')
    
    args = parser.parse_args()
    
    logger.info("Docker Port Conflict Manager started")
    print(f"{Fore.CYAN}Docker Port Conflict Manager{Style.RESET_ALL}")
    print(f"{Fore.CYAN}=============================={Style.RESET_ALL}")
    
    # Check for port conflicts
    conflicts = check_port_conflicts()
    
    if not conflicts:
        print(f"{Fore.GREEN}No port conflicts detected.{Style.RESET_ALL}")
        logger.info("No port conflicts detected")
    else:
        print(f"{Fore.RED}Port conflicts detected:{Style.RESET_ALL}")
        for service, port in conflicts:
            print(f"{Fore.RED}  - {service} port {port} is in use{Style.RESET_ALL}")
            
        if args.check_only:
            logger.info("Check-only mode - not attempting to resolve conflicts")
            return 1
            
        # Try to resolve conflicts
        resolved = resolve_port_conflicts(conflicts)
        if not resolved:
            logger.error("Failed to resolve all port conflicts")
            print(f"{Fore.RED}Failed to resolve all port conflicts. Please stop the conflicting services manually.{Style.RESET_ALL}")
            return 1
    
    # Handle Docker operations
    if args.rebuild or args.clear_cache:
        # Stop containers first
        stop_docker_containers()
        
        if args.clear_cache:
            clear_docker_cache()
            
        if args.rebuild:
            rebuild_docker_containers(args.compose_file)
    
    logger.info("Docker Port Conflict Manager completed successfully")
    print(f"{Fore.GREEN}Docker environment ready!{Style.RESET_ALL}")
    return 0

if __name__ == "__main__":
    sys.exit(main())