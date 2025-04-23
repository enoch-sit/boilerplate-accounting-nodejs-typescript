# User Management Guide

This guide provides comprehensive instructions for quickly creating and removing users in the Simple Authentication System. It's designed for new users who need to understand how to manage users efficiently on both Windows and Linux systems.

## Table of Contents
- [User Management Guide](#user-management-guide)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Prerequisites](#prerequisites)
  - [Installation Setup](#installation-setup)
    - [Windows](#windows)
    - [Linux](#linux)
  - [Creating Users](#creating-users)
    - [Creating Users on Windows](#creating-users-on-windows)
    - [Creating Users on Linux](#creating-users-on-linux)
  - [Listing Users](#listing-users)
    - [Listing Users on Windows](#listing-users-on-windows)
    - [Listing Users on Linux](#listing-users-on-linux)
  - [Removing Users](#removing-users)
    - [Removing Users on Windows](#removing-users-on-windows)
    - [Removing Users on Linux](#removing-users-on-linux)
  - [Customizing User Configurations](#customizing-user-configurations)
  - [Troubleshooting](#troubleshooting)
    - [API Server Not Running](#api-server-not-running)
    - [MongoDB Connection Issues](#mongodb-connection-issues)
    - [Python or Package Errors](#python-or-package-errors)
    - [Permission Issues on Linux](#permission-issues-on-linux)
  - [Security Best Practices](#security-best-practices)

## Introduction

The Simple Authentication System includes user management utilities that enable administrators to:
- Create default users with different roles (admin, supervisor, enduser)
- List all existing users and their roles
- Remove users from the system

These utilities are available as Python scripts with companion batch files (.bat) for Windows and shell scripts (.sh) for Linux, making them easy to run on any platform.

## Prerequisites

Before using the user management utilities, ensure you have:

- Docker and Docker Compose installed
- The authentication system running with `docker-compose -f docker-compose.dev.yml up -d`
- Python 3.7 or higher installed
- Basic familiarity with command line operations

## Installation Setup

The user management scripts are already included in the `quickCreateAdminPy` folder of your project. You don't need to install anything else beyond the prerequisites.

However, if you're setting up a new environment, ensure the Python virtual environment is properly configured:

### Windows
```
cd quickCreateAdminPy
python -m venv venv
venv\Scripts\activate
pip install requests tabulate
```

### Linux
```
cd quickCreateAdminPy
python3 -m venv venv
source venv/bin/activate
pip install requests tabulate
```

## Creating Users

The create_users script will set up a default admin user, along with supervisor and regular users.

### Creating Users on Windows

1. Navigate to the quickCreateAdminPy folder in File Explorer
2. Double-click the `create_users.bat` file

Alternatively, from Command Prompt:
```
cd path\to\simple-accounting\quickCreateAdminPy
create_users.bat
```

### Creating Users on Linux

1. Open a terminal
2. Make the script executable (first time only):
   ```
   chmod +x create_users.sh
   ```
3. Run the script:
   ```
   ./create_users.sh
   ```

**Default Users Created:**
- Admin: username `admin`, password `admin@admin`
- Supervisors: username `supervisor1` and `supervisor2`, passwords `Supervisor1@` and `Supervisor2@`
- Regular users: username `user1` and `user2`, passwords `User1@123` and `User2@123`

## Listing Users

The list_users script allows you to see all existing users in the system and their roles.

### Listing Users on Windows

1. Navigate to the quickCreateAdminPy folder in File Explorer
2. Double-click the `list_users.bat` file

Alternatively, from Command Prompt:
```
cd path\to\simple-accounting\quickCreateAdminPy
list_users.bat
```

### Listing Users on Linux

1. Open a terminal
2. Make the script executable (first time only):
   ```
   chmod +x list_users.sh
   ```
3. Run the script:
   ```
   ./list_users.sh
   ```

The output will display a formatted table showing:
- Username
- Email
- Role
- Verification status
- Creation date
- Last login date
- User ID

## Removing Users

The remove_all_users script allows you to remove all users from the system.

### Removing Users on Windows

1. Navigate to the quickCreateAdminPy folder in File Explorer
2. Double-click the `remove_all_users.bat` file

Alternatively, from Command Prompt:
```
cd path\to\simple-accounting\quickCreateAdminPy
remove_all_users.bat
```

### Removing Users on Linux

1. Open a terminal
2. Create a shell script file named `remove_all_users.sh` with the following content:
   ```bash
   #!/bin/bash
   # User Removal Shell Script
   
   echo "===== User Removal Utility ====="
   echo "This script will remove ALL users from the database!"
   
   # Check if Python is installed
   if ! command -v python3 &>/dev/null; then
       echo "Error: Python 3 is not installed or not in PATH"
       echo "Please install Python 3.7+ and try again"
       exit 1
   fi
   
   # Check if virtual environment exists, if not create it
   if [ ! -d "venv" ]; then
       echo "Creating virtual environment..."
       python3 -m venv venv
   fi
   
   # Activate the virtual environment
   echo "Activating virtual environment..."
   source venv/bin/activate
   
   # Install required packages in the virtual environment
   echo "Installing required packages..."
   pip install requests
   
   # Run the Python script
   echo ""
   echo "Running User Removal Script..."
   echo ""
   python remove_all_users.py
   
   echo ""
   if [ $? -eq 0 ]; then
       echo "User removal completed successfully!"
   else
       echo "Error occurred during user removal."
   fi
   
   # Deactivate the virtual environment
   deactivate
   
   read -p "Press Enter to continue..."
   ```

3. Make the script executable:
   ```
   chmod +x remove_all_users.sh
   ```

4. Run the script:
   ```
   ./remove_all_users.sh
   ```

**Warning:** This will permanently remove ALL users from the database. You will be prompted to confirm this action by typing "DELETE ALL USERS" and providing a password.

## Customizing User Configurations

If you need to customize the default users being created:

1. Open the `create_users.py` file in a text editor
2. Locate the user configuration sections:
   ```python
   ADMIN_USER = {
       "username": "admin",
       "email": "admin@example.com",
       "password": "admin@admin",
   }
   SUPERVISOR_USERS = [...]
   REGULAR_USERS = [...]
   ```
3. Modify the usernames, emails, passwords, or add/remove users as needed
4. Save the file
5. Run the create_users script again

## Troubleshooting

### API Server Not Running

If you encounter an error about the API server not running:

1. Start the Docker environment:
   ```
   docker-compose -f docker-compose.dev.yml up -d
   ```
2. Wait 30 seconds for all services to initialize
3. Try running the script again

### MongoDB Connection Issues

If the script fails to connect to MongoDB:

1. Check if the MongoDB container is running:
   ```
   docker ps | grep mongodb
   ```
2. If the container name is different from "auth-mongodb", edit the `MONGODB_CONTAINER` variable in the Python scripts

### Python or Package Errors

If you encounter Python errors:

1. Ensure you have Python 3.7+ installed
2. Try manually creating and activating the virtual environment
3. Manually install the required packages:
   ```
   pip install requests tabulate
   ```

### Permission Issues on Linux

If you encounter permission issues with the shell scripts:

1. Ensure the scripts are executable:
   ```
   chmod +x create_users.sh list_users.sh remove_all_users.sh
   ```
2. If running the Python scripts directly, make them executable:
   ```
   chmod +x create_users.py list_users.py remove_all_users.py
   ```

## Security Best Practices

For production environments, follow these best practices:

1. **Change default passwords**: Always change the default passwords, especially for admin accounts
2. **Limit admin accounts**: Only create the necessary admin accounts
3. **Use strong passwords**: Enforce strong password policies
4. **Remove test accounts**: Remove or disable test accounts before deploying to production
5. **Regularly review users**: Periodically review the user list and remove inactive accounts
6. **Audit user actions**: Enable logging and audit user activities, especially for admin accounts
7. **Secure database access**: Restrict direct database access and use the API for user management whenever possible

Remember that the provided scripts are primarily designed for development and testing environments. For production deployments, consider implementing additional security measures and access controls.