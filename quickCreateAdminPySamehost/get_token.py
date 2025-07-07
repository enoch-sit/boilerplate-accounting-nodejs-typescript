#!/usr/bin/env python3
"""
Get User Token Script
This script logs in as a specific user and retrieves their JWT token.
"""

import requests
import json
import sys
import os
import base64
import hmac
import hashlib
from datetime import datetime

# Configuration
API_BASE_URL = "http://localhost:3000"

# Default user credentials (you can modify these)
DEFAULT_USER = {
    "username": "admin",
    "password": "admin@admin@aidcec"
}

def check_api_health():
    """Check if the API server is running"""
    try:
        print(f"🔍 Checking API health at {API_BASE_URL}/health...")
        response = requests.get(f"{API_BASE_URL}/health", timeout=10)
        if response.status_code == 200:
            print("✅ API server is running")
            return True
        else:
            print(f"❌ API health check failed with status: {response.status_code}")
            return False
    except requests.RequestException as e:
        print(f"❌ API connection error: {e}")
        return False

def login_user(username, password):
    """Log in a user and return their JWT token"""
    try:
        print(f"🔐 Logging in user: {username}")
        
        login_data = {
            "username": username,
            "password": password
        }
        
        response = requests.post(
            f"{API_BASE_URL}/api/auth/login",
            json=login_data,
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            
            # Try to extract the token from different possible formats
            token = None
            
            # Try direct access first
            if "accessToken" in data:
                token = data["accessToken"]
            elif "token" in data and isinstance(data["token"], dict):
                token = data["token"].get("accessToken")
            elif "token" in data and isinstance(data["token"], str):
                token = data["token"]
            else:
                # Search for any field that looks like a JWT token
                for key, value in data.items():
                    if isinstance(value, str) and len(value) > 40 and '.' in value:
                        token = value
                        break
            
            if token:
                print("✅ Login successful!")
                print(f"🎫 JWT Token: {token}")
                
                # Try to decode token header (without verification for display)
                try:
                    header_b64 = token.split('.')[0]
                    # Add padding if needed
                    header_b64 += '=' * (4 - len(header_b64) % 4)
                    header = json.loads(base64.b64decode(header_b64).decode('utf-8'))
                    print(f"🔍 Token Header: {json.dumps(header, indent=2)}")
                except:
                    print("ℹ️  Could not decode token header")
                
                # Show basic payload info (without verification)
                payload = decode_jwt_payload(token)
                if payload:
                    print(f"🔍 Token Payload (unverified): {json.dumps(payload, indent=2)}")
                
                # Show response structure for debugging
                print(f"📋 Full Response: {json.dumps(data, indent=2)}")
                
                return token
            else:
                print("❌ No token found in response")
                print(f"📋 Response: {json.dumps(data, indent=2)}")
                return None
        else:
            print(f"❌ Login failed with status: {response.status_code}")
            print(f"📋 Response: {response.text}")
            return None
            
    except requests.RequestException as e:
        print(f"❌ Login request error: {e}")
        return None
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return None

def decode_jwt_payload(token):
    """Decode JWT payload without verification (for display purposes)"""
    try:
        # Split token into parts
        parts = token.split('.')
        if len(parts) != 3:
            return None
        
        # Decode payload (second part)
        payload_b64 = parts[1]
        # Add padding if needed
        payload_b64 += '=' * (4 - len(payload_b64) % 4)
        payload = json.loads(base64.b64decode(payload_b64).decode('utf-8'))
        
        return payload
    except Exception as e:
        print(f"❌ Error decoding payload: {e}")
        return None

def verify_jwt_token(token, secret_key):
    """Verify JWT token signature and expiration"""
    try:
        # Split token into parts
        parts = token.split('.')
        if len(parts) != 3:
            print("❌ Invalid token format")
            return False
        
        header_b64, payload_b64, signature_b64 = parts
        
        # Decode header
        header_b64_padded = header_b64 + '=' * (4 - len(header_b64) % 4)
        header = json.loads(base64.b64decode(header_b64_padded).decode('utf-8'))
        
        # Decode payload
        payload_b64_padded = payload_b64 + '=' * (4 - len(payload_b64) % 4)
        payload = json.loads(base64.b64decode(payload_b64_padded).decode('utf-8'))
        
        print(f"🔍 Token Header: {json.dumps(header, indent=2)}")
        print(f"🔍 Token Payload: {json.dumps(payload, indent=2)}")
        
        # Check algorithm
        if header.get('alg') != 'HS256':
            print(f"❌ Unsupported algorithm: {header.get('alg')}")
            return False
        
        # Verify signature
        message = f"{header_b64}.{payload_b64}"
        expected_signature = base64.urlsafe_b64encode(
            hmac.new(
                secret_key.encode('utf-8'),
                message.encode('utf-8'),
                hashlib.sha256
            ).digest()
        ).decode('utf-8').rstrip('=')
        
        # Remove padding from actual signature for comparison
        actual_signature = signature_b64.rstrip('=')
        
        if expected_signature != actual_signature:
            print("❌ Token signature verification failed")
            print(f"Expected: {expected_signature}")
            print(f"Actual: {actual_signature}")
            return False
        
        print("✅ Token signature verified successfully")
        
        # Check expiration
        if 'exp' in payload:
            exp_timestamp = payload['exp']
            exp_datetime = datetime.fromtimestamp(exp_timestamp)
            current_datetime = datetime.now()
            
            print(f"🕒 Token expires at: {exp_datetime}")
            print(f"🕒 Current time: {current_datetime}")
            
            if current_datetime > exp_datetime:
                print("❌ Token has expired")
                return False
            else:
                time_remaining = exp_datetime - current_datetime
                print(f"✅ Token is valid for {time_remaining}")
        
        # Check issued at
        if 'iat' in payload:
            iat_timestamp = payload['iat']
            iat_datetime = datetime.fromtimestamp(iat_timestamp)
            print(f"🕒 Token issued at: {iat_datetime}")
        
        # Show user info
        if 'userId' in payload:
            print(f"👤 User ID: {payload['userId']}")
        if 'username' in payload:
            print(f"👤 Username: {payload['username']}")
        if 'email' in payload:
            print(f"📧 Email: {payload['email']}")
        if 'role' in payload:
            print(f"🔐 Role: {payload['role']}")
        
        return True
        
    except Exception as e:
        print(f"❌ Token verification error: {e}")
        return False

def test_token(token):
    """Test the token by making an authenticated request"""
    try:
        print(f"🧪 Testing token validity...")
        
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }
        
        # Try to access a protected endpoint
        response = requests.get(
            f"{API_BASE_URL}/api/auth/me",
            headers=headers,
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Token is valid!")
            print(f"📋 User Info: {json.dumps(data, indent=2)}")
            return True
        else:
            print(f"❌ Token test failed with status: {response.status_code}")
            print(f"📋 Response: {response.text}")
            return False
            
    except requests.RequestException as e:
        print(f"❌ Token test error: {e}")
        return False

def main():
    """Main function"""
    print("🎫 JWT Token Retrieval Script")
    print("=" * 50)
    
    # Check if API is available
    if not check_api_health():
        print("❌ API is not available. Please start the Docker environment first.")
        sys.exit(1)
    
    # Get user credentials
    username = input(f"Enter username (default: {DEFAULT_USER['username']}): ").strip()
    if not username:
        username = DEFAULT_USER['username']
    
    password = input(f"Enter password (default: {DEFAULT_USER['password']}): ").strip()
    if not password:
        password = DEFAULT_USER['password']
    
    print(f"\n🔐 Attempting to login as: {username}")
    
    # Login and get token
    token = login_user(username, password)
    
    if token:
        print("\n" + "=" * 50)
        print("✅ SUCCESS! Here's your JWT token:")
        print("=" * 50)
        print(f"Token: {token}")
        print("=" * 50)
        
        # Test the token via API
        print("\n🧪 Testing token via API...")
        api_test_success = test_token(token)
        
        # Ask for secret key to verify token locally
        print("\n" + "=" * 50)
        print("🔑 JWT TOKEN VERIFICATION")
        print("=" * 50)
        
        verify_choice = input("Do you want to verify the token with a secret key? (y/n): ").strip().lower()
        
        if verify_choice in ['y', 'yes']:
            secret_key = input("Enter the JWT secret key: ").strip()
            
            if secret_key:
                print(f"\n🔐 Verifying token with provided secret key...")
                verification_success = verify_jwt_token(token, secret_key)
                
                if verification_success:
                    print("✅ Token verification completed successfully!")
                else:
                    print("❌ Token verification failed!")
            else:
                print("⚠️ No secret key provided, skipping verification")
        else:
            print("ℹ️ Skipping token verification")
        
        # Save token to file for easy access
        token_file = "jwt_token.txt"
        with open(token_file, "w") as f:
            f.write(token)
        print(f"\n💾 Token saved to: {token_file}")
        
        # Show curl example
        print("\n🌐 Example usage with curl:")
        print(f'curl -H "Authorization: Bearer {token}" {API_BASE_URL}/api/auth/me')
        
    else:
        print("❌ Failed to retrieve token")
        sys.exit(1)

if __name__ == "__main__":
    main()
