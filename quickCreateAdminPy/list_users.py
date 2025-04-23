#!/usr/bin/env python3
"""
User Listing Script for Simple Authentication System
This script lists all users in the database with their roles and verification status.
"""

import requests
import subprocess
import json
import sys
import os
import datetime
from tabulate import tabulate

# Configuration
API_BASE_URL = "http://localhost:3000"
MONGODB_CONTAINER = "auth-mongodb"


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
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"Command failed with error: {e}")
        print(f"Error output: {e.stderr}")
        return None


def check_api_health():
    """Check if the API server is running"""
    try:
        print(f"Checking API health at {API_BASE_URL}/health...")
        response = requests.get(f"{API_BASE_URL}/health", timeout=10)
        print(f"API response status: {response.status_code}")
        if response.status_code == 200:
            print("✅ API server is running")
            return True
    except requests.RequestException as e:
        print(f"❌ API connection error: {e}")

    print("❌ API server is not running. Please start the Docker environment first.")
    print("Run: docker-compose -f docker-compose.dev.yml up -d")
    return False


def get_admin_token():
    """Log in as admin and get the access token"""
    print("\n--- Getting admin access token ---")
    
    admin_credentials = {
        "username": "admin",
        "password": "admin@admin"
    }
    
    try:
        response = requests.post(
            f"{API_BASE_URL}/api/auth/login",
            json=admin_credentials
        )

        if response.status_code == 200:
            data = response.json()
            # Try both access patterns to handle different API response formats
            token = data.get("accessToken")
            if not token:
                # Try nested format
                token = data.get("token", {}).get("accessToken")

            if token:
                print("✅ Admin access token obtained")
                return token
            else:
                print("❌ Access token not found in response")
                print(f"Response data: {data}")
        else:
            print(f"❌ Failed to log in as admin: {response.text}")
            print("Will fall back to direct MongoDB access method")
    except requests.RequestException as e:
        print(f"❌ Request error: {e}")
        print("Will fall back to direct MongoDB access method")

    return None


def list_users_api(token):
    """List users using the API (requires admin privileges)"""
    print("\n--- Fetching users via API ---")
    try:
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }

        response = requests.get(
            f"{API_BASE_URL}/api/admin/users",
            headers=headers
        )

        if response.status_code == 200:
            data = response.json()
            users = data.get("users", [])
            return users
        else:
            print(f"❌ Failed to fetch users: {response.text}")
            return None
    except requests.RequestException as e:
        print(f"❌ Request error: {e}")
        return None


def list_users_direct():
    """List users directly from MongoDB"""
    print("\n--- Fetching users directly from database ---")
    
    # Create MongoDB command to fetch users with selected fields
    mongo_commands = """use auth_db
db.users.find({}, {
    username: 1,
    email: 1,
    role: 1,
    isVerified: 1,
    createdAt: 1,
    lastLogin: 1
}).toArray()
exit
"""
    
    # Create a temporary file for MongoDB commands
    script_dir = os.path.dirname(os.path.abspath(__file__))
    mongo_file_path = os.path.join(script_dir, "temp_mongo_list.js")
    with open(mongo_file_path, "w") as f:
        f.write(mongo_commands)
    
    # Execute MongoDB commands
    command = f'docker exec -i {MONGODB_CONTAINER} mongosh --quiet --json < "{mongo_file_path}"'
    output = run_command(command)
    
    # Clean up temporary file
    try:
        os.remove(mongo_file_path)
    except:
        pass
    
    if not output:
        print("❌ Failed to execute database commands")
        return None
    
    # Try to parse the JSON output
    try:
        # MongoDB might return multiple JSON objects, so handle this by removing line breaks
        # and wrapping in square brackets if needed
        cleaned_output = output.strip()
        if cleaned_output.startswith('[') and cleaned_output.endswith(']'):
            users = json.loads(cleaned_output)
        else:
            # Handle multiple JSON objects by joining them into an array
            json_lines = cleaned_output.split('\n')
            combined_json = '[' + ','.join(json_lines) + ']'
            users = json.loads(combined_json)
        
        return users
    except json.JSONDecodeError as e:
        print(f"❌ Failed to parse JSON: {e}")
        print(f"Raw output: {output}")
        return None


def format_datetime(dt_str):
    """Format datetime string for display"""
    if not dt_str:
        return "Never"
    
    try:
        # Parse ISO format datetime
        dt = datetime.datetime.fromisoformat(dt_str.replace('Z', '+00:00'))
        
        # Format to a more readable form
        return dt.strftime("%Y-%m-%d %H:%M:%S")
    except:
        return dt_str


def display_users(users):
    """Display users in a formatted table"""
    if not users:
        print("No users found in database.")
        return
    
    # Prepare data for tabulate
    table_data = []
    for user in users:
        # Extract user ID from _id field which could be in different formats
        user_id = None
        if isinstance(user.get('_id'), dict) and '$oid' in user.get('_id', {}):
            user_id = user['_id']['$oid']
        else:
            user_id = str(user.get('_id', 'N/A'))
        
        # Format dates
        created_at = format_datetime(user.get('createdAt', ''))
        last_login = format_datetime(user.get('lastLogin', ''))
        
        # Add row to table
        table_data.append([
            user.get('username', 'N/A'),
            user.get('email', 'N/A'),
            user.get('role', 'N/A'),
            '✓' if user.get('isVerified', False) else '✗',
            created_at,
            last_login,
            user_id[:10] + '...' if len(user_id) > 10 else user_id
        ])
    
    # Print the table
    headers = ["Username", "Email", "Role", "Verified", "Created At", "Last Login", "User ID"]
    print(tabulate(table_data, headers=headers, tablefmt="grid"))
    
    # Print summary
    print(f"\nTotal users: {len(users)}")
    
    # Count by role
    roles = {}
    for user in users:
        role = user.get('role', 'unknown')
        roles[role] = roles.get(role, 0) + 1
    
    print("\nUsers by role:")
    for role, count in roles.items():
        print(f"- {role}: {count}")


def main():
    # Check if API server is running
    if not check_api_health():
        sys.exit(1)
    
    print("\n=== User Listing ===")
    
    # Try to get admin token for API access
    token = get_admin_token()
    
    users = None
    if token:
        # Try using the API first
        users = list_users_api(token)
    
    # Fall back to direct MongoDB access if API method fails
    if users is None:
        users = list_users_direct()
    
    if users is None:
        print("❌ Failed to retrieve users")
        sys.exit(1)
    
    # Display users in a formatted table
    display_users(users)


if __name__ == "__main__":
    main()