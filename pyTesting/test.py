import requests

base_url = "http://localhost:3000/api"

# 1. Sign Up
print("\n--- Sign Up ---")
username = input("Enter username: ")
email = input("Enter email: ")
password = input("Enter password: ")
signup_data = {
    "username": username,
    "email": email,
    "password": password
}
signup_response = requests.post(f"{base_url}/auth/signup", json=signup_data)
print("Sign Up Response:", signup_response.json())

# 2. Verify Email
print("\n--- Verify Email ---")
token = input("Enter the verification token (from MailHog): ")
verify_email_data = {
    "token": token
}
verify_email_response = requests.post(f"{base_url}/auth/verify-email", json=verify_email_data)
print("Verify Email Response:", verify_email_response.json())

# 3. Login
print("\n--- Login ---")
login_username = input("Enter username for login: ")
login_password = input("Enter password for login: ")
login_data = {
    "username": login_username,
    "password": login_password
}
login_response = requests.post(f"{base_url}/auth/login", json=login_data)
print("Login Response:", login_response.json())

# Extract access and refresh tokens from the login response
access_token = login_response.json().get("accessToken", "")
refresh_token = login_response.json().get("refreshToken", "")
user_role = login_response.json().get("user", {}).get("role", "")

print(f"User role: {user_role}")

# 4. Access Protected Route
print("\n--- Access Protected Route ---")
if access_token:
    headers = {"Authorization": f"Bearer {access_token}"}
    profile_response = requests.get(f"{base_url}/profile", headers=headers)
    print("Profile Response:", profile_response.json())
else:
    print("Access token not available. Cannot access the protected route.")

# 5. Access Role-Based Routes
if access_token:
    headers = {"Authorization": f"Bearer {access_token}"}
    
    # Test admin-only route
    print("\n--- Testing Admin Route ---")
    admin_response = requests.get(f"{base_url}/admin/users", headers=headers)
    print(f"Admin Route Status: {admin_response.status_code}")
    print(f"Admin Route Response: {admin_response.json()}")
    
    # Test supervisor route
    print("\n--- Testing Supervisor Route ---")
    supervisor_response = requests.get(f"{base_url}/admin/reports", headers=headers)
    print(f"Supervisor Route Status: {supervisor_response.status_code}")
    print(f"Supervisor Route Response: {supervisor_response.json()}")
    
    # Test general user route
    print("\n--- Testing User Route ---")
    user_response = requests.get(f"{base_url}/admin/dashboard", headers=headers)
    print(f"User Route Status: {user_response.status_code}")
    print(f"User Route Response: {user_response.json()}")
else:
    print("Access token not available. Cannot test role-based routes.")

# 6. Refresh Token
print("\n--- Refresh Token ---")
if refresh_token:
    refresh_data = {"refreshToken": refresh_token}
    refresh_response = requests.post(f"{base_url}/auth/refresh", json=refresh_data)
    print("Refresh Token Response:", refresh_response.json())
    
    # Get new access token
    new_access_token = refresh_response.json().get("accessToken", "")
    
    # Verify the new token works with a protected route
    if new_access_token:
        print("\n--- Testing New Access Token ---")
        headers = {"Authorization": f"Bearer {new_access_token}"}
        test_response = requests.get(f"{base_url}/profile", headers=headers)
        print(f"New Token Test Status: {test_response.status_code}")
        print(f"New Token Test Response: {test_response.json()}")
else:
    print("Refresh token not available. Cannot refresh the token.")

# 7. Forgot Password
print("\n--- Forgot Password ---")
forgot_email = input("Enter the email for password reset: ")
forgot_password_data = {"email": forgot_email}
forgot_password_response = requests.post(f"{base_url}/auth/forgot-password", json=forgot_password_data)
print("Forgot Password Response:", forgot_password_response.json())

# 8. Reset Password
print("\n--- Reset Password ---")
reset_token = input("Enter the reset token (from email): ")
new_password = input("Enter the new password: ")
reset_password_data = {
    "token": reset_token,
    "newPassword": new_password
}
reset_password_response = requests.post(f"{base_url}/auth/reset-password", json=reset_password_data)
print("Reset Password Response:", reset_password_response.json())