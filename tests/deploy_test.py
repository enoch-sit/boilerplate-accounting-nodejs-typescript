#!/usr/bin/env python3
"""
Production Deployment Testing Script for Authentication System

This script runs a series of tests against a deployed authentication system,
including real email verification flows. It allows users to manually enter
verification codes received via email for complete end-to-end testing.

Usage:
  python deploy_test.py                                    # Uses default Docker service URL
  python deploy_test.py --url http://localhost:3000        # Tests local deployment
  python deploy_test.py --email your-real-email@example.com # Uses real email for verification
  python deploy_test.py --mailhog-url http://localhost:8025 # Specifies custom MailHog URL
  python deploy_test.py --admin-test true                  # Tests admin user creation API

Requirements:
  - Python 3.6+
  - requests library (pip install requests)
"""

import argparse
import json
import re
import requests
import time
import uuid
import sys
import socket
from getpass import getpass
from datetime import datetime


def is_docker_available(host="auth-service", port=3000, timeout=1):
    """Check if Docker service is available."""
    try:
        socket.create_connection((host, port), timeout)
        return True
    except (socket.timeout, socket.error):
        return False


def get_default_url():
    """Determine the default API URL based on environment."""
    # Check if running in Docker environment first
    if is_docker_available("auth-service", 3000):
        return "http://auth-service:3000"
    # Otherwise use localhost
    return "http://localhost:3000"


class AuthApiTester:
    def __init__(self, base_url, mailhog_url=None):
        """Initialize the tester with the API base URL."""
        self.base_url = base_url.rstrip('/')
        self.mailhog_url = mailhog_url
        self.access_token = None
        self.refresh_token = None
        self.admin_token = None  # For admin tests
        self.user_id = None
        self.session = requests.Session()
        self.test_results = []
        
        # Print connection information
        print(f"Testing against API URL: {self.base_url}")
        if self.mailhog_url:
            print(f"MailHog URL configured: {self.mailhog_url}")

    def log_result(self, test_name, passed, details=None):
        """Log a test result."""
        result = {
            "test": test_name,
            "passed": passed,
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }
        if details:
            result["details"] = details
        
        self.test_results.append(result)
        
        status = "PASS" if passed else "FAIL"
        print(f"[{status}] {test_name}")
        if details:
            if not passed:
                print(f"       Details: {details}")
            elif "User ID" in details or "Created user" in details:  # Always show created user IDs
                print(f"       {details}")
        print()

    def generate_test_user(self, email=None, role="user"):
        """Generate unique test user credentials."""
        unique_id = str(uuid.uuid4())[:8]
        email = email or f"test.{unique_id}@example.com"
        return {
            "username": f"testuser_{unique_id}",
            "email": email,
            "password": "TestPassword123!",
            "role": role
        }

    def health_check(self):
        """Test 1: Check if the API is up and running."""
        try:
            response = self.session.get(f"{self.base_url}/health")
            passed = response.status_code == 200
            self.log_result("Health Check", passed, 
                            details=None if passed else f"Status code: {response.status_code}")
            return passed
        except Exception as e:
            self.log_result("Health Check", False, details=str(e))
            print("Troubleshooting tips:")
            print("1. Check if the service is running")
            print("2. Verify the API URL is correct")
            print("3. Check if there's a network connectivity issue")
            return False

    def try_fetch_verification_from_mailhog(self, email):
        """Try to fetch verification code from MailHog."""
        if not self.mailhog_url:
            return None
            
        try:
            print(f"Attempting to fetch verification code from MailHog for {email}...")
            response = requests.get(f"{self.mailhog_url}/api/v2/search?kind=to&query={email}")
            
            if response.status_code != 200:
                print(f"MailHog API returned status code {response.status_code}")
                return None
                
            data = response.json()
            if not data.get("items"):
                print("No emails found in MailHog")
                return None
                
            # Get the most recent email
            email_content = data["items"][0]["Content"]["Body"]
            
            # Try to extract verification code using regex
            # Pattern looks for a verification code or token which is typically a 
            # sequence of letters, numbers, and possibly some special characters
            pattern = r"verification code[:\s]+([A-Za-z0-9\-_]{6,})"
            match = re.search(pattern, email_content, re.IGNORECASE)
            
            if match:
                verification_code = match.group(1)
                print(f"Verification code found: {verification_code}")
                return verification_code
                
            pattern = r"token[:\s]+([A-Za-z0-9\-_]{6,})"
            match = re.search(pattern, email_content, re.IGNORECASE)
            
            if match:
                verification_code = match.group(1)
                print(f"Verification token found: {verification_code}")
                return verification_code
                
            print("Couldn't find verification code in email content.")
            return None
            
        except Exception as e:
            print(f"Error accessing MailHog: {e}")
            return None

    def signup_user(self, user_data):
        """Test 2: Register a new user."""
        print(f"Signing up with username: {user_data['username']}, email: {user_data['email']}")
        
        try:
            response = self.session.post(
                f"{self.base_url}/api/auth/signup", 
                json=user_data
            )
            
            if response.status_code == 201:
                response_data = response.json()
                self.user_id = response_data.get("userId")
                passed = self.user_id is not None
                details = f"User ID: {self.user_id}" if passed else "No user ID in response"
            else:
                passed = False
                details = f"Status code: {response.status_code}, Response: {response.text}"
                
            self.log_result("User Sign Up", passed, details)
            return passed
        except Exception as e:
            self.log_result("User Sign Up", False, details=str(e))
            return False

    def verify_email(self):
        """Test 3: Verify email through MailHog or manual input."""
        # First try to get verification code from MailHog if configured
        verification_code = None
        if self.mailhog_url:
            verification_code = self.try_fetch_verification_from_mailhog(self.current_user['email'])
        
        # If MailHog didn't work or isn't configured, ask for manual input
        if not verification_code:
            print("\nPlease check your email for a verification code.")
            print(f"Email should be sent to: {self.current_user['email']}")
            print("Note: If using MailHog, check the web interface at http://localhost:8025")
            
            verification_code = input("\nEnter the verification code from the email: ").strip()
        
        if not verification_code:
            self.log_result("Email Verification", False, "No verification code provided")
            return False
            
        try:
            response = self.session.post(
                f"{self.base_url}/api/auth/verify-email", 
                json={"token": verification_code}
            )
            
            passed = response.status_code == 200
            details = f"Status code: {response.status_code}, Response: {response.text}"
            self.log_result("Email Verification", passed, details)
            return passed
        except Exception as e:
            self.log_result("Email Verification", False, details=str(e))
            return False

    def login_user(self):
        """Test 4: Login with the registered user."""
        try:
            response = self.session.post(
                f"{self.base_url}/api/auth/login", 
                json={
                    "username": self.current_user["username"],
                    "password": self.current_user["password"]
                }
            )
            
            if response.status_code == 200:
                response_data = response.json()
                self.access_token = response_data.get("accessToken")
                self.refresh_token = response_data.get("refreshToken")
                passed = self.access_token is not None and self.refresh_token is not None
                details = "Tokens received" if passed else "Missing tokens in response"
            else:
                passed = False
                details = f"Status code: {response.status_code}, Response: {response.text}"
                
            self.log_result("User Login", passed, details)
            return passed
        except Exception as e:
            self.log_result("User Login", False, details=str(e))
            return False

    def admin_login(self):
        """Login as an admin user."""
        try:
            # First try with default admin credentials
            admin_creds = {
                "username": "admin",
                "password": "AdminPassword123!"
            }
            
            print(f"Attempting to login with admin user: {admin_creds['username']}")
            
            response = self.session.post(
                f"{self.base_url}/api/auth/login", 
                json=admin_creds
            )
            
            if response.status_code == 200:
                response_data = response.json()
                self.admin_token = response_data.get("accessToken")
                passed = self.admin_token is not None
                details = "Admin login successful" if passed else "Missing admin token"
            else:
                # If default failed, ask for admin credentials
                print("\nDefault admin login failed. Please provide admin credentials:")
                admin_username = input("Admin username: ")
                admin_password = getpass("Admin password: ")
                
                response = self.session.post(
                    f"{self.base_url}/api/auth/login", 
                    json={
                        "username": admin_username,
                        "password": admin_password
                    }
                )
                
                if response.status_code == 200:
                    response_data = response.json()
                    self.admin_token = response_data.get("accessToken")
                    passed = self.admin_token is not None
                    details = "Admin login successful" if passed else "Missing admin token"
                else:
                    passed = False
                    details = f"Status code: {response.status_code}, Response: {response.text}"
            
            self.log_result("Admin Login", passed, details)
            return passed
        except Exception as e:
            self.log_result("Admin Login", False, details=str(e))
            return False

    def admin_create_user(self, role="user"):
        """Test admin user creation API."""
        if not self.admin_token:
            self.log_result("Admin Create User", False, "No admin token available")
            return False
        
        new_user = self.generate_test_user(role=role)
        
        try:
            response = self.session.post(
                f"{self.base_url}/api/admin/users",
                headers={"Authorization": f"Bearer {self.admin_token}"},
                json={
                    "username": new_user["username"],
                    "email": new_user["email"],
                    "password": new_user["password"],
                    "role": role,
                    "skipVerification": True
                }
            )
            
            if response.status_code in [200, 201]:
                response_data = response.json()
                created_user_id = response_data.get("userId") or response_data.get("id")
                passed = created_user_id is not None
                details = f"Created user with role '{role}', ID: {created_user_id}" if passed else "No user ID in response"
            else:
                passed = False
                details = f"Status code: {response.status_code}, Response: {response.text}"
                
            self.log_result(f"Admin Create {role.capitalize()} User", passed, details)
            return passed
        except Exception as e:
            self.log_result(f"Admin Create {role.capitalize()} User", False, details=str(e))
            return False

    def list_users_as_admin(self):
        """List all users as admin."""
        if not self.admin_token:
            self.log_result("List Users", False, "No admin token available")
            return False
            
        try:
            response = self.session.get(
                f"{self.base_url}/api/admin/users",
                headers={"Authorization": f"Bearer {self.admin_token}"}
            )
            
            passed = response.status_code == 200
            
            if passed:
                users = response.json().get("users", [])
                details = f"Found {len(users)} users"
                print("\nUsers in system:")
                for user in users[:5]:  # Show limited number to avoid clutter
                    print(f"- {user.get('username')} ({user.get('email')}): {user.get('role')}")
                if len(users) > 5:
                    print(f"...and {len(users) - 5} more users")
            else:
                details = f"Status code: {response.status_code}, Response: {response.text}"
                
            self.log_result("List Users", passed, details)
            return passed
        except Exception as e:
            self.log_result("List Users", False, details=str(e))
            return False

    def access_protected_route(self):
        """Test 5: Access a protected route with the access token."""
        if not self.access_token:
            self.log_result("Access Protected Route", False, "No access token available")
            return False
            
        try:
            response = self.session.get(
                f"{self.base_url}/api/profile",
                headers={"Authorization": f"Bearer {self.access_token}"}
            )
            
            passed = response.status_code == 200
            details = f"Status code: {response.status_code}, Response: {response.text[:100]+'...' if len(response.text) > 100 else response.text}"
            self.log_result("Access Protected Route", passed, details)
            return passed
        except Exception as e:
            self.log_result("Access Protected Route", False, details=str(e))
            return False

    def refresh_token_test(self):
        """Test 6: Refresh the access token using the refresh token."""
        if not self.refresh_token:
            self.log_result("Refresh Token", False, "No refresh token available")
            return False
            
        try:
            # Make sure we're using the correct endpoint
            endpoint = f"{self.base_url}/api/auth/refresh"
            print(f"DEBUG: Sending refresh token request to: {endpoint}")
            print(f"DEBUG: Using refresh token: {self.refresh_token[:20]}...")
            
            # Add detailed debugging information
            import json
            debug_request_data = {"refreshToken": self.refresh_token}
            print(f"DEBUG: Full request body: {json.dumps(debug_request_data)}")
            
            # Make sure headers are correct
            headers = {
                "Content-Type": "application/json",
                "Accept": "application/json"
            }
            print(f"DEBUG: Request headers: {headers}")
            
            response = self.session.post(
                endpoint,
                json=debug_request_data,
                headers=headers
            )
            
            print(f"DEBUG: Response status code: {response.status_code}")
            print(f"DEBUG: Response body: {response.text}")
            
            if response.status_code == 200:
                response_data = response.json()
                old_token = self.access_token
                self.access_token = response_data.get("accessToken")
                
                # Check if we got a new access token
                if self.access_token:
                    passed = True
                    details = f"New access token received: {self.access_token[:15]}..."
                    print(f"DEBUG: Successfully refreshed token. Old: {old_token[:10]}... New: {self.access_token[:10]}...")
                else:
                    passed = False
                    details = "Response was 200 but no accessToken in the response body"
            else:
                passed = False
                details = f"Status code: {response.status_code}, Response: {response.text}"
                
            self.log_result("Refresh Token", passed, details)
            return passed
        except Exception as e:
            print(f"DEBUG: Exception during token refresh: {str(e)}")
            import traceback
            print(f"DEBUG: Stack trace: {traceback.format_exc()}")
            self.log_result("Refresh Token", False, details=str(e))
            return False

    def request_password_reset(self):
        """Test 7: Request a password reset."""
        try:
            response = self.session.post(
                f"{self.base_url}/api/auth/forgot-password",
                json={"email": self.current_user["email"]}
            )
            
            passed = response.status_code == 200
            details = f"Status code: {response.status_code}, Response: {response.text}"
            self.log_result("Request Password Reset", passed, details)
            return passed
        except Exception as e:
            self.log_result("Request Password Reset", False, details=str(e))
            return False

    def reset_password_with_manual_input(self):
        """Test 8: Reset password with manually entered token."""
        # First try to get reset token from MailHog if configured
        reset_token = None
        if self.mailhog_url:
            reset_token = self.try_fetch_verification_from_mailhog(self.current_user['email'])
        
        # If MailHog didn't work or isn't configured, ask for manual input
        if not reset_token:
            print("\nPlease check your email for a password reset link/token.")
            print(f"Email should be sent to: {self.current_user['email']}")
            print("Note: If using MailHog, check the web interface at http://localhost:8025")
            
            reset_token = input("\nEnter the reset token from the email: ").strip()
        
        if not reset_token:
            self.log_result("Password Reset", False, "No reset token provided")
            return False
            
        # New password for the user
        new_password = "NewPassword123!"
        
        try:
            response = self.session.post(
                f"{self.base_url}/api/auth/reset-password",
                json={
                    "token": reset_token,
                    "newPassword": new_password
                }
            )
            
            passed = response.status_code == 200
            details = f"Status code: {response.status_code}, Response: {response.text}"
            
            if passed:
                # Update the password in our user object
                self.current_user["password"] = new_password
                
            self.log_result("Password Reset", passed, details)
            return passed
        except Exception as e:
            self.log_result("Password Reset", False, details=str(e))
            return False

    def login_after_reset(self):
        """Test 9: Login with the new password after reset."""
        return self.login_user()

    def logout_user(self):
        """Test 10: Logout the user."""
        if not self.refresh_token:
            self.log_result("User Logout", False, "No refresh token available")
            return False
            
        try:
            response = self.session.post(
                f"{self.base_url}/api/auth/logout",
                json={"refreshToken": self.refresh_token}
            )
            
            passed = response.status_code == 200
            details = f"Status code: {response.status_code}, Response: {response.text}"
            
            if passed:
                # Clear tokens
                self.access_token = None
                self.refresh_token = None
                
            self.log_result("User Logout", passed, details)
            return passed
        except Exception as e:
            self.log_result("User Logout", False, details=str(e))
            return False

    def run_admin_tests(self):
        """Run tests for admin user creation API."""
        print("\n" + "=" * 50)
        print("RUNNING ADMIN API TESTS")
        print("=" * 50)
        
        if not self.admin_login():
            print("Admin login failed. Skipping admin tests.")
            return False
        
        self.admin_create_user(role="user")
        self.admin_create_user(role="supervisor")
        self.list_users_as_admin()
        
        return True

    def generate_report(self):
        """Generate a test report."""
        passed_tests = sum(1 for result in self.test_results if result["passed"])
        total_tests = len(self.test_results)
        pass_rate = (passed_tests / total_tests) * 100 if total_tests > 0 else 0
        
        print("\n" + "=" * 50)
        print("DEPLOYMENT TEST REPORT")
        print("=" * 50)
        print(f"API URL: {self.base_url}")
        print(f"Tests Passed: {passed_tests}/{total_tests} ({pass_rate:.1f}%)")
        print(f"Date/Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("-" * 50)
        
        for i, result in enumerate(self.test_results, 1):
            status = "PASS" if result["passed"] else "FAIL"
            print(f"{i}. [{status}] {result['test']}")
            
        print("=" * 50)
        
        # Save report to file
        filename = f"deploy_test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(filename, "w") as f:
            json.dump({
                "api_url": self.base_url,
                "test_date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                "passed": passed_tests,
                "total": total_tests,
                "pass_rate": pass_rate,
                "results": self.test_results
            }, f, indent=2)
            
        print(f"Report saved to {filename}")

    def run_auth_flow_test(self, user_email=None):
        """Run a complete authentication flow test."""
        print("\n" + "=" * 50)
        print("RUNNING DEPLOYMENT TEST SUITE")
        print("=" * 50)
        
        # Generate test user data
        self.current_user = self.generate_test_user(email=user_email)
        
        # Run tests in sequence, stopping if critical tests fail
        if not self.health_check():
            print("API health check failed. Aborting tests.")
            return False
            
        if not self.signup_user(self.current_user):
            print("User signup failed. Aborting tests.")
            return False
            
        if not self.verify_email():
            print("Email verification failed. Aborting tests.")
            return False
            
        if not self.login_user():
            print("User login failed. Aborting tests.")
            return False
            
        self.access_protected_route()
        self.refresh_token_test()
        
        # Ask if user wants to test password reset flow
        test_password_reset = input("\nDo you want to test password reset flow? (y/n): ").lower().strip() == 'y'
        
        if test_password_reset:
            if self.request_password_reset():
                self.reset_password_with_manual_input()
                self.login_after_reset()
        
        self.logout_user()
        
        return True


def main():
    parser = argparse.ArgumentParser(description='Test deployment of the authentication API')
    parser.add_argument('--url', help='Base URL of the deployed API')
    parser.add_argument('--email', help='Email to use for testing (real email recommended for verification)')
    parser.add_argument('--mailhog-url', help='URL of MailHog for automatic email verification testing')
    parser.add_argument('--admin-test', help='Run admin user creation API tests', choices=['true', 'false'])
    
    args = parser.parse_args()
    
    # Determine the URL to use
    base_url = args.url or get_default_url()
    
    # Set default MailHog URL if not specified
    mailhog_url = args.mailhog_url
    if not mailhog_url and "localhost" in base_url:
        mailhog_url = "http://localhost:8025"
    elif not mailhog_url and "auth-service" in base_url:
        mailhog_url = "http://mailhog:8025"
    
    # Create the tester
    tester = AuthApiTester(base_url, mailhog_url)
    
    # Run authentication flow tests
    auth_flow_passed = tester.run_auth_flow_test(user_email=args.email)
    
    # Run admin tests if requested
    if args.admin_test and args.admin_test.lower() == 'true':
        tester.run_admin_tests()
    
    # Generate final report
    tester.generate_report()
    
    # Return success status for script exit code
    return auth_flow_passed


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)