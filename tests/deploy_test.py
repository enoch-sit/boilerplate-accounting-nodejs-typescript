#!/usr/bin/env python3
"""
Production Deployment Testing Script for Authentication System

This script runs a series of tests against a deployed authentication system,
including real email verification flows. It allows users to manually enter
verification codes received via email for complete end-to-end testing.

Usage:
  python deploy_test.py --url https://your-api-url.com --email your-real-email@example.com

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
from getpass import getpass
from datetime import datetime


class AuthApiTester:
    def __init__(self, base_url):
        """Initialize the tester with the API base URL."""
        self.base_url = base_url.rstrip('/')
        self.access_token = None
        self.refresh_token = None
        self.user_id = None
        self.session = requests.Session()
        self.test_results = []

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
        if details and not passed:
            print(f"       Details: {details}")
        print()

    def generate_test_user(self, email=None):
        """Generate unique test user credentials."""
        unique_id = str(uuid.uuid4())[:8]
        email = email or f"test.{unique_id}@example.com"
        return {
            "username": f"testuser_{unique_id}",
            "email": email,
            "password": "TestPassword123!"
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
            return False

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

    def verify_email_with_manual_input(self):
        """Test 3: Verify email with manually entered code."""
        print("\nPlease check your email for a verification code.")
        print(f"Email should be sent to: {self.current_user['email']}")
        
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
            response = self.session.post(
                f"{self.base_url}/api/auth/refresh",
                json={"refreshToken": self.refresh_token}
            )
            
            if response.status_code == 200:
                response_data = response.json()
                old_token = self.access_token
                self.access_token = response_data.get("accessToken")
                passed = self.access_token is not None and self.access_token != old_token
                details = "New access token received" if passed else "Token refresh failed"
            else:
                passed = False
                details = f"Status code: {response.status_code}, Response: {response.text}"
                
            self.log_result("Refresh Token", passed, details)
            return passed
        except Exception as e:
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
        print("\nPlease check your email for a password reset link/token.")
        print(f"Email should be sent to: {self.current_user['email']}")
        
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
            
        if not self.verify_email_with_manual_input():
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
        
        self.generate_report()
        return True


def main():
    parser = argparse.ArgumentParser(description='Test deployment of the authentication API')
    parser.add_argument('--url', required=True, help='Base URL of the deployed API')
    parser.add_argument('--email', help='Email to use for testing (real email recommended for verification)')
    
    args = parser.parse_args()
    
    tester = AuthApiTester(args.url)
    tester.run_auth_flow_test(user_email=args.email)


if __name__ == "__main__":
    main()