#!/bin/bash

echo "==================================================="
echo "Simple Accounting Deployment Test Runner"
echo "==================================================="

# Check if conda is installed
if ! command -v conda &> /dev/null; then
    echo "Conda is not installed or not in PATH. Please run ./install.sh first."
    exit 1
fi

# Check if simple_auth_test environment exists
if ! conda env list | grep -q "simple_auth_test"; then
    echo "Environment 'simple_auth_test' does not exist. Please run ./install.sh first."
    exit 1
fi

# Activate the environment
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate simple_auth_test

echo
echo "Select deployment test options:"
echo
echo "1. Test local deployment (localhost:3000)"
echo "2. Test Docker deployment"
echo "3. Test custom URL"
echo

read -p "Enter option (1-3): " test_option

api_url=""
mailhog_url=""
email_address=""
admin_test="false"

if [ "$test_option" == "1" ]; then
    api_url="http://localhost:3000"
    mailhog_url="http://localhost:8025"
elif [ "$test_option" == "2" ]; then
    api_url="http://auth-service:3000"
    mailhog_url="http://mailhog:8025"
elif [ "$test_option" == "3" ]; then
    read -p "Enter API URL (e.g., http://example.com:3000): " api_url
else
    echo "Invalid option selected."
    exit 1
fi

echo
read -p "Use MailHog for email testing? (y/n): " use_mailhog
if [[ "$use_mailhog" == "y" || "$use_mailhog" == "Y" ]]; then
    if [ -z "$mailhog_url" ]; then
        read -p "Enter MailHog URL (e.g., http://localhost:8025): " mailhog_url
    fi
else
    mailhog_url=""
fi

echo
read -p "Use real email for verification? (y/n): " use_real_email
if [[ "$use_real_email" == "y" || "$use_real_email" == "Y" ]]; then
    read -p "Enter email address: " email_address
fi

echo
read -p "Run admin API tests? (y/n): " run_admin_test
if [[ "$run_admin_test" == "y" || "$run_admin_test" == "Y" ]]; then
    admin_test="true"
fi

echo
echo "Running deployment tests..."
echo

# Build the command
cmd="python deploy_test.py"

if [ ! -z "$api_url" ]; then
    cmd="$cmd --url \"$api_url\""
fi

if [ ! -z "$email_address" ]; then
    cmd="$cmd --email \"$email_address\""
fi

if [ ! -z "$mailhog_url" ]; then
    cmd="$cmd --mailhog-url \"$mailhog_url\""
fi

if [ "$admin_test" == "true" ]; then
    cmd="$cmd --admin-test true"
fi

# Run the command
echo "Executing: $cmd"
eval $cmd

echo
echo "==================================================="
echo "Test run completed"
echo "==================================================="