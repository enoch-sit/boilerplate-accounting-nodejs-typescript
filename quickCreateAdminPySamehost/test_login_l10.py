#!/usr/bin/env python3
"""
Test Login Script for Simple Authentication System
This script attempts to log in with all users and displays their JWT tokens.
Includes debug information to help troubleshoot malformed JWT errors.
"""

import json
import requests
import sys
import os
import datetime
import base64
import time
from pprint import pprint

# Configuration
API_BASE_URL = "http://localhost:3000"
LOG_FILE = "login_test.log"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
LOG_PATH = os.path.join(SCRIPT_DIR, LOG_FILE)

# Delay between login attempts (in seconds)
LOGIN_DELAY = 0.5

# User credentials from create_users.py
ADMIN_USER = {
    "username": "admin",
    "email": "admin@example.com",
    "password": "admin@admin@aidcec",  # Please change this
}
SUPERVISOR_USERS = [
    {
        "username": "supervisor1",
        "email": "supervisor1@example.com",
        "password": "Supervisor1@",
        "role": "supervisor",
    },
    {
        "username": "supervisor2",
        "email": "supervisor2@example.com",
        "password": "Supervisor2@",
        "role": "supervisor",
    },
]
REGULAR_USERS = [
    {
        "username": f"User{i:02d}",
        "email": f"user{i:02d}@aidcec.com",
        "password": f"User{i:02d}@aidcec",
        "role": "enduser",
    }
    for i in range(90, 101)
]

# Combine all users for testing
ALL_USERS = [ADMIN_USER] + SUPERVISOR_USERS + REGULAR_USERS


def decode_jwt_payload(token):
    """Decode and return the payload from a JWT token"""
    try:
        # Split the token into its three parts
        parts = token.split(".")

        if len(parts) != 3:
            return f"Invalid token format: expected 3 parts, got {len(parts)}"

        # Decode the payload (middle part)
        # Add padding if needed
        payload = parts[1]
        padding = "=" * (4 - len(payload) % 4)
        payload += padding

        # Replace URL-safe characters
        payload = payload.replace("-", "+").replace("_", "/")

        # Decode base64
        decoded_bytes = base64.b64decode(payload)
        decoded_str = decoded_bytes.decode("utf-8")

        # Parse as JSON
        payload_json = json.loads(decoded_str)
        return payload_json
    except Exception as e:
        return f"Error decoding token: {str(e)}"


def log_token(username, email, password, token=None, status=None, error=None):
    """Log login attempt and token to file"""
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    if token:
        # Decode and include token details in the log
        token_payload = decode_jwt_payload(token)

        log_entry = f"[{timestamp}] LOGIN SUCCESS: username='{username}', email='{email}', password='{password}'\n"
        log_entry += f"TOKEN: {token}\n"
        log_entry += f"TOKEN PAYLOAD: {json.dumps(token_payload, indent=2)}\n\n"
    else:
        log_entry = f"[{timestamp}] LOGIN FAILED: username='{username}', email='{email}', password='{password}'\n"
        log_entry += f"STATUS: {status}, ERROR: {error}\n\n"

    with open(LOG_PATH, "a") as log_file:
        log_file.write(log_entry)


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


def test_api_with_token(token, username):
    """Test authenticated endpoints with the token"""
    if not token:
        return False

    print(f"\n--- Testing API access with token for {username} ---")

    # Update to use correct endpoint paths based on the API routes in the codebase
    endpoints = ["/api/profile", "/api/dashboard"]

    if username == "admin":
        endpoints.append("/api/admin/users")

    success = False

    for endpoint in endpoints:
        try:
            print(f"Testing endpoint: {endpoint}")
            # Print the exact format of the headers being sent
            auth_header = f"Bearer {token}"
            headers = {"Authorization": auth_header}
            print(f"Using Authorization header: {auth_header}")

            response = requests.get(f"{API_BASE_URL}{endpoint}", headers=headers)

            if response.status_code == 200:
                print(f"✅ Successfully accessed {endpoint}")
                print(f"Response: {response.text[:100]}...")  # Show first 100 chars
                success = True
            else:
                print(f"❌ Failed to access {endpoint}: {response.status_code}")
                print(f"Response: {response.text}")
        except Exception as e:
            print(f"❌ Error testing endpoint {endpoint}: {str(e)}")

    return success


def login_user(user):
    """Attempt to log in as a user and get the access token"""
    username = user.get("username")
    email = user.get("email")
    password = user.get("password")

    print(f"\n--- Attempting login for {username} ---")
    try:
        response = requests.post(
            f"{API_BASE_URL}/api/auth/login",
            json={
                "username": username,
                "password": password,
            },
        )

        # Print the full response for debugging
        print(f"Response Status: {response.status_code}")
        print(f"Response Headers: {response.headers}")

        # Try to parse response as JSON, fallback to text if not possible
        try:
            data = response.json()
            print(f"Response JSON: {json.dumps(data, indent=2)}")
        except:
            print(f"Response Text: {response.text}")
            data = {}

        if response.status_code == 200:
            # Try to find token using different access patterns
            token = None

            # Method 1: Direct access
            token = data.get("accessToken")

            # Method 2: Nested format
            if not token and "token" in data:
                token = data.get("token", {}).get("accessToken")

            # Method 3: Check for other formats
            if not token and isinstance(data, dict):
                # Look through all string fields for something that looks like a JWT
                for key, value in data.items():
                    if isinstance(value, str) and len(value) > 40 and "." in value:
                        token = value
                        print(f"Found potential token in field '{key}'")
                        break

            # Method 4: Try to extract from response body if it's a string
            if not token and isinstance(data, str) and "." in data and len(data) > 40:
                token = data

            # Last resort: Check raw response text
            if not token and "." in response.text and len(response.text) > 40:
                # Look for JWT pattern in raw text
                import re

                jwt_pattern = r"eyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+"
                matches = re.findall(jwt_pattern, response.text)
                if matches:
                    token = matches[0]
                    print(f"Extracted token using regex: {token[:20]}...")

            if token:
                print(f"✅ {username} login successful")
                print(f"Username: {username}")
                print(f"Email: {email}")
                print(f"Password: {password}")
                print(f"JWT Token: {token}")

                # Try to decode token parts
                parts = token.split(".")
                if len(parts) == 3:
                    print(f"Token is properly formatted with 3 parts")
                else:
                    print(f"⚠️ Warning: Token has {len(parts)} parts, expected 3")

                # Decode and show payload
                payload = decode_jwt_payload(token)
                print(f"Token payload: {json.dumps(payload, indent=2)}")

                # Test token with API
                test_api_with_token(token, username)

                # Log successful login with token
                log_token(username, email, password, token)
                return token
            else:
                print(f"❌ Access token not found in response")
                log_token(
                    username,
                    email,
                    password,
                    None,
                    response.status_code,
                    "Token not found in response",
                )
        else:
            print(f"❌ Failed to log in as {username}: {response.text}")
            log_token(
                username, email, password, None, response.status_code, response.text
            )
    except requests.RequestException as e:
        print(f"❌ Request error: {e}")
        log_token(username, email, password, None, "Request Error", str(e))
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        log_token(username, email, password, None, "Unexpected Error", str(e))

    return None


def main():
    # Create log file header
    with open(LOG_PATH, "w") as log_file:
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_file.write(f"# Login Test Log - Started {timestamp}\n")
        log_file.write(
            "# Format: [timestamp] LOGIN STATUS: username='xxx', email='xxx', password='xxx'\n\n"
        )

    # Check if API server is running
    if not check_api_health():
        sys.exit(1)

    # Test login for all users
    successful_logins = 0
    failed_logins = 0

    print("\n===== TESTING USER LOGINS =====")

    for i, user in enumerate(ALL_USERS):
        # Add delay between login attempts (except for the first one)
        if i > 0:
            print(f"Waiting {LOGIN_DELAY} seconds before next login attempt...")
            time.sleep(LOGIN_DELAY)

        token = login_user(user)
        if token:
            successful_logins += 1
        else:
            failed_logins += 1

    # Print summary
    print("\n===== LOGIN TEST SUMMARY =====")
    print(f"Total users tested: {len(ALL_USERS)}")
    print(f"Successful logins: {successful_logins}")
    print(f"Failed logins: {failed_logins}")
    print(f"\nLogin test log saved to: {LOG_PATH}")

    # Print instructions for using tokens in API requests
    print("\n===== HOW TO USE TOKENS =====")
    print("To use a token in an API request, add the following header:")
    print("Authorization: Bearer <token>")
    print("\nExample curl command:")
    print(
        'curl -H "Authorization: Bearer <token>" http://localhost:3000/api/protected/me'
    )
    print("\nCheck the log file for full token details.")


if __name__ == "__main__":
    main()
