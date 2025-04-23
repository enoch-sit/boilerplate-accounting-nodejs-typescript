#!/usr/bin/env python3
"""
Authentication Example - Login using Python
This script demonstrates how to:
1. Login to the authentication system
2. Store tokens
3. Make authenticated requests
4. Refresh tokens
5. Logout
"""

import requests
import json
import sys
from typing import Dict, Optional, Tuple, Any

# Configuration
API_URL = "http://localhost:3000/api"  # Update with your server address


def login(username_or_email: str, password: str) -> Tuple[bool, Dict[str, Any]]:
    """
    Login to the authentication system.
    
    Args:
        username_or_email: The username or email address
        password: The user's password
    
    Returns:
        Tuple containing success status and response data (with tokens if successful)
    """
    url = f"{API_URL}/auth/login"
    
    # Create the payload
    payload = {
        "username": username_or_email,  # The server accepts this field as username or email
        "password": password
    }
    
    try:
        # Make the request
        response = requests.post(url, json=payload)
        
        # Check if request was successful
        if response.status_code == 200:
            data = response.json()
            print(f"Login successful! Welcome, {data['user']['username']}!")
            return True, data
        else:
            error_msg = response.json().get("error", "Unknown error")
            print(f"Login failed: {error_msg}")
            return False, {"error": error_msg}
            
    except requests.exceptions.RequestException as e:
        print(f"Error connecting to the server: {e}")
        return False, {"error": str(e)}
    except json.JSONDecodeError:
        print("Error decoding server response")
        return False, {"error": "Invalid server response"}


def make_authenticated_request(endpoint: str, access_token: str) -> Dict[str, Any]:
    """
    Make an authenticated request to a protected endpoint.
    
    Args:
        endpoint: The API endpoint (without the base URL)
        access_token: The JWT access token
        
    Returns:
        The response data from the server
    """
    url = f"{API_URL}{endpoint}"
    headers = {
        "Authorization": f"Bearer {access_token}"
    }
    
    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            return response.json()
        else:
            print(f"Request failed with status code {response.status_code}")
            return {"error": response.json().get("error", "Request failed")}
    except Exception as e:
        print(f"Error making authenticated request: {e}")
        return {"error": str(e)}


def refresh_token(refresh_token: str) -> Tuple[bool, Optional[str]]:
    """
    Refresh the access token using a refresh token.
    
    Args:
        refresh_token: The JWT refresh token
        
    Returns:
        Tuple containing success status and new access token if successful
    """
    url = f"{API_URL}/auth/refresh"
    payload = {
        "refreshToken": refresh_token
    }
    
    try:
        response = requests.post(url, json=payload)
        if response.status_code == 200:
            data = response.json()
            print("Token refreshed successfully")
            return True, data.get("accessToken")
        else:
            print("Failed to refresh token")
            return False, None
    except Exception as e:
        print(f"Error refreshing token: {e}")
        return False, None


def logout(refresh_token: str) -> bool:
    """
    Logout from the system.
    
    Args:
        refresh_token: The JWT refresh token
        
    Returns:
        True if logout was successful, False otherwise
    """
    url = f"{API_URL}/auth/logout"
    payload = {
        "refreshToken": refresh_token
    }
    
    try:
        response = requests.post(url, json=payload)
        if response.status_code == 200:
            print("Logged out successfully")
            return True
        else:
            print("Failed to logout")
            return False
    except Exception as e:
        print(f"Error during logout: {e}")
        return False


def main():
    if len(sys.argv) < 3:
        print("Usage: python login_example.py <username_or_email> <password>")
        return
    
    username_or_email = sys.argv[1]
    password = sys.argv[2]
    
    # Step 1: Login
    success, login_data = login(username_or_email, password)
    
    if not success:
        print("Login failed. Exiting...")
        return
    
    # Extract tokens
    access_token = login_data.get("accessToken")
    refresh_token = login_data.get("refreshToken")
    
    if not access_token or not refresh_token:
        print("No tokens received. Exiting...")
        return
    
    # Step 2: Make an authenticated request to get the user profile
    print("\nFetching user profile...")
    profile_data = make_authenticated_request("/profile", access_token)
    if "error" not in profile_data:
        print(f"Profile fetched successfully!")
        print(f"User data: {json.dumps(profile_data, indent=2)}")
    
    # Step 3: Demonstrate token refresh
    print("\nRefreshing access token...")
    refresh_success, new_access_token = refresh_token(refresh_token)
    
    if refresh_success and new_access_token:
        print("Making a request with the new access token...")
        dashboard_data = make_authenticated_request("/dashboard", new_access_token)
        if "error" not in dashboard_data:
            print(f"Dashboard access successful: {json.dumps(dashboard_data, indent=2)}")
    
    # Step 4: Logout
    print("\nLogging out...")
    logout_success = logout(refresh_token)
    if logout_success:
        print("You have been logged out successfully!")


if __name__ == "__main__":
    main()