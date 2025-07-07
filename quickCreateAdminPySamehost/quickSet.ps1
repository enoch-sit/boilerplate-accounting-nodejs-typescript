# QuickSet - User Management Utility
# This script provides a menu to remove all users, create default users, and list users

function Show-Menu {
    Clear-Host
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "         QUICKSET - USER MANAGEMENT UTILITY" -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host
    Write-Host "This utility helps you quickly manage users in your application." -ForegroundColor White
    Write-Host
    Write-Host "Available options:" -ForegroundColor Yellow
    Write-Host "1. Complete Reset (Remove All + Create Default Users + List)" -ForegroundColor White
    Write-Host "2. Remove All Users" -ForegroundColor White
    Write-Host "3. Create Default Users" -ForegroundColor White
    Write-Host "4. List All Users" -ForegroundColor White
    Write-Host "5. Exit" -ForegroundColor White
    Write-Host
}

function Complete-Reset {
    Write-Host
    Write-Host "===== STARTING COMPLETE USER RESET =====" -ForegroundColor Magenta
    Write-Host
    Write-Host "Step 1: Removing all existing users..." -ForegroundColor Yellow
    & .\remove_all_users.ps1
    Write-Host
    Write-Host "Step 2: Creating default users..." -ForegroundColor Yellow
    & .\create_users.ps1
    Write-Host
    Write-Host "Step 3: Listing all users..." -ForegroundColor Yellow
    & .\list_users.ps1
    Write-Host
    Write-Host "===== COMPLETE USER RESET FINISHED =====" -ForegroundColor Green
    Write-Host
    Read-Host "Press Enter to continue"
}

function Remove-AllUsers {
    Write-Host
    Write-Host "===== REMOVING ALL USERS =====" -ForegroundColor Red
    & .\remove_all_users.ps1
    Write-Host
    Read-Host "Press Enter to continue"
}

function Create-DefaultUsers {
    Write-Host
    Write-Host "===== CREATING DEFAULT USERS =====" -ForegroundColor Green
    & .\create_users.ps1
    Write-Host
    Read-Host "Press Enter to continue"
}

function List-AllUsers {
    Write-Host
    Write-Host "===== LISTING ALL USERS =====" -ForegroundColor Cyan
    & .\list_users.ps1
    Write-Host
    Read-Host "Press Enter to continue"
}

# Main script execution
$exitScript = $false
while (-not $exitScript) {
    Show-Menu
    $choice = Read-Host "Enter your choice (1-5)"
    
    switch ($choice) {
        "1" { Complete-Reset }
        "2" { Remove-AllUsers }
        "3" { Create-DefaultUsers }
        "4" { List-AllUsers }
        "5" { 
            Write-Host
            Write-Host "Thank you for using QuickSet User Management Utility" -ForegroundColor Cyan
            Write-Host "Exiting..." -ForegroundColor Cyan
            Start-Sleep -Seconds 2
            $exitScript = $true
        }
        default {
            Write-Host "Invalid choice. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}