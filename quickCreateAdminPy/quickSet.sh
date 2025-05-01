#!/bin/bash
# QuickSet - User Management Utility
# This script provides a menu to remove all users, create default users, and list users

# Function to display menu
show_menu() {
    clear
    echo "==================================================="
    echo "         QUICKSET - USER MANAGEMENT UTILITY"
    echo "==================================================="
    echo
    echo "This utility helps you quickly manage users in your application."
    echo
    echo "Available options:"
    echo "1. Complete Reset (Remove All + Create Default Users + List)"
    echo "2. Remove All Users"
    echo "3. Create Default Users"
    echo "4. List All Users"
    echo "5. Exit"
    echo
}

# Function for complete reset
complete_reset() {
    echo
    echo "===== STARTING COMPLETE USER RESET ====="
    echo
    echo "Step 1: Removing all existing users..."
    bash ./remove_all_users.sh
    echo
    echo "Step 2: Creating default users..."
    bash ./create_users.sh
    echo
    echo "Step 3: Listing all users..."
    bash ./list_users.sh
    echo
    echo "===== COMPLETE USER RESET FINISHED ====="
    echo
    read -p "Press Enter to continue..."
}

# Function to remove all users
remove_users() {
    echo
    echo "===== REMOVING ALL USERS ====="
    bash ./remove_all_users.sh
    echo
    read -p "Press Enter to continue..."
}

# Function to create default users
create_users() {
    echo
    echo "===== CREATING DEFAULT USERS ====="
    bash ./create_users.sh
    echo
    read -p "Press Enter to continue..."
}

# Function to list all users
list_users() {
    echo
    echo "===== LISTING ALL USERS ====="
    bash ./list_users.sh
    echo
    read -p "Press Enter to continue..."
}

# Make the script executable
chmod +x remove_all_users.sh create_users.sh list_users.sh 2>/dev/null

# Main script execution
while true; do
    show_menu
    read -p "Enter your choice (1-5): " choice
    
    case $choice in
        1)
            complete_reset
            ;;
        2)
            remove_users
            ;;
        3)
            create_users
            ;;
        4)
            list_users
            ;;
        5)
            echo
            echo "Thank you for using QuickSet User Management Utility"
            echo "Exiting..."
            sleep 2
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            sleep 2
            ;;
    esac
done