#!/usr/bin/env python3
"""
User Removal Script for Simple Authentication System
This script removes ALL users from the database, including admin users.
CAUTION: This will permanently delete all users and related data!
"""

import requests
import subprocess
import time
import sys
import os
import datetime
from getpass import getpass

# Configuration
API_BASE_URL = "http://localhost:3000"
MONGODB_CONTAINER = "auth-mongodb"

# Log file setup
LOG_FILE = "user_removal.log"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
LOG_PATH = os.path.join(SCRIPT_DIR, LOG_FILE)


def log_removal_action(message):
    """Log removal actions to file"""
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"[{timestamp}] {message}"

    with open(LOG_PATH, "a") as log_file:
        log_file.write(log_entry + "\n")

    print(f"✓ {message}")


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


def count_users():
    """Count users in the database and return stats"""
    mongo_commands = """use auth_db
db.users.countDocuments()
db.users.countDocuments({role: "admin"})
db.tokens.countDocuments()
db.verifications.countDocuments()
exit
"""
    
    # Create a temporary file for MongoDB commands
    mongo_file_path = os.path.join(SCRIPT_DIR, "temp_mongo_count.js")
    with open(mongo_file_path, "w") as f:
        f.write(mongo_commands)
    
    # Execute MongoDB commands
    command = f'docker exec -i {MONGODB_CONTAINER} mongosh < "{mongo_file_path}"'
    output = run_command(command)
    
    # Clean up temporary file
    try:
        os.remove(mongo_file_path)
    except:
        pass
    
    if not output:
        return None
    
    # Parse output to extract counts
    lines = output.strip().split('\n')
    counts = {}
    
    # Find the count values in the output
    for line in lines:
        if line.isdigit():
            if "counts" not in locals():
                counts["total_users"] = int(line)
                continue
            elif "admin_users" not in counts:
                counts["admin_users"] = int(line)
                continue
            elif "tokens" not in counts:
                counts["tokens"] = int(line)
                continue
            elif "verifications" not in counts:
                counts["verifications"] = int(line)
                continue
    
    return counts


def remove_all_users_direct():
    """Remove all users directly from MongoDB"""
    print("\n--- Removing all users from database ---")
    
    # First, count and log the current state
    print("Counting current users...")
    counts = count_users()
    if counts:
        print(f"Found {counts.get('total_users', 'unknown')} total users (including {counts.get('admin_users', 'unknown')} admins)")
        print(f"Found {counts.get('tokens', 'unknown')} tokens and {counts.get('verifications', 'unknown')} verification records")
        
        # Log the counts
        log_removal_action(f"Starting removal - Found {counts.get('total_users', 'unknown')} users, {counts.get('admin_users', 'unknown')} admins, {counts.get('tokens', 'unknown')} tokens, {counts.get('verifications', 'unknown')} verifications")
    
    # Create the MongoDB commands to remove all users and related data
    mongo_commands = """use auth_db
// Get count before deletion for reporting
let userCount = db.users.countDocuments()
let tokenCount = db.tokens.countDocuments()
let verificationCount = db.verifications.countDocuments()

// Perform deletions
db.users.deleteMany({})
db.tokens.deleteMany({})
db.verifications.deleteMany({})

// Report results
print("DELETION_RESULTS:")
print("Users deleted: " + userCount)
print("Tokens deleted: " + tokenCount)
print("Verifications deleted: " + verificationCount)
exit
"""
    
    # Create a temporary file for MongoDB commands
    mongo_file_path = os.path.join(SCRIPT_DIR, "temp_mongo_delete.js")
    with open(mongo_file_path, "w") as f:
        f.write(mongo_commands)
    
    # Execute MongoDB commands
    command = f'docker exec -i {MONGODB_CONTAINER} mongosh < "{mongo_file_path}"'
    output = run_command(command)
    
    # Clean up temporary file
    try:
        os.remove(mongo_file_path)
    except:
        pass
    
    if not output:
        print("❌ Failed to execute database commands")
        return False
    
    # Parse the results
    if "DELETION_RESULTS:" in output:
        # Extract the deletion counts
        results_section = output.split("DELETION_RESULTS:")[1].strip().split("\n")
        users_deleted = next((line.split(": ")[1] for line in results_section if "Users deleted" in line), "unknown")
        tokens_deleted = next((line.split(": ")[1] for line in results_section if "Tokens deleted" in line), "unknown")
        verifications_deleted = next((line.split(": ")[1] for line in results_section if "Verifications deleted" in line), "unknown")
        
        print(f"✅ Successfully removed:")
        print(f"  - {users_deleted} users")
        print(f"  - {tokens_deleted} tokens")
        print(f"  - {verifications_deleted} verification records")
        
        # Log the deletion
        log_removal_action(f"Successfully removed {users_deleted} users, {tokens_deleted} tokens, and {verifications_deleted} verification records")
        return True
    else:
        print("❌ Failed to parse deletion results")
        print(f"Output: {output}")
        return False


def main():
    # Create log file header if it doesn't exist or is empty
    if not os.path.exists(LOG_PATH) or os.path.getsize(LOG_PATH) == 0:
        with open(LOG_PATH, "w") as log_file:
            timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            log_file.write(f"# User Removal Log - Started {timestamp}\n\n")
    
    # Check if API server is running
    if not check_api_health():
        sys.exit(1)
    
    # Confirmation
    print("\n⚠️  WARNING: This will permanently delete ALL users including admin accounts! ⚠️")
    print("This action cannot be undone and will require recreating all users.")
    
    # Ask for confirmation with a specific phrase
    confirm = input("\nTo confirm, type 'DELETE ALL USERS': ")
    if confirm != "DELETE ALL USERS":
        print("Aborted. No users were deleted.")
        log_removal_action("User aborted deletion process")
        sys.exit(0)
    
    # Double-check with password
    print("\nFor additional security, please enter a password:")
    password = getpass("Password (anything will work): ")
    if not password:
        print("Aborted. No users were deleted.")
        log_removal_action("User aborted deletion at password prompt")
        sys.exit(0)
    
    # Perform the deletion
    success = remove_all_users_direct()
    
    if success:
        print("\n✨ All users have been successfully removed from the database!")
        print("To create new users, you can run the create_users.py script.")
        print(f"\nRemoval log saved to: {LOG_PATH}")
    else:
        print("\n❌ Error occurred during user removal.")
        print("Some users may remain in the database.")
        sys.exit(1)


if __name__ == "__main__":
    main()