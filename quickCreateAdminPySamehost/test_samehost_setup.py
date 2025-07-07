#!/usr/bin/env python3
"""
Samehost Configuration Test Script
This script verifies that the samehost Docker setup is properly configured and working.
"""

import subprocess
import time
import sys
import os

# Configuration
REQUIRED_CONTAINERS = [
    "auth-service-dev",
    "auth-mongodb-samehost", 
    "auth-mailhog-samehost"
]

def run_command(command):
    """Run a shell command and return the output"""
    try:
        result = subprocess.run(
            command,
            shell=True,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Command failed: {command}")
        print(f"Error: {e.stderr}")
        return None

def check_docker_containers():
    """Check if all required Docker containers are running"""
    print("🔍 Checking Docker containers...")
    
    output = run_command("docker ps --format 'table {{.Names}}\t{{.Status}}'")
    if not output:
        print("❌ Failed to get Docker container status")
        return False
    
    print(f"Docker containers status:\n{output}")
    
    running_containers = []
    for line in output.split('\n')[1:]:  # Skip header
        if line.strip():
            container_name = line.split('\t')[0]
            running_containers.append(container_name)
    
    missing_containers = []
    for required_container in REQUIRED_CONTAINERS:
        if required_container not in running_containers:
            missing_containers.append(required_container)
    
    if missing_containers:
        print(f"❌ Missing containers: {', '.join(missing_containers)}")
        print("Please start the samehost environment with:")
        print("  ./rebuild_docker_samehost.sh (Linux/Mac)")
        print("  .\\rebuild_docker_samehost.bat (Windows)")
        return False
    
    print("✅ All required containers are running!")
    return True

def check_mongodb_connection():
    """Test MongoDB connection using the samehost container"""
    print("🔍 Testing MongoDB connection...")
    
    # Test basic MongoDB connection
    mongo_cmd = 'docker exec auth-mongodb-samehost mongosh --eval "db.adminCommand(\\"ping\\")"'
    output = run_command(mongo_cmd)
    
    if output and "ok" in output:
        print("✅ MongoDB connection successful!")
        return True
    else:
        print("❌ MongoDB connection failed!")
        return False

def check_api_health():
    """Check if the API is responding to health checks"""
    print("🔍 Checking API health...")
    
    try:
        import requests
        response = requests.get("http://localhost:3000/health", timeout=10)
        if response.status_code == 200:
            print("✅ API health check successful!")
            return True
        else:
            print(f"❌ API health check failed with status: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ API health check failed: {e}")
        return False

def check_environment_file():
    """Check if .env.samehost file exists and has required variables"""
    print("🔍 Checking .env.samehost file...")
    
    env_file = "../.env.samehost"
    if not os.path.exists(env_file):
        print("❌ .env.samehost file not found!")
        return False
    
    required_vars = [
        "JWT_ACCESS_SECRET",
        "JWT_REFRESH_SECRET", 
        "MONGODB_URI",
        "NODE_ENV"
    ]
    
    with open(env_file, 'r') as f:
        content = f.read()
    
    missing_vars = []
    for var in required_vars:
        if var not in content:
            missing_vars.append(var)
    
    if missing_vars:
        print(f"❌ Missing environment variables: {', '.join(missing_vars)}")
        return False
    
    print("✅ .env.samehost file looks good!")
    return True

def main():
    """Main test function"""
    print("=" * 60)
    print("🧪 SAMEHOST CONFIGURATION TEST")
    print("=" * 60)
    
    tests = [
        ("Environment File", check_environment_file),
        ("Docker Containers", check_docker_containers),
        ("MongoDB Connection", check_mongodb_connection),
        ("API Health", check_api_health),
    ]
    
    passed = 0
    failed = 0
    
    for test_name, test_func in tests:
        print(f"\n📋 Running {test_name} test...")
        try:
            if test_func():
                passed += 1
            else:
                failed += 1
        except Exception as e:
            print(f"❌ {test_name} test failed with exception: {e}")
            failed += 1
    
    print("\n" + "=" * 60)
    print(f"🧪 TEST RESULTS: {passed} passed, {failed} failed")
    print("=" * 60)
    
    if failed == 0:
        print("🎉 All tests passed! Your samehost configuration is working correctly.")
        print("\nYou can now run the user management scripts:")
        print("  python create_users.py")
        print("  python list_users.py")
        print("  python test_login.py")
    else:
        print("❌ Some tests failed. Please check the configuration and try again.")
        sys.exit(1)

if __name__ == "__main__":
    main()
