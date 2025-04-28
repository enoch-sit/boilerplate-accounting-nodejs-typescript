#!/usr/bin/env python3
"""
JWT_verification.py - Verify JWT tokens in development and production environments

This script allows you to verify the JWT tokens used in the simple-accounting
authentication system. It can decode tokens, verify their signatures, and
check if they are valid for the current environment.

Usage:
    python JWT_verification.py verify --token <jwt_token> --env [dev|prod]
    python JWT_verification.py check-env --env [dev|prod]
    python JWT_verification.py extract --docker-container <container_name>

Example:
    python JWT_verification.py verify --token eyJhbGciOi... --env dev
    python JWT_verification.py check-env --env prod
    python JWT_verification.py extract --docker-container auth-service-dev
"""

import argparse
import base64
import json
import os
import re
import sys
import subprocess
from datetime import datetime
import hmac
import hashlib
import requests

# Default secrets for development environment
DEFAULT_ACCESS_SECRET = "dev_access_secret_key_change_this_in_production"
DEFAULT_REFRESH_SECRET = "dev_refresh_secret_key_change_this_in_production"

# API URLs
DEV_API_URL = "http://localhost:3000/api"
PROD_API_URL = None  # Set this to your production API URL


def parse_arguments():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="JWT token verification tool")
    subparsers = parser.add_subparsers(dest="command", help="Command to execute")

    # Verify command
    verify_parser = subparsers.add_parser("verify", help="Verify a JWT token")
    verify_parser.add_argument("--token", required=True, help="JWT token to verify")
    verify_parser.add_argument(
        "--env", choices=["dev", "prod"], default="dev", help="Environment (dev or prod)"
    )
    verify_parser.add_argument(
        "--type", choices=["access", "refresh"], help="Token type (access or refresh)"
    )
    verify_parser.add_argument(
        "--secret", help="Override the JWT secret for verification"
    )

    # Check environment command
    check_parser = subparsers.add_parser(
        "check-env", help="Check JWT secrets in environment"
    )
    check_parser.add_argument(
        "--env", choices=["dev", "prod"], required=True, help="Environment to check"
    )

    # Extract from Docker command
    extract_parser = subparsers.add_parser(
        "extract", help="Extract JWT secrets from Docker container"
    )
    extract_parser.add_argument(
        "--docker-container",
        required=True,
        help="Name of the Docker container to extract from",
    )

    # Health check command
    health_parser = subparsers.add_parser(
        "health", help="Check if the authentication service is running"
    )
    health_parser.add_argument(
        "--env", choices=["dev", "prod"], default="dev", help="Environment to check"
    )
    health_parser.add_argument("--url", help="Override the API URL for the health check")

    return parser.parse_args()


def decode_jwt_payload(token):
    """Decode the payload part of a JWT token without verification."""
    try:
        # Split the token into header, payload, and signature
        parts = token.split(".")
        if len(parts) != 3:
            print("Error: Invalid JWT token format")
            return None

        # Decode the payload
        payload_b64 = parts[1]
        # Make sure the padding is correct for base64 decoding
        payload_b64 += "=" * ((4 - len(payload_b64) % 4) % 4)
        payload_bytes = base64.urlsafe_b64decode(payload_b64)
        payload = json.loads(payload_bytes)
        return payload

    except Exception as e:
        print(f"Error decoding token: {e}")
        return None


def verify_jwt_signature(token, secret, token_type=None):
    """Verify the JWT signature using the provided secret."""
    try:
        # Split the token into header, payload, and signature
        parts = token.split(".")
        if len(parts) != 3:
            return False, "Invalid JWT token format"

        # Join the header and payload with a period
        message = f"{parts[0]}.{parts[1]}"
        
        # Decode the signature
        signature_b64 = parts[2]
        # Make sure the padding is correct for base64 decoding
        signature_b64 += "=" * ((4 - len(signature_b64) % 4) % 4)
        signature = base64.urlsafe_b64decode(signature_b64)
        
        # Decode the header to get the algorithm
        header_b64 = parts[0]
        header_b64 += "=" * ((4 - len(header_b64) % 4) % 4)
        header_bytes = base64.urlsafe_b64decode(header_b64)
        header = json.loads(header_bytes)
        
        # Check the algorithm
        algorithm = header.get("alg")
        if algorithm != "HS256":
            return False, f"Unsupported algorithm: {algorithm}"
        
        # Verify the signature
        key = bytes(secret, "utf-8")
        expected_signature = hmac.new(key, message.encode("utf-8"), hashlib.sha256).digest()
        
        if not hmac.compare_digest(signature, expected_signature):
            return False, "Signature verification failed"
        
        # If token_type is specified, verify that the token is of the correct type
        if token_type:
            payload = decode_jwt_payload(token)
            if payload and payload.get("type") != token_type:
                return False, f"Token is not a {token_type} token"
        
        return True, "Signature verified successfully"
    
    except Exception as e:
        return False, f"Error verifying signature: {e}"


def check_token_expiration(payload):
    """Check if the token has expired based on the 'exp' claim."""
    if "exp" not in payload:
        return False, "No expiration claim (exp) in token"
    
    exp_time = datetime.fromtimestamp(payload["exp"])
    now = datetime.now()
    
    if now > exp_time:
        time_diff = now - exp_time
        return False, f"Token expired on {exp_time} ({time_diff} ago)"
    else:
        time_left = exp_time - now
        return True, f"Token valid until {exp_time} ({time_left} remaining)"


def get_appropriate_secret(env, token_type, override_secret=None):
    """Get the appropriate secret for the specified environment and token type."""
    if override_secret:
        return override_secret
    
    if env == "dev":
        if token_type == "refresh":
            return DEFAULT_REFRESH_SECRET
        else:  # Default to access token
            return DEFAULT_ACCESS_SECRET
    elif env == "prod":
        # In production, we should get secrets from environment variables
        # or other secure sources
        if token_type == "refresh":
            return os.environ.get("PROD_JWT_REFRESH_SECRET")
        else:  # Default to access token
            return os.environ.get("PROD_JWT_ACCESS_SECRET")
    
    return None


def check_environment_secrets(env):
    """Check if JWT secrets are properly set in the environment."""
    print(f"\n=== Checking JWT Secrets for {env.upper()} Environment ===\n")
    
    if env == "dev":
        # For dev, we just verify against the default secrets
        print(f"Access token secret (expected): {DEFAULT_ACCESS_SECRET}")
        print(f"Refresh token secret (expected): {DEFAULT_REFRESH_SECRET}")
        
        # Try to get values from docker-compose file
        try:
            with open("../docker-compose.dev.yml", "r") as f:
                compose_content = f.read()
                
                access_match = re.search(r"JWT_ACCESS_SECRET=([^\n]+)", compose_content)
                refresh_match = re.search(r"JWT_REFRESH_SECRET=([^\n]+)", compose_content)
                
                if access_match:
                    actual_access = access_match.group(1)
                    if actual_access == DEFAULT_ACCESS_SECRET:
                        print("✅ Access token secret in docker-compose.dev.yml matches default")
                    else:
                        print(f"⚠️ Access token secret in docker-compose.dev.yml is different: {actual_access}")
                else:
                    print("❌ Could not find JWT_ACCESS_SECRET in docker-compose.dev.yml")
                
                if refresh_match:
                    actual_refresh = refresh_match.group(1)
                    if actual_refresh == DEFAULT_REFRESH_SECRET:
                        print("✅ Refresh token secret in docker-compose.dev.yml matches default")
                    else:
                        print(f"⚠️ Refresh token secret in docker-compose.dev.yml is different: {actual_refresh}")
                else:
                    print("❌ Could not find JWT_REFRESH_SECRET in docker-compose.dev.yml")
        
        except FileNotFoundError:
            print("⚠️ Could not find docker-compose.dev.yml file")
        
        # Check if the actual running container has the expected values
        print("\nChecking running Docker container (if available):")
        try:
            result = subprocess.run(
                ["docker", "exec", "auth-service-dev", "printenv"],
                capture_output=True,
                text=True,
                check=False
            )
            
            if result.returncode == 0:
                env_vars = result.stdout.splitlines()
                access_var = next((var for var in env_vars if var.startswith("JWT_ACCESS_SECRET=")), None)
                refresh_var = next((var for var in env_vars if var.startswith("JWT_REFRESH_SECRET=")), None)
                
                if access_var:
                    actual_access = access_var.split("=", 1)[1]
                    if actual_access == DEFAULT_ACCESS_SECRET:
                        print("✅ JWT_ACCESS_SECRET in container matches default")
                    else:
                        print(f"⚠️ JWT_ACCESS_SECRET in container is different: {actual_access}")
                else:
                    print("❌ JWT_ACCESS_SECRET not found in container environment")
                
                if refresh_var:
                    actual_refresh = refresh_var.split("=", 1)[1]
                    if actual_refresh == DEFAULT_REFRESH_SECRET:
                        print("✅ JWT_REFRESH_SECRET in container matches default")
                    else:
                        print(f"⚠️ JWT_REFRESH_SECRET in container is different: {actual_refresh}")
                else:
                    print("❌ JWT_REFRESH_SECRET not found in container environment")
            else:
                print("⚠️ Could not check Docker container (not running or permission denied)")
                print(f"Error: {result.stderr}")
        
        except Exception as e:
            print(f"⚠️ Error checking Docker container: {e}")
    
    elif env == "prod":
        # For prod, we check for environment variables
        access_secret = os.environ.get("PROD_JWT_ACCESS_SECRET")
        refresh_secret = os.environ.get("PROD_JWT_REFRESH_SECRET")
        
        if access_secret:
            masked_access = access_secret[:3] + "***" + access_secret[-3:] if len(access_secret) > 6 else "***"
            print(f"✅ PROD_JWT_ACCESS_SECRET is set in environment variables: {masked_access}")
        else:
            print("❌ PROD_JWT_ACCESS_SECRET is not set in environment variables")
        
        if refresh_secret:
            masked_refresh = refresh_secret[:3] + "***" + refresh_secret[-3:] if len(refresh_secret) > 6 else "***"
            print(f"✅ PROD_JWT_REFRESH_SECRET is set in environment variables: {masked_refresh}")
        else:
            print("❌ PROD_JWT_REFRESH_SECRET is not set in environment variables")
    
    print("\nNote: For production use, ensure your secrets are:")
    print("  1. Complex and unique")
    print("  2. Not stored in source code")
    print("  3. Different from development secrets")
    print("  4. At least 32 characters long\n")


def extract_from_docker(container_name):
    """Extract JWT secrets from a Docker container."""
    print(f"\n=== Extracting JWT Secrets from Docker Container: {container_name} ===\n")
    
    try:
        result = subprocess.run(
            ["docker", "exec", container_name, "printenv"],
            capture_output=True,
            text=True,
            check=True
        )
        
        env_vars = result.stdout.splitlines()
        
        # Filter for JWT-related environment variables
        jwt_vars = [var for var in env_vars if "JWT" in var]
        
        if jwt_vars:
            print("Found JWT-related environment variables:")
            for var in jwt_vars:
                print(f"  {var}")
        else:
            print("No JWT-related environment variables found in the container")
        
        # Look for other potentially useful variables
        other_vars = [
            var for var in env_vars 
            if any(key in var for key in ["SECRET", "TOKEN", "AUTH", "KEY"])
            and "JWT" not in var
        ]
        
        if other_vars:
            print("\nOther potentially relevant environment variables:")
            for var in other_vars:
                print(f"  {var}")
    
    except subprocess.CalledProcessError as e:
        print(f"Error executing command: {e}")
        print(f"Error output: {e.stderr}")
    except Exception as e:
        print(f"Error: {e}")


def verify_token(token, env, token_type=None, override_secret=None):
    """Verify a JWT token and print its contents."""
    print(f"\n=== Verifying JWT Token in {env.upper()} Environment ===\n")
    
    # Step 1: Decode the payload without verification
    payload = decode_jwt_payload(token)
    if not payload:
        print("❌ Failed to decode token payload")
        return
    
    # Determine token type from payload if not specified
    if not token_type and "type" in payload:
        token_type = payload["type"]
        print(f"Token type detected from payload: {token_type}")
    elif not token_type:
        print("⚠️ Token type not specified and not found in payload")
        print("Assuming this is an access token for verification purposes")
        token_type = "access"
    
    # Step 2: Get the appropriate secret
    secret = get_appropriate_secret(env, token_type, override_secret)
    if not secret:
        print(f"❌ Could not determine appropriate secret for {env} environment, {token_type} token")
        print("Please provide a secret using --secret or set the appropriate environment variable")
        return
    
    # Step 3: Verify the signature
    is_valid, signature_message = verify_jwt_signature(token, secret, token_type)
    if is_valid:
        print(f"✅ {signature_message}")
    else:
        print(f"❌ {signature_message}")
    
    # Step 4: Check expiration
    is_valid_exp, exp_message = check_token_expiration(payload)
    if is_valid_exp:
        print(f"✅ {exp_message}")
    else:
        print(f"❌ {exp_message}")
    
    # Step 5: Print decoded payload
    print("\nDecoded Token Payload:")
    print(json.dumps(payload, indent=2))
    
    # Step 6: Additional token information
    print("\nAdditional Information:")
    if "sub" in payload:
        print(f"User ID (sub): {payload['sub']}")
    if "username" in payload:
        print(f"Username: {payload['username']}")
    if "email" in payload:
        print(f"Email: {payload['email']}")
    if "role" in payload:
        print(f"Role: {payload['role']}")
    
    # Overall validity
    if is_valid and is_valid_exp:
        print("\n✅ Token is VALID")
    else:
        print("\n❌ Token is INVALID")


def check_health(env, override_url=None):
    """Check if the authentication service is running."""
    print(f"\n=== Checking Authentication Service Health ({env.upper()}) ===\n")
    
    api_url = override_url
    if not api_url:
        if env == "dev":
            api_url = DEV_API_URL
        else:  # prod
            if PROD_API_URL:
                api_url = PROD_API_URL
            else:
                print("❌ Production API URL not configured")
                print("Please set PROD_API_URL in the script or provide --url parameter")
                return
    
    # Check /health endpoint
    health_url = f"{api_url}/health"
    print(f"Checking health endpoint: {health_url}")
    
    try:
        response = requests.get(health_url, timeout=5)
        if response.status_code == 200:
            print(f"✅ Service is healthy (Status: {response.status_code})")
            try:
                print(json.dumps(response.json(), indent=2))
            except:
                print(f"Response: {response.text}")
        else:
            print(f"❌ Service returned non-200 status code: {response.status_code}")
            print(f"Response: {response.text}")
    except requests.exceptions.ConnectionError:
        print("❌ Connection error - service may not be running")
    except requests.exceptions.Timeout:
        print("❌ Request timed out - service may be overloaded")
    except Exception as e:
        print(f"❌ Error checking service health: {e}")
    
    # Check if Docker container is running
    if env == "dev":
        print("\nChecking if Docker container is running:")
        try:
            result = subprocess.run(
                ["docker", "ps", "--filter", "name=auth-service-dev", "--format", "{{.Names}} {{.Status}}"],
                capture_output=True,
                text=True,
                check=False
            )
            
            if "auth-service-dev" in result.stdout:
                print(f"✅ Docker container is running: {result.stdout.strip()}")
            else:
                print("❌ Docker container 'auth-service-dev' is not running")
        except Exception as e:
            print(f"⚠️ Error checking Docker container: {e}")


def main():
    """Main function."""
    args = parse_arguments()
    
    if args.command == "verify":
        verify_token(args.token, args.env, args.type, args.secret)
    elif args.command == "check-env":
        check_environment_secrets(args.env)
    elif args.command == "extract":
        extract_from_docker(args.docker_container)
    elif args.command == "health":
        check_health(args.env, args.url)
    else:
        print("No command specified. Use -h or --help for usage information.")


if __name__ == "__main__":
    main()