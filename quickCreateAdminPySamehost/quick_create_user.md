# Quick User Creation Guide

This guide explains how to use the automated setup script to quickly create admin, supervisor, and regular users for testing and development purposes.

## Overview

The `quickCreateAdminPy` folder contains scripts that automate the creation of users with different roles:

- An admin user with full system access
- Supervisor users with limited administrative capabilities
- Regular users with basic access

## Prerequisites

- Docker and Docker Compose installed
- The authentication system running (`docker-compose -f docker-compose.dev.yml up -d`)
- Python 3.x installed on your system

## Running the Setup Script

### Windows Users

1. Simply run the `setup_and_run.bat` batch file by double-clicking it or running it from the command prompt:

   ```
   cd quickCreateAdminPy
   setup_and_run.bat
   ```

   This will:
   - Create a Python virtual environment
   - Install required dependencies
   - Run the user creation script

### Mac/Linux Users

1. Make the Python script executable:

   ```bash
   chmod +x create_users.py
   ```

2. Install the required Python package:

   ```bash
   pip install requests
   ```

3. Run the script:

   ```bash
   python create_users.py
   ```

## What the Script Does

The script performs these tasks in sequence:

1. Checks if the API server is running
2. Creates an admin user through the API
3. Promotes the user to admin role by directly updating the MongoDB database
4. Logs in as the admin and obtains an access token
5. Uses the admin credentials to create supervisor users
6. Uses the admin credentials to create regular users

## Default Users Created

After running the script, the following users will be available:

### Admin User

- Username: `admin`
- Email: `admin@example.com`
- Password: `admin@admin`

### Supervisor Users

- Username: `supervisor1`
- Email: `supervisor1@example.com`
- Password: `Supervisor1@`

- Username: `supervisor2`
- Email: `supervisor2@example.com`
- Password: `Supervisor2@`

### Regular Users

- Username: `user1`
- Email: `user1@example.com`
- Password: `User1@123`

- Username: `user2`
- Email: `user2@example.com`
- Password: `User2@123`

## Customizing the Users

If you want to customize the users being created, you can edit the `create_users.py` file:

1. Open `create_users.py` in a text editor
2. Modify the `ADMIN_USER`, `SUPERVISOR_USERS`, or `REGULAR_USERS` dictionaries
3. Save the file and run the script again

```python
# Example of modifying the admin user
ADMIN_USER = {
    "username": "myadmin",
    "email": "myadmin@example.com",
    "password": "SecurePassword123!",
}
```

## Troubleshooting

### API Server Not Running

If you see an error message about the API server not running:

1. Start the Docker environment:

   ```
   cd ..
   docker-compose -f docker-compose.dev.yml up -d
   ```

2. Wait a few seconds for services to initialize
3. Run the script again

### User Already Exists

If the admin user already exists, the script will continue to the next steps. If you want to start fresh:

1. Access the MongoDB container:

   ```
   docker exec -it auth-mongodb mongosh
   ```

2. Delete the existing users:

   ```
   use auth_db
   db.users.deleteMany({})
   exit
   ```

3. Run the script again

### MongoDB Container Not Found

If the script can't find the MongoDB container:

1. Check that the container is running:

   ```
   docker ps | findstr mongodb
   ```

2. If the container name is different, edit the `MONGODB_CONTAINER` variable in `create_users.py`

## Using the Created Users

After running the script, you can:

1. Log in to the application using any of the created users
2. Test role-based permissions with different user types
3. Use the admin user to manage other users through the admin API

## Security Note

These users are intended for development and testing purposes only. For production environments:

- Use strong, unique passwords
- Create only the necessary admin accounts
- Remove or disable test accounts before going live
