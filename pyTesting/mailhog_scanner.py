#!/usr/bin/env python3
"""
MailHog Port and API Scanner

This script scans for MailHog instances running on the local machine,
detecting their SMTP and API ports, and API version information.
Results are logged to pyTest.log.

Usage:
    python mailhog_scanner.py [--port-range START END]

Author: Auth System Team
Date: April 9, 2025
"""

import argparse
import datetime
import json
import logging
import socket
import sys
import time
from concurrent.futures import ThreadPoolExecutor
import requests
from requests.exceptions import RequestException
from colorama import Fore, Style, init

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

# Default MailHog ports
DEFAULT_SMTP_PORT = 1025
DEFAULT_HTTP_PORT = 8025

def check_tcp_port(host, port, timeout=1):
    """Check if a TCP port is open."""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((host, port))
        sock.close()
        return result == 0
    except:
        return False

def is_smtp_port(host, port, timeout=2):
    """Check if a port is an SMTP port by attempting to connect and receive a greeting."""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        sock.connect((host, port))
        data = sock.recv(1024)
        sock.close()
        
        # Most SMTP servers respond with a line starting with 220
        # MailHog's response should contain "MailHog" or "SMTP"
        response = data.decode('utf-8', errors='ignore')
        return "220" in response or "SMTP" in response or "MailHog" in response
    except:
        return False

def is_mailhog_api(url):
    """Check if a URL is a MailHog API endpoint."""
    try:
        # Try different API endpoints to identify MailHog
        api_paths = [
            "/api/v1/messages",
            "/api/v2/messages",
            "/api"
        ]
        
        for path in api_paths:
            try:
                response = requests.get(f"{url}{path}", timeout=2)
                if response.status_code == 200:
                    # For v2 API, the response should be JSON with an 'items' field
                    if path == "/api/v2/messages":
                        data = response.json()
                        if 'items' in data:
                            return True, "v2", path
                    # For v1 API, should also return JSON
                    elif path == "/api/v1/messages":
                        data = response.json()
                        return True, "v1", path
                    # Root API endpoint might just return different format
                    elif path == "/api":
                        return True, "unknown", path
            except:
                continue
        
        # Check for MailHog web interface
        try:
            response = requests.get(url, timeout=2)
            if "MailHog" in response.text:
                return True, "web_interface", "/"
        except:
            pass
            
        return False, None, None
    except:
        return False, None, None

def check_default_mailhog_instance(host="localhost"):
    """Check if MailHog is running on default ports."""
    print(f"{Fore.CYAN}Checking default MailHog ports on {host}...{Style.RESET_ALL}")
    logging.info(f"Checking default MailHog ports on {host}")
    
    smtp_port_open = check_tcp_port(host, DEFAULT_SMTP_PORT)
    http_port_open = check_tcp_port(host, DEFAULT_HTTP_PORT)
    
    if not smtp_port_open and not http_port_open:
        print(f"{Fore.YELLOW}No services found on default MailHog ports.{Style.RESET_ALL}")
        logging.info("No services found on default MailHog ports")
        return None
    
    instance = {}
    
    # Check SMTP port
    if smtp_port_open:
        if is_smtp_port(host, DEFAULT_SMTP_PORT):
            print(f"{Fore.GREEN}Found MailHog SMTP service on port {DEFAULT_SMTP_PORT}{Style.RESET_ALL}")
            logging.info(f"Found MailHog SMTP service on port {DEFAULT_SMTP_PORT}")
            instance["smtp_port"] = DEFAULT_SMTP_PORT
        else:
            print(f"{Fore.YELLOW}Port {DEFAULT_SMTP_PORT} is open but doesn't appear to be MailHog SMTP{Style.RESET_ALL}")
            logging.info(f"Port {DEFAULT_SMTP_PORT} is open but doesn't appear to be MailHog SMTP")
    
    # Check HTTP/API port
    if http_port_open:
        url = f"http://{host}:{DEFAULT_HTTP_PORT}"
        is_api, api_version, api_path = is_mailhog_api(url)
        
        if is_api:
            print(f"{Fore.GREEN}Found MailHog API (v{api_version}) on port {DEFAULT_HTTP_PORT}{Style.RESET_ALL}")
            logging.info(f"Found MailHog API (v{api_version}) on port {DEFAULT_HTTP_PORT}")
            instance["api_port"] = DEFAULT_HTTP_PORT
            instance["api_version"] = api_version
            instance["api_url"] = f"{url}{api_path}"
            instance["web_ui"] = url
        else:
            print(f"{Fore.YELLOW}Port {DEFAULT_HTTP_PORT} is open but doesn't appear to be MailHog API{Style.RESET_ALL}")
            logging.info(f"Port {DEFAULT_HTTP_PORT} is open but doesn't appear to be MailHog API")
    
    # Return instance if both SMTP and API are found
    if "smtp_port" in instance and "api_port" in instance:
        print(f"{Fore.GREEN}Found complete MailHog instance on default ports!{Style.RESET_ALL}")
        logging.info("Found complete MailHog instance on default ports")
        return [instance]
    elif "smtp_port" in instance or "api_port" in instance:
        print(f"{Fore.YELLOW}Found partial MailHog services on default ports{Style.RESET_ALL}")
        logging.info("Found partial MailHog services on default ports")
    
    return None

def scan_mailhog_ports(host="localhost", port_range=(1024, 10000)):
    """
    Scan for MailHog instances on the given host within the specified port range.
    Returns a list of detected MailHog configurations.
    """
    mailhog_instances = []
    smtp_ports = []
    api_ports = []
    
    # First check default ports
    default_instance = check_default_mailhog_instance(host)
    if default_instance:
        return default_instance
    
    logging.info(f"Starting MailHog port scan on {host} (port range: {port_range[0]}-{port_range[1]})")
    print(f"{Fore.CYAN}Scanning for MailHog instances on {host}...{Style.RESET_ALL}")

    # First pass: find open ports
    print(f"{Fore.YELLOW}Step 1: Scanning for open TCP ports...{Style.RESET_ALL}")
    open_ports = []
    
    with ThreadPoolExecutor(max_workers=50) as executor:
        port_futures = {executor.submit(check_tcp_port, host, port): port for port in range(port_range[0], port_range[1] + 1)}
        for future in port_futures:
            port = port_futures[future]
            try:
                if future.result():
                    open_ports.append(port)
                    print(f"  Found open port: {port}")
            except Exception as exc:
                logging.error(f"Error checking port {port}: {exc}")
    
    logging.info(f"Found {len(open_ports)} open ports")
    print(f"{Fore.GREEN}Found {len(open_ports)} open ports{Style.RESET_ALL}")
    
    # Second pass: check for SMTP ports among open ports
    print(f"{Fore.YELLOW}Step 2: Checking for SMTP servers...{Style.RESET_ALL}")
    for port in open_ports:
        if is_smtp_port(host, port):
            smtp_ports.append(port)
            print(f"{Fore.GREEN}  Found SMTP port: {port}{Style.RESET_ALL}")
            logging.info(f"Found potential MailHog SMTP port: {port}")
    
    # Third pass: check for MailHog API ports among open ports
    print(f"{Fore.YELLOW}Step 3: Checking for MailHog API endpoints...{Style.RESET_ALL}")
    for port in open_ports:
        url = f"http://{host}:{port}"
        is_api, api_version, api_path = is_mailhog_api(url)
        
        if is_api:
            api_ports.append({
                "port": port,
                "api_version": api_version,
                "api_path": api_path,
                "url": url
            })
            print(f"{Fore.GREEN}  Found MailHog API (v{api_version}): {url}{api_path}{Style.RESET_ALL}")
            logging.info(f"Found MailHog API: {url}{api_path} (version: {api_version})")
            
            # Stop scanning after finding first API port if there are also SMTP ports found
            if smtp_ports:
                print(f"{Fore.GREEN}Found API port, stopping scan...{Style.RESET_ALL}")
                logging.info("Found API port, stopping scan")
                break
    
    # Match SMTP ports with API ports to identify complete MailHog instances
    for smtp_port in smtp_ports:
        for api_info in api_ports:
            mailhog_instances.append({
                "smtp_port": smtp_port,
                "api_port": api_info["port"],
                "api_version": api_info["api_version"],
                "api_url": f"{api_info['url']}{api_info['api_path']}",
                "web_ui": api_info["url"]
            })
    
    return mailhog_instances

def verify_mailhog_functionality(instance):
    """Verify MailHog's functionality by sending a test email and checking the API."""
    verification = {
        "smtp_test": False,
        "api_test": False,
        "message_count": 0
    }
    
    # Check API first
    try:
        api_version = instance["api_version"]
        api_url = instance["api_url"]
        
        # Adjust API endpoint based on version
        if api_version == "v2":
            messages_url = api_url
        else:
            # Fall back to v1 or try to guess
            messages_url = api_url.replace("v2", "v1") if "v2" in api_url else api_url
        
        response = requests.get(messages_url)
        if response.status_code == 200:
            verification["api_test"] = True
            
            # Parse message count based on API version
            data = response.json()
            if api_version == "v2" and "items" in data:
                verification["message_count"] = len(data["items"])
            else:
                # For v1 or unknown, just count the elements if it's a list
                if isinstance(data, list):
                    verification["message_count"] = len(data)
                else:
                    verification["message_count"] = "unknown"
    except Exception as e:
        logging.error(f"API verification failed: {e}")
    
    # Send test email via SMTP
    try:
        import smtplib
        from email.mime.text import MIMEText
        
        msg = MIMEText(f"MailHog test email sent at {datetime.datetime.now()}")
        msg['Subject'] = 'MailHog Scanner Test'
        msg['From'] = 'test@example.com'
        msg['To'] = 'recipient@example.com'
        
        with smtplib.SMTP('localhost', instance["smtp_port"]) as smtp:
            smtp.send_message(msg)
            verification["smtp_test"] = True
    except Exception as e:
        logging.error(f"SMTP verification failed: {e}")
    
    # Verify email arrived (if API is working)
    if verification["api_test"] and verification["smtp_test"]:
        try:
            time.sleep(1)  # Wait for message to be processed
            response = requests.get(messages_url)
            if response.status_code == 200:
                data = response.json()
                new_count = 0
                
                if api_version == "v2" and "items" in data:
                    new_count = len(data["items"])
                elif isinstance(data, list):
                    new_count = len(data)
                
                verification["message_received"] = (
                    new_count > verification["message_count"] 
                    if isinstance(verification["message_count"], int) else True
                )
        except:
            verification["message_received"] = False
    
    return verification

def test_mailhog_api_endpoints(instance):
    """Test various MailHog API endpoints and features."""
    web_ui = instance["web_ui"]
    api_endpoints = [
        {"url": f"{web_ui}/api/v2/messages", "name": "List Messages (v2)"},
        {"url": f"{web_ui}/api/v1/messages", "name": "List Messages (v1)"},
        {"url": f"{web_ui}/api/v1/events", "name": "Events Stream"},
        {"url": f"{web_ui}/api/v2/search", "name": "Search (v2)", "params": {"kind": "to", "query": "test"}},
        {"url": f"{web_ui}/api/v1/search", "name": "Search (v1)", "params": {"kind": "to", "query": "test"}}
    ]
    
    results = []
    
    for endpoint in api_endpoints:
        try:
            params = endpoint.get("params", {})
            response = requests.get(endpoint["url"], params=params, timeout=2)
            
            results.append({
                "endpoint": endpoint["name"],
                "url": endpoint["url"],
                "status_code": response.status_code,
                "working": response.status_code == 200,
            })
        except Exception as e:
            results.append({
                "endpoint": endpoint["name"],
                "url": endpoint["url"],
                "status_code": "Error",
                "working": False,
                "error": str(e)
            })
    
    return results

def main():
    parser = argparse.ArgumentParser(description='Scan for MailHog instances on local machine')
    parser.add_argument('--port-range', nargs=2, type=int, default=[1024, 10000],
                        help='Port range to scan (default: 1024 10000)')
    parser.add_argument('--host', type=str, default='localhost',
                        help='Host to scan (default: localhost)')
    parser.add_argument('--skip-default-check', action='store_true',
                        help='Skip checking default MailHog ports')
    
    args = parser.parse_args()
    port_range = tuple(args.port_range)
    
    # Log start time and system info
    logging.info("=" * 80)
    logging.info(f"MailHog Scanner started at {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    logging.info(f"Host: {args.host}, Port range: {port_range[0]}-{port_range[1]}")
    
    # Scan for MailHog instances
    instances = scan_mailhog_ports(args.host, port_range)
    
    if not instances:
        message = "No MailHog instances detected"
        print(f"{Fore.RED}{message}{Style.RESET_ALL}")
        logging.warning(message)
        return
    
    # Log and display results
    message = f"Found {len(instances)} potential MailHog instance(s)"
    print(f"\n{Fore.GREEN}{message}{Style.RESET_ALL}")
    logging.info(message)
    
    # Test each instance
    for i, instance in enumerate(instances):
        print(f"\n{Fore.CYAN}MailHog Instance #{i+1}:{Style.RESET_ALL}")
        print(f"  SMTP Port: {instance['smtp_port']}")
        print(f"  API Port: {instance['api_port']} (Version: {instance['api_version']})")
        print(f"  Web UI: {instance['web_ui']}")
        print(f"  API URL: {instance['api_url']}")
        
        # Log instance details
        logging.info(f"MailHog Instance #{i+1}:")
        logging.info(f"  SMTP Port: {instance['smtp_port']}")
        logging.info(f"  API Port: {instance['api_port']} (Version: {instance['api_version']})")
        logging.info(f"  Web UI: {instance['web_ui']}")
        logging.info(f"  API URL: {instance['api_url']}")
        
        # Verify functionality
        print(f"\n{Fore.YELLOW}Testing MailHog functionality...{Style.RESET_ALL}")
        verification = verify_mailhog_functionality(instance)
        
        print(f"  API test: {'✅ Passed' if verification['api_test'] else '❌ Failed'}")
        print(f"  SMTP test: {'✅ Passed' if verification['smtp_test'] else '❌ Failed'}")
        
        if "message_received" in verification:
            print(f"  Message received: {'✅ Yes' if verification['message_received'] else '❌ No'}")
            
        logging.info(f"  Verification results:")
        logging.info(f"    API test: {'Passed' if verification['api_test'] else 'Failed'}")
        logging.info(f"    SMTP test: {'Passed' if verification['smtp_test'] else 'Failed'}")
        if "message_received" in verification:
            logging.info(f"    Message received: {'Yes' if verification['message_received'] else 'No'}")
        
        # Test API endpoints
        print(f"\n{Fore.YELLOW}Testing API endpoints...{Style.RESET_ALL}")
        api_tests = test_mailhog_api_endpoints(instance)
        
        for test in api_tests:
            status = "✅ Working" if test["working"] else "❌ Not working"
            print(f"  {test['endpoint']}: {status} ({test['url']})")
            logging.info(f"  API endpoint {test['endpoint']}: {'Working' if test["working"] else 'Not working'} ({test['status_code']})")
    
    # Log completion
    logging.info(f"MailHog scan completed at {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    logging.info("=" * 80)
    
    print(f"\n{Fore.GREEN}Scan complete. Results saved to {log_file}{Style.RESET_ALL}")

if __name__ == "__main__":
    main()