#!/usr/bin/env python3
"""
Simple Login Example
This script demonstrates how to login to the authentication system with just username/email and password.
"""

import requests
import json

# Configuration
API_URL = "http://localhost:3000/api"  # Update with your server address

def simple_login():
    """
    A simple login example that prompts the user for credentials
    """
    print("=== Simple Authentication Login Example ===")
    
    # Get user credentials
    username_or_email = input("Enter your username or email: ")
    password = input("Enter your password: ")
    
    # Create the payload - just username/email and password are required
    payload = {
        "username": username_or_email,  # The server accepts either username or email in this field
        "password": password
    }
    
    # Endpoint for login
    url = f"{API_URL}/auth/login"
    
    try:
        # Make the request
        print("\nSending login request...")
        response = requests.post(url, json=payload)
        
        # Handle the response
        if response.status_code == 200:
            data = response.json()
            print("\n✅ Login successful!")
            print(f"User: {data['user']['username']}")
            print(f"Email: {data['user']['email']}")
            print(f"Role: {data['user']['role']}")
            
            # Print tokens (in a real app, you would store these securely)
            print("\nYour access token (store this securely):")
            print(f"{data['accessToken'][:20]}...")
            print("\nYour refresh token (store this securely):")
            print(f"{data['refreshToken'][:20]}...")
            
            return True
        else:
            # Handle specific error cases
            error_data = response.json()
            error_msg = error_data.get("error", "Unknown error")
            
            if "Email not verified" in error_msg:
                print("\n❌ Login failed: Your email has not been verified.")
                print("Please check your email for a verification code or request a new one.")
            elif "Invalid credentials" in error_msg:
                print("\n❌ Login failed: Invalid username/email or password.")
            else:
                print(f"\n❌ Login failed: {error_msg}")
            
            return False
            
    except requests.exceptions.ConnectionError:
        print("\n❌ Connection error: Unable to connect to the server.")
        print(f"Please make sure the server is running at {API_URL}")
        return False
    except json.JSONDecodeError:
        print("\n❌ Error: Invalid response from server.")
        return False
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")
        return False

if __name__ == "__main__":
    simple_login()