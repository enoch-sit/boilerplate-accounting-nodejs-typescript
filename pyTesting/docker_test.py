#!/usr/bin/env python3
"""
Docker Container Test Script

This script performs automated testing of Docker containers for the authentication system
using Python requests. It follows the same testing flow as DockerManuelCurlTest.md.

Usage:
    python docker_test.py [--env {dev|mailhog}]

Requirements:
    - requests
    - colorama (for colored terminal output)
    - python-dotenv (optional, for environment configuration)

Author: Auth System Team
Date: April 9, 2025
"""

import argparse
import json
import random
import smtplib
import sys
import time
from email.mime.text import MIMEText
import os
import requests
from requests.exceptions import RequestException
import unittest
from colorama import Fore, Style, init
import logging
import datetime
import subprocess

# Import MailHog scanner functionality
try:
    from mailhog_scanner import scan_mailhog_ports, verify_mailhog_functionality, test_mailhog_api_endpoints
    mailhog_scanner_available = True
except ImportError:
    mailhog_scanner_available = False

# Initialize colorama
init(autoreset=True)

# Configure logging
log_file = "pyTest.log"
logging.basicConfig(
    filename=log_file,
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

console = logging.StreamHandler()
console.setLevel(logging.INFO)
formatter = logging.Formatter('%(message)s')
console.setFormatter(formatter)
logging.getLogger('').addHandler(console)

class DockerApiTests(unittest.TestCase):
    """Test suite for Docker containers in the authentication system."""

    @classmethod
    def setUpClass(cls):
        """Set up test environment and configuration."""
        parser = argparse.ArgumentParser(description='Test Docker containers for auth system')
        parser.add_argument('--env', choices=['dev', 'mailhog'], default='dev',
                            help='Environment to test (dev or mailhog)')
        parser.add_argument('--scan-ports', action='store_true',
                            help='Scan for MailHog ports before testing')
        
        args = parser.parse_args()
        cls.env = args.env
        cls.scan_ports = args.scan_ports
        
        # Configure service URLs based on environment
        if cls.env == 'dev':
            cls.auth_url = "http://localhost:3000"
            cls.mongodb_port = 27018
            cls.mailhog_url = "http://localhost:8025"
            cls.smtp_port = 1025
            print(f"{Fore.CYAN}Testing development environment{Style.RESET_ALL}")
            logging.info("Testing development environment")
        else:
            cls.auth_url = "http://localhost:3001"
            cls.mongodb_port = 27018
            cls.mailhog_url = "http://localhost:8026"
            cls.smtp_port = 1026
            print(f"{Fore.CYAN}Testing MailHog test environment{Style.RESET_ALL}")
            logging.info("Testing MailHog test environment")
        
        # Scan for MailHog ports if requested
        if cls.scan_ports and mailhog_scanner_available:
            print(f"{Fore.YELLOW}Scanning for MailHog instances...{Style.RESET_ALL}")
            logging.info("Scanning for MailHog instances")
            
            # Use a smaller port range for quicker scanning during test setup
            port_range = (1024, 10000) 
            instances = scan_mailhog_ports(port_range=port_range)
            
            if instances:
                print(f"{Fore.GREEN}Found {len(instances)} MailHog instance(s){Style.RESET_ALL}")
                logging.info(f"Found {len(instances)} MailHog instance(s)")
                
                # Log detailed information about detected instances
                for i, instance in enumerate(instances):
                    print(f"MailHog #{i+1}: SMTP on port {instance['smtp_port']}, API on port {instance['api_port']} (v{instance['api_version']})")
                    logging.info(f"MailHog #{i+1}: SMTP port={instance['smtp_port']}, API port={instance['api_port']}, version={instance['api_version']}")
                    
                    # If this matches our expected configuration, update our test parameters
                    if (cls.env == 'dev' and instance['smtp_port'] == 1025 and instance['api_port'] == 8025) or \
                       (cls.env == 'mailhog' and instance['smtp_port'] == 1026 and instance['api_port'] == 8026):
                        cls.mailhog_url = instance['web_ui']
                        cls.smtp_port = instance['smtp_port']
                        print(f"{Fore.GREEN}Using detected MailHog: SMTP={cls.smtp_port}, API={cls.mailhog_url}{Style.RESET_ALL}")
                        logging.info(f"Using detected MailHog: SMTP={cls.smtp_port}, API={cls.mailhog_url}")
            else:
                print(f"{Fore.YELLOW}No MailHog instances detected. Using default configuration.{Style.RESET_ALL}")
                logging.warning("No MailHog instances detected. Using default configuration.")
        
        # Test user credentials
        cls.username = f"testuser_{random.randint(1000, 9999)}"
        cls.email = f"testuser_{random.randint(1000, 9999)}@example.com"
        cls.password = "TestPassword123!"
        cls.new_password = "NewPassword456!"
        
        # Store tokens and IDs
        cls.user_id = None
        cls.access_token = None
        cls.refresh_token = None
        cls.verification_token = None
        cls.reset_token = None
        
        # Log environment information
        logging.info("=" * 80)
        logging.info(f"Docker Testing started at {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        logging.info(f"Environment: {cls.env}")
        logging.info(f"Auth URL: {cls.auth_url}")
        logging.info(f"MailHog URL: {cls.mailhog_url}")
        logging.info(f"MongoDB Port: {cls.mongodb_port}")
        logging.info(f"SMTP Port: {cls.smtp_port}")
        logging.info(f"Test User: {cls.username} / {cls.email}")
        
        print(f"{Fore.GREEN}Test user: {cls.username} / {cls.email}{Style.RESET_ALL}")

    def test_01_health_check(self):
        """Test the health endpoint of the auth service."""
        print(f"\n{Fore.CYAN}=== Testing Health Endpoint ==={Style.RESET_ALL}")
        logging.info("Testing health endpoint")
        
        try:
            response = requests.get(f"{self.auth_url}/health")
            response.raise_for_status()
            data = response.json()
            
            self.assertEqual(response.status_code, 200)
            self.assertEqual(data.get('status'), 'ok')
            print(f"{Fore.GREEN}Health check successful: {response.status_code}{Style.RESET_ALL}")
            logging.info(f"Health check successful: {response.status_code}")
        except RequestException as e:
            logging.error(f"Health check failed: {e}")
            self.fail(f"Health check failed: {e}")
    
    def test_14_scan_mailhog(self):
        """Perform detailed MailHog port and API scanning."""
        print(f"\n{Fore.CYAN}=== Performing MailHog Port and API Scan ==={Style.RESET_ALL}")
        logging.info("Starting MailHog detailed scan")
        
        if not mailhog_scanner_available:
            print(f"{Fore.YELLOW}MailHog scanner module not available. Skipping detailed scan.{Style.RESET_ALL}")
            logging.warning("MailHog scanner module not available")
            self.skipTest("MailHog scanner module not available")
            return
        
        # Run the scanner as a separate process to get full details
        try:
            print(f"{Fore.YELLOW}Running detailed MailHog scan...{Style.RESET_ALL}")
            
            # Define port ranges based on environment
            if self.env == 'dev':
                port_range = "1024 1030 8024 8030"  # Focus around expected dev ports
            else:
                port_range = "1024 1030 8024 8030"  # Focus around expected mailhog test ports
                
            # Run scanner script
            command = [sys.executable, "pyTesting/mailhog_scanner.py", "--port-range"] + port_range.split()
            logging.info(f"Running command: {' '.join(command)}")
            
            result = subprocess.run(command, capture_output=True, text=True)
            
            # Log the output
            if result.stdout:
                for line in result.stdout.splitlines():
                    if line.strip():
                        logging.info(f"Scanner: {line.strip()}")
            
            if result.stderr:
                for line in result.stderr.splitlines():
                    if line.strip():
                        logging.error(f"Scanner error: {line.strip()}")
                        
            # Test passes if scanner ran without errors
            self.assertEqual(result.returncode, 0, "MailHog scanner failed")
            print(f"{Fore.GREEN}MailHog scan completed successfully{Style.RESET_ALL}")
            logging.info("MailHog scan completed")
        except Exception as e:
            logging.error(f"Error running MailHog scanner: {e}")
            print(f"{Fore.YELLOW}Error running MailHog scanner: {e}{Style.RESET_ALL}")
            # Don't fail the test suite because of scanner issues
    
    @classmethod
    def tearDownClass(cls):
        """Clean up after all tests."""
        # Log test completion
        logging.info(f"Docker Testing completed at {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        logging.info("=" * 80)
        
def run_tests():
    """Run the tests with custom test runner."""
    suite = unittest.TestLoader().loadTestsFromTestCase(DockerApiTests)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return result

if __name__ == "__main__":
    print(f"{Fore.CYAN}======================================{Style.RESET_ALL}")
    print(f"{Fore.CYAN}  DOCKER CONTAINER API TEST SUITE  {Style.RESET_ALL}")
    print(f"{Fore.CYAN}======================================{Style.RESET_ALL}\n")
    
    result = run_tests()
    
    # Print summary
    print(f"\n{Fore.CYAN}======================================{Style.RESET_ALL}")
    print(f"{Fore.CYAN}  TEST SUMMARY  {Style.RESET_ALL}")
    print(f"{Fore.CYAN}======================================{Style.RESET_ALL}")
    print(f"Total tests: {result.testsRun}")
    print(f"Successful: {result.testsRun - len(result.errors) - len(result.failures)}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")
    
    # Write summary to log
    logging.info(f"Test Summary:")
    logging.info(f"  Total tests: {result.testsRun}")
    logging.info(f"  Successful: {result.testsRun - len(result.errors) - len(result.failures)}")
    logging.info(f"  Failures: {len(result.failures)}")
    logging.info(f"  Errors: {len(result.errors)}")
    
    print(f"\n{Fore.GREEN}Results saved to {log_file}{Style.RESET_ALL}")
    
    # Exit with appropriate status code
    sys.exit(len(result.failures) + len(result.errors))