@echo off
REM QuickSet - User Management Utility
REM This script provides a menu to remove all users, create default users, and list users

setlocal enabledelayedexpansion

:MENU
cls
echo ===================================================
echo         QUICKSET - USER MANAGEMENT UTILITY
echo ===================================================
echo.
echo This utility helps you quickly manage users in your application.
echo.
echo Available options:
echo 1. Complete Reset (Remove All + Create Default Users + List)
echo 2. Remove All Users
echo 3. Create Default Users
echo 4. List All Users
echo 5. Exit
echo.

set /p choice=Enter your choice (1-5): 

if "%choice%"=="1" goto COMPLETE_RESET
if "%choice%"=="2" goto REMOVE_USERS
if "%choice%"=="3" goto CREATE_USERS
if "%choice%"=="4" goto LIST_USERS
if "%choice%"=="5" goto EXIT
echo Invalid choice. Please try again.
timeout /t 2 >nul
goto MENU

:COMPLETE_RESET
echo.
echo ===== STARTING COMPLETE USER RESET =====
echo.
echo Step 1: Removing all existing users...
call remove_all_users.bat
echo.
echo Step 2: Creating default users...
call create_users.bat
echo.
echo Step 3: Listing all users...
call list_users.bat
echo.
echo ===== COMPLETE USER RESET FINISHED =====
echo.
pause
goto MENU

:REMOVE_USERS
echo.
echo ===== REMOVING ALL USERS =====
call remove_all_users.bat
echo.
pause
goto MENU

:CREATE_USERS
echo.
echo ===== CREATING DEFAULT USERS =====
call create_users.bat
echo.
pause
goto MENU

:LIST_USERS
echo.
echo ===== LISTING ALL USERS =====
call list_users.bat
echo.
pause
goto MENU

:EXIT
echo.
echo Thank you for using QuickSet User Management Utility
echo Exiting...
timeout /t 2 >nul
exit /b 0