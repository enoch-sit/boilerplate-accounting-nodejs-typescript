#!/usr/bin/env python3
"""
JWT Token Verification Script
This script verifies a JWT token using a provided secret key.
"""

import json
import sys
import base64
import hmac
import hashlib
from datetime import datetime

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
        print("🔐 Starting JWT token verification...")
        print("=" * 50)
        
        # Split token into parts
        parts = token.split('.')
        if len(parts) != 3:
            print("❌ Invalid token format - JWT must have 3 parts separated by dots")
            return False
        
        header_b64, payload_b64, signature_b64 = parts
        
        # Decode header
        header_b64_padded = header_b64 + '=' * (4 - len(header_b64) % 4)
        header = json.loads(base64.b64decode(header_b64_padded).decode('utf-8'))
        
        # Decode payload
        payload_b64_padded = payload_b64 + '=' * (4 - len(payload_b64) % 4)
        payload = json.loads(base64.b64decode(payload_b64_padded).decode('utf-8'))
        
        print("📋 TOKEN CONTENTS:")
        print(f"🔍 Header: {json.dumps(header, indent=2)}")
        print(f"🔍 Payload: {json.dumps(payload, indent=2)}")
        print()
        
        # Check algorithm
        if header.get('alg') != 'HS256':
            print(f"❌ Unsupported algorithm: {header.get('alg')} (expected HS256)")
            return False
        
        print("✅ Algorithm check passed (HS256)")
        
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
            print("❌ SIGNATURE VERIFICATION FAILED")
            print(f"Expected: {expected_signature}")
            print(f"Actual:   {actual_signature}")
            print("🔍 This could mean:")
            print("  - Wrong secret key")
            print("  - Token was tampered with")
            print("  - Token was signed with a different key")
            return False
        
        print("✅ Signature verification passed")
        
        # Check expiration
        if 'exp' in payload:
            exp_timestamp = payload['exp']
            exp_datetime = datetime.fromtimestamp(exp_timestamp)
            current_datetime = datetime.now()
            
            print(f"🕒 Token expires at: {exp_datetime}")
            print(f"🕒 Current time:     {current_datetime}")
            
            if current_datetime > exp_datetime:
                print("❌ TOKEN HAS EXPIRED")
                return False
            else:
                time_remaining = exp_datetime - current_datetime
                print(f"✅ Token is valid for: {time_remaining}")
        else:
            print("⚠️ No expiration time found in token")
        
        # Check issued at
        if 'iat' in payload:
            iat_timestamp = payload['iat']
            iat_datetime = datetime.fromtimestamp(iat_timestamp)
            print(f"🕒 Token issued at: {iat_datetime}")
        
        # Show user info
        print("\n👤 USER INFORMATION:")
        if 'userId' in payload:
            print(f"   User ID: {payload['userId']}")
        if 'username' in payload:
            print(f"   Username: {payload['username']}")
        if 'email' in payload:
            print(f"   Email: {payload['email']}")
        if 'role' in payload:
            print(f"   Role: {payload['role']}")
        
        # Show other claims
        standard_claims = {'iat', 'exp', 'userId', 'username', 'email', 'role', 'iss', 'aud', 'sub'}
        other_claims = {k: v for k, v in payload.items() if k not in standard_claims}
        if other_claims:
            print("\n🔍 OTHER CLAIMS:")
            for key, value in other_claims.items():
                print(f"   {key}: {value}")
        
        return True
        
    except Exception as e:
        print(f"❌ Token verification error: {e}")
        return False

def main():
    """Main function"""
    print("🔐 JWT Token Verification Tool")
    print("=" * 50)
    
    # Get token
    token_choice = input("Do you want to (1) enter token manually or (2) read from jwt_token.txt? (1/2): ").strip()
    
    token = None
    if token_choice == "2":
        try:
            with open("jwt_token.txt", "r") as f:
                token = f.read().strip()
            print(f"✅ Token loaded from jwt_token.txt")
        except FileNotFoundError:
            print("❌ jwt_token.txt not found")
        except Exception as e:
            print(f"❌ Error reading jwt_token.txt: {e}")
    
    if not token:
        token = input("Enter JWT token: ").strip()
    
    if not token:
        print("❌ No token provided")
        sys.exit(1)
    
    # Get secret key
    secret_key = input("Enter JWT secret key: ").strip()
    
    if not secret_key:
        print("❌ No secret key provided")
        sys.exit(1)
    
    print(f"\n🔐 Verifying token...")
    print(f"Token preview: {token[:50]}..." if len(token) > 50 else f"Token: {token}")
    print()
    
    # Verify token
    verification_success = verify_jwt_token(token, secret_key)
    
    print("\n" + "=" * 50)
    if verification_success:
        print("🎉 TOKEN VERIFICATION SUCCESSFUL!")
        print("✅ The token is valid and properly signed")
    else:
        print("❌ TOKEN VERIFICATION FAILED!")
        print("❌ The token is invalid, expired, or incorrectly signed")
    print("=" * 50)

if __name__ == "__main__":
    main()
