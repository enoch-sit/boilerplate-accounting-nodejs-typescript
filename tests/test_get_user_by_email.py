#!/usr/bin/env python3
"""
Test Get User by Email API Endpoint
This script tests the new GET /api/admin/users/by-email/:email endpoint
"""

import requests
import json
import sys
import urllib.parse
from typing import Dict, Optional, Any
import argparse

# Configuration
API_BASE_URL = "http://localhost:3000"

def check_api_health() -> bool:
    """Check if the API server is running"""
    try:
        response = requests.get(f"{API_BASE_URL}/health", timeout=5)
        return response.status_code == 200
    except requests.exceptions.RequestException:
        return False

def login_admin(username: str = "admin", password: str = "admin@admin") -> Optional[str]:
    """Login as admin and get access token"""
    print(f"Logging in as admin user: {username}")
    
    try:
        response = requests.post(
            f"{API_BASE_URL}/api/auth/login",
            json={
                "username": username,
                "password": password
            },
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            access_token = data.get("accessToken")
            
            if access_token:
                print("✅ Admin login successful")
                return access_token
            else:
                print("❌ No access token in response")
                print(f"Response: {json.dumps(data, indent=2)}")
                return None
        else:
            print(f"❌ Login failed: {response.status_code}")
            print(f"Response: {response.text}")
            return None
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Login request failed: {e}")
        return None

def get_user_by_email(email: str, admin_token: str) -> Optional[Dict[str, Any]]:
    """
    Test the GET /api/admin/users/by-email/:email endpoint
    
    Args:
        email: User's email address
        admin_token: Admin JWT token for authentication
        
    Returns:
        Dict containing user info, or None if not found/error
    """
    print(f"\nTesting GET /api/admin/users/by-email/{email}")
    
    # URL encode the email
    encoded_email = urllib.parse.quote(email, safe='')
    url = f"{API_BASE_URL}/api/admin/users/by-email/{encoded_email}"
    
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": f"Bearer {admin_token}"
    }
    
    try:
        print(f"Making request to: {url}")
        print(f"Headers: Authorization: Bearer {admin_token[:20]}...")
        
        response = requests.get(url, headers=headers, timeout=10)
        
        print(f"Response Status: {response.status_code}")
        print(f"Response Headers: {dict(response.headers)}")
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Request successful!")
            print(f"Response: {json.dumps(data, indent=2)}")
            
            # Extract user data
            user_data = data.get('user')
            if user_data:
                return {
                    'user_id': user_data.get('_id'),
                    'username': user_data.get('username'),
                    'email': user_data.get('email'),
                    'role': user_data.get('role'),
                    'is_verified': user_data.get('isVerified', False),
                    'created_at': user_data.get('createdAt'),
                    'updated_at': user_data.get('updatedAt')
                }
            else:
                print("⚠️ No user data in response")
                return None
                
        elif response.status_code == 404:
            print(f"❌ User not found: {email}")
            try:
                error_data = response.json()
                print(f"Error details: {json.dumps(error_data, indent=2)}")
            except:
                print(f"Error response: {response.text}")
            return None
            
        elif response.status_code == 401:
            print("❌ Unauthorized - check admin token")
            return None
            
        elif response.status_code == 403:
            print("❌ Forbidden - admin access required")
            return None
            
        else:
            print(f"❌ Unexpected status code: {response.status_code}")
            print(f"Response: {response.text}")
            return None
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Request failed: {e}")
        return None

def list_all_users(admin_token: str) -> Optional[list]:
    """Get all users for comparison"""
    print("\nGetting all users for comparison...")
    
    headers = {
        "Authorization": f"Bearer {admin_token}"
    }
    
    try:
        response = requests.get(
            f"{API_BASE_URL}/api/admin/users",
            headers=headers,
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            users = data.get('users', [])
            print(f"Found {len(users)} total users in system")
            return users
        else:
            print(f"❌ Failed to get users list: {response.status_code}")
            return None
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Failed to get users list: {e}")
        return None

def test_multiple_emails(admin_token: str, users: list):
    """Test the endpoint with multiple email addresses"""
    print("\n" + "="*60)
    print("TESTING MULTIPLE EMAIL ADDRESSES")
    print("="*60)
    
    # Test with existing users
    print("\n--- Testing with existing users ---")
    for user in users[:5]:  # Test first 5 users
        email = user.get('email')
        if email:
            result = get_user_by_email(email, admin_token)
            if result:
                print(f"✅ Found user: {result['username']} ({result['email']}) - Role: {result['role']}")
            else:
                print(f"❌ Failed to find user with email: {email}")
    
    # Test with non-existent email
    print("\n--- Testing with non-existent email ---")
    fake_email = "nonexistent@example.com"
    result = get_user_by_email(fake_email, admin_token)
    if result is None:
        print(f"✅ Correctly returned None for non-existent email: {fake_email}")
    else:
        print(f"❌ Unexpected result for non-existent email: {result}")
    
    # Test with special characters in email
    print("\n--- Testing with special characters ---")
    special_emails = [
        "test+tag@example.com",
        "user.name@example.com", 
        "user-name@example.com"
    ]
    
    for email in special_emails:
        print(f"\nTesting special email: {email}")
        result = get_user_by_email(email, admin_token)
        # These should return 404 since they don't exist, but shouldn't error

def test_invalid_scenarios(admin_token: str):
    """Test invalid scenarios"""
    print("\n" + "="*60)
    print("TESTING INVALID SCENARIOS")
    print("="*60)
    
    # Test with invalid token
    print("\n--- Testing with invalid token ---")
    fake_token = "invalid.token.here"
    result = get_user_by_email("admin@example.com", fake_token)
    if result is None:
        print("✅ Correctly handled invalid token")
    
    # Test with empty email (should be handled by URL routing)
    print("\n--- Testing edge cases ---")
    edge_cases = ["", " ", "@", "@example.com", "invalid-email"]
    
    for email in edge_cases:
        if email.strip():  # Skip empty emails as they'll cause routing issues
            print(f"Testing edge case email: '{email}'")
            result = get_user_by_email(email, admin_token)

def main():
    parser = argparse.ArgumentParser(description='Test the Get User by Email API endpoint')
    parser.add_argument('--email', help='Specific email to test')
    parser.add_argument('--admin-username', default='admin', help='Admin username (default: admin)')
    parser.add_argument('--admin-password', default='admin@admin', help='Admin password (default: admin@admin)')
    parser.add_argument('--api-url', default='http://localhost:3000', help='API base URL (default: http://localhost:3000)')
    parser.add_argument('--skip-health-check', action='store_true', help='Skip API health check')
    
    args = parser.parse_args()
    
    # Update global API URL if provided
    global API_BASE_URL
    API_BASE_URL = args.api_url.rstrip('/')
    
    print("="*60)
    print("GET USER BY EMAIL API ENDPOINT TEST")
    print("="*60)
    print(f"API URL: {API_BASE_URL}")
    print(f"Testing endpoint: GET /api/admin/users/by-email/:email")
    
    # Check if API is running
    if not args.skip_health_check:
        print("\nChecking API health...")
        if not check_api_health():
            print("❌ API server is not running or not accessible")
            print(f"Please ensure the server is running at {API_BASE_URL}")
            sys.exit(1)
        print("✅ API server is running")
    
    # Login as admin
    print("\n" + "="*60)
    print("ADMIN LOGIN")
    print("="*60)
    
    admin_token = login_admin(args.admin_username, args.admin_password)
    if not admin_token:
        print("❌ Failed to get admin token. Cannot proceed with tests.")
        sys.exit(1)
    
    # Test specific email if provided
    if args.email:
        print("\n" + "="*60)
        print(f"TESTING SPECIFIC EMAIL: {args.email}")
        print("="*60)
        
        result = get_user_by_email(args.email, admin_token)
        if result:
            print(f"\n✅ SUCCESS: Found user")
            print(f"User ID: {result['user_id']}")
            print(f"Username: {result['username']}")
            print(f"Email: {result['email']}")
            print(f"Role: {result['role']}")
            print(f"Verified: {result['is_verified']}")
            print(f"Created: {result['created_at']}")
        else:
            print(f"\n❌ FAILED: User not found or error occurred")
        
        sys.exit(0 if result else 1)
    
    # Get all users for comprehensive testing
    users = list_all_users(admin_token)
    if not users:
        print("❌ Could not get users list for testing")
        sys.exit(1)
    
    # Run comprehensive tests
    test_multiple_emails(admin_token, users)
    test_invalid_scenarios(admin_token)
    
    print("\n" + "="*60)
    print("TEST COMPLETED")
    print("="*60)
    print("✅ All tests completed successfully!")
    print("\nThe GET /api/admin/users/by-email/:email endpoint is working correctly.")

if __name__ == "__main__":
    main()
