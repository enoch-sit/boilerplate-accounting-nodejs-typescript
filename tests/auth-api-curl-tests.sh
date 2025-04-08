#!/bin/bash
# Comprehensive curl test script for authentication endpoints
# This script works in Git Bash on Windows or any Linux/macOS terminal

# Color codes for better readability
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Base URL - change if your service is deployed elsewhere
BASE_URL="http://localhost:3000"

# Create a directory to store test results
TEST_DIR="./tests/curl-results"
mkdir -p $TEST_DIR

# Function to display test results
show_test_result() {
  local test_name=$1
  local status_code=$2
  local response=$3
  
  echo -e "\n======================="
  echo -e "${CYAN}TEST: $test_name${NC}"
  if [[ $status_code -lt 400 ]]; then
    echo -e "Status: ${GREEN}$status_code${NC}"
    echo -e "Response: ${GREEN}$response${NC}"
  else
    echo -e "Status: ${RED}$status_code${NC}"
    echo -e "Response: ${YELLOW}$response${NC}"
  fi
  echo -e "======================="
}

# Variables to store tokens and user data
ACCESS_TOKEN=""
REFRESH_TOKEN=""
USER_ID=""
RANDOM_STRING=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
TEST_USERNAME="testuser_$RANDOM_STRING"
TEST_EMAIL="testuser_$RANDOM_STRING@example.com"
TEST_PASSWORD="TestPassword123!"

echo -e "${CYAN}=== Authentication API Testing ====${NC}"
echo -e "Base URL: $BASE_URL"
echo -e "Test username: $TEST_USERNAME"
echo -e "Test email: $TEST_EMAIL"

# -----------------
# 1. SIGNUP TEST
# -----------------
echo -e "\n${CYAN}=== Testing Signup Endpoint ===${NC}"

# Running the signup test
SIGNUP_RESPONSE=$(curl -s -X POST "$BASE_URL/api/auth/signup" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$TEST_USERNAME\",\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\"}" \
  -w "\nSTATUS_CODE:%{http_code}")

SIGNUP_BODY=$(echo "$SIGNUP_RESPONSE" | sed -n '/^STATUS_CODE/!p')
SIGNUP_STATUS=$(echo "$SIGNUP_RESPONSE" | grep -o 'STATUS_CODE:[0-9]*' | cut -d':' -f2)

show_test_result "USER SIGNUP" "$SIGNUP_STATUS" "$SIGNUP_BODY"
echo "$SIGNUP_BODY" > "$TEST_DIR/signup_response.json"

# Extract user ID if available
USER_ID=$(echo $SIGNUP_BODY | grep -o '"userId":"[^"]*"' | cut -d'"' -f4)
if [[ -n "$USER_ID" ]]; then
  echo -e "${GREEN}Extracted User ID: $USER_ID${NC}"
fi

# -----------------
# 2. EMAIL VERIFICATION (Simulated)
# -----------------
echo -e "\n${CYAN}=== Email Verification Would Be Here ===${NC}"
echo -e "${YELLOW}Note: In a real scenario, you would receive a verification email with a token${NC}"
echo -e "${YELLOW}For testing purposes, we'll continue with the login flow${NC}"

# -----------------
# 3. LOGIN TEST
# -----------------
echo -e "\n${CYAN}=== Testing Login Endpoint ===${NC}"

# Running the login test
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$TEST_USERNAME\",\"password\":\"$TEST_PASSWORD\"}" \
  -w "\nSTATUS_CODE:%{http_code}")

LOGIN_BODY=$(echo "$LOGIN_RESPONSE" | sed -n '/^STATUS_CODE/!p')
LOGIN_STATUS=$(echo "$LOGIN_RESPONSE" | grep -o 'STATUS_CODE:[0-9]*' | cut -d':' -f2)

show_test_result "USER LOGIN" "$LOGIN_STATUS" "$LOGIN_BODY"
echo "$LOGIN_BODY" > "$TEST_DIR/login_response.json"

# Extract tokens if login was successful
if [[ $LOGIN_STATUS -lt 400 ]]; then
  ACCESS_TOKEN=$(echo $LOGIN_BODY | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
  REFRESH_TOKEN=$(echo $LOGIN_BODY | grep -o '"refreshToken":"[^"]*"' | cut -d'"' -f4)
  
  if [[ -n "$ACCESS_TOKEN" ]]; then
    echo -e "${GREEN}Extracted Access Token: ${NC}${ACCESS_TOKEN:0:20}..."
  fi
  
  if [[ -n "$REFRESH_TOKEN" ]]; then
    echo -e "${GREEN}Extracted Refresh Token: ${NC}${REFRESH_TOKEN:0:20}..."
  fi
else
  echo -e "${RED}Login failed - continuing with limited tests${NC}"
fi

# -----------------
# 4. REFRESH TOKEN TEST
# -----------------
if [[ -n "$REFRESH_TOKEN" ]]; then
  echo -e "\n${CYAN}=== Testing Token Refresh Endpoint ===${NC}"
  
  REFRESH_RESPONSE=$(curl -s -X POST "$BASE_URL/api/auth/refresh" \
    -H "Content-Type: application/json" \
    -d "{\"refreshToken\":\"$REFRESH_TOKEN\"}" \
    -w "\nSTATUS_CODE:%{http_code}")
  
  REFRESH_BODY=$(echo "$REFRESH_RESPONSE" | sed -n '/^STATUS_CODE/!p')
  REFRESH_STATUS=$(echo "$REFRESH_RESPONSE" | grep -o 'STATUS_CODE:[0-9]*' | cut -d':' -f2)
  
  show_test_result "TOKEN REFRESH" "$REFRESH_STATUS" "$REFRESH_BODY"
  echo "$REFRESH_BODY" > "$TEST_DIR/refresh_response.json"
  
  # Update access token if refresh was successful
  if [[ $REFRESH_STATUS -lt 400 ]]; then
    NEW_ACCESS_TOKEN=$(echo $REFRESH_BODY | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
    if [[ -n "$NEW_ACCESS_TOKEN" ]]; then
      ACCESS_TOKEN=$NEW_ACCESS_TOKEN
      echo -e "${GREEN}Updated Access Token: ${NC}${ACCESS_TOKEN:0:20}..."
    fi
  fi
fi

# -----------------
# 5. FORGOT PASSWORD TEST
# -----------------
echo -e "\n${CYAN}=== Testing Forgot Password Endpoint ===${NC}"

FORGOT_RESPONSE=$(curl -s -X POST "$BASE_URL/api/auth/forgot-password" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$TEST_EMAIL\"}" \
  -w "\nSTATUS_CODE:%{http_code}")

FORGOT_BODY=$(echo "$FORGOT_RESPONSE" | sed -n '/^STATUS_CODE/!p')
FORGOT_STATUS=$(echo "$FORGOT_RESPONSE" | grep -o 'STATUS_CODE:[0-9]*' | cut -d':' -f2)

show_test_result "FORGOT PASSWORD" "$FORGOT_STATUS" "$FORGOT_BODY"
echo "$FORGOT_BODY" > "$TEST_DIR/forgot_password_response.json"

echo -e "${YELLOW}Note: In a real scenario, you would receive a password reset email${NC}"

# -----------------
# 6. RESET PASSWORD TEST (Simulated)
# -----------------
echo -e "\n${CYAN}=== Testing Reset Password Endpoint (Simulated) ===${NC}"
echo -e "${YELLOW}Note: This will fail with a dummy token${NC}"

RESET_RESPONSE=$(curl -s -X POST "$BASE_URL/api/auth/reset-password" \
  -H "Content-Type: application/json" \
  -d "{\"token\":\"dummy-reset-token\",\"newPassword\":\"NewPassword456!\"}" \
  -w "\nSTATUS_CODE:%{http_code}")

RESET_BODY=$(echo "$RESET_RESPONSE" | sed -n '/^STATUS_CODE/!p')
RESET_STATUS=$(echo "$RESET_RESPONSE" | grep -o 'STATUS_CODE:[0-9]*' | cut -d':' -f2)

show_test_result "RESET PASSWORD (EXPECTED TO FAIL)" "$RESET_STATUS" "$RESET_BODY"
echo "$RESET_BODY" > "$TEST_DIR/reset_password_response.json"

# -----------------
# PROTECTED ROUTES TESTS
# -----------------
if [[ -n "$ACCESS_TOKEN" ]]; then
  echo -e "\n${CYAN}=== Testing Protected Routes ===${NC}"
  
  # 7. GET PROFILE TEST
  echo -e "\n${CYAN}=== Testing Get Profile Endpoint ===${NC}"
  
  PROFILE_RESPONSE=$(curl -s -X GET "$BASE_URL/api/protected/profile" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -w "\nSTATUS_CODE:%{http_code}")
  
  PROFILE_BODY=$(echo "$PROFILE_RESPONSE" | sed -n '/^STATUS_CODE/!p')
  PROFILE_STATUS=$(echo "$PROFILE_RESPONSE" | grep -o 'STATUS_CODE:[0-9]*' | cut -d':' -f2)
  
  show_test_result "GET PROFILE" "$PROFILE_STATUS" "$PROFILE_BODY"
  echo "$PROFILE_BODY" > "$TEST_DIR/profile_response.json"
  
  # 8. UPDATE PROFILE TEST
  echo -e "\n${CYAN}=== Testing Update Profile Endpoint ===${NC}"
  
  UPDATE_USERNAME="updated_$RANDOM_STRING"
  
  UPDATE_PROFILE_RESPONSE=$(curl -s -X PUT "$BASE_URL/api/protected/profile" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$UPDATE_USERNAME\"}" \
    -w "\nSTATUS_CODE:%{http_code}")
  
  UPDATE_PROFILE_BODY=$(echo "$UPDATE_PROFILE_RESPONSE" | sed -n '/^STATUS_CODE/!p')
  UPDATE_PROFILE_STATUS=$(echo "$UPDATE_PROFILE_RESPONSE" | grep -o 'STATUS_CODE:[0-9]*' | cut -d':' -f2)
  
  show_test_result "UPDATE PROFILE" "$UPDATE_PROFILE_STATUS" "$UPDATE_PROFILE_BODY"
  echo "$UPDATE_PROFILE_BODY" > "$TEST_DIR/update_profile_response.json"
  
  # 9. CHANGE PASSWORD TEST
  echo -e "\n${CYAN}=== Testing Change Password Endpoint ===${NC}"
  
  CHANGE_PASSWORD_RESPONSE=$(curl -s -X POST "$BASE_URL/api/protected/change-password" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"currentPassword\":\"$TEST_PASSWORD\",\"newPassword\":\"UpdatedPassword789!\"}" \
    -w "\nSTATUS_CODE:%{http_code}")
  
  CHANGE_PASSWORD_BODY=$(echo "$CHANGE_PASSWORD_RESPONSE" | sed -n '/^STATUS_CODE/!p')
  CHANGE_PASSWORD_STATUS=$(echo "$CHANGE_PASSWORD_RESPONSE" | grep -o 'STATUS_CODE:[0-9]*' | cut -d':' -f2)
  
  show_test_result "CHANGE PASSWORD" "$CHANGE_PASSWORD_STATUS" "$CHANGE_PASSWORD_BODY"
  echo "$CHANGE_PASSWORD_BODY" > "$TEST_DIR/change_password_response.json"
  
  # Update test password if successful
  if [[ $CHANGE_PASSWORD_STATUS -lt 400 ]]; then
    TEST_PASSWORD="UpdatedPassword789!"
    echo -e "${GREEN}Password updated successfully${NC}"
  fi
  
  # 10. DASHBOARD ACCESS TEST
  echo -e "\n${CYAN}=== Testing Dashboard Access ===${NC}"
  
  DASHBOARD_RESPONSE=$(curl -s -X GET "$BASE_URL/api/protected/dashboard" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -w "\nSTATUS_CODE:%{http_code}")
  
  DASHBOARD_BODY=$(echo "$DASHBOARD_RESPONSE" | sed -n '/^STATUS_CODE/!p')
  DASHBOARD_STATUS=$(echo "$DASHBOARD_RESPONSE" | grep -o 'STATUS_CODE:[0-9]*' | cut -d':' -f2)
  
  show_test_result "DASHBOARD ACCESS" "$DASHBOARD_STATUS" "$DASHBOARD_BODY"
  echo "$DASHBOARD_BODY" > "$TEST_DIR/dashboard_response.json"
  
  # -----------------
  # ADMIN ROUTES TESTS
  # -----------------
  echo -e "\n${CYAN}=== Testing Admin Routes (May Fail Without Admin Privileges) ===${NC}"
  
  # 11. GET ALL USERS TEST
  echo -e "\n${CYAN}=== Testing Get All Users Endpoint ===${NC}"
  
  USERS_RESPONSE=$(curl -s -X GET "$BASE_URL/api/admin/users" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -w "\nSTATUS_CODE:%{http_code}")
  
  USERS_BODY=$(echo "$USERS_RESPONSE" | sed -n '/^STATUS_CODE/!p')
  USERS_STATUS=$(echo "$USERS_RESPONSE" | grep -o 'STATUS_CODE:[0-9]*' | cut -d':' -f2)
  
  show_test_result "GET ALL USERS (ADMIN)" "$USERS_STATUS" "$USERS_BODY"
  echo "$USERS_BODY" > "$TEST_DIR/all_users_response.json"
  
  # 12. UPDATE USER ROLE TEST
  if [[ -n "$USER_ID" ]]; then
    echo -e "\n${CYAN}=== Testing Update User Role Endpoint ===${NC}"
    
    ROLE_RESPONSE=$(curl -s -X PUT "$BASE_URL/api/admin/users/$USER_ID/role" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"role\":\"USER\"}" \
      -w "\nSTATUS_CODE:%{http_code}")
    
    ROLE_BODY=$(echo "$ROLE_RESPONSE" | sed -n '/^STATUS_CODE/!p')
    ROLE_STATUS=$(echo "$ROLE_RESPONSE" | grep -o 'STATUS_CODE:[0-9]*' | cut -d':' -f2)
    
    show_test_result "UPDATE USER ROLE (ADMIN)" "$ROLE_STATUS" "$ROLE_BODY"
    echo "$ROLE_BODY" > "$TEST_DIR/role_update_response.json"
  fi
  
  # 13. REPORTS ACCESS TEST
  echo -e "\n${CYAN}=== Testing Reports Access Endpoint ===${NC}"
  
  REPORTS_RESPONSE=$(curl -s -X GET "$BASE_URL/api/admin/reports" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -w "\nSTATUS_CODE:%{http_code}")
  
  REPORTS_BODY=$(echo "$REPORTS_RESPONSE" | sed -n '/^STATUS_CODE/!p')
  REPORTS_STATUS=$(echo "$REPORTS_RESPONSE" | grep -o 'STATUS_CODE:[0-9]*' | cut -d':' -f2)
  
  show_test_result "REPORTS ACCESS (SUPERVISOR/ADMIN)" "$REPORTS_STATUS" "$REPORTS_BODY"
  echo "$REPORTS_BODY" > "$TEST_DIR/reports_response.json"
  
  # 14. ADMIN DASHBOARD ACCESS TEST
  echo -e "\n${CYAN}=== Testing Admin Dashboard Access ===${NC}"
  
  ADMIN_DASHBOARD_RESPONSE=$(curl -s -X GET "$BASE_URL/api/admin/dashboard" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -w "\nSTATUS_CODE:%{http_code}")
  
  ADMIN_DASHBOARD_BODY=$(echo "$ADMIN_DASHBOARD_RESPONSE" | sed -n '/^STATUS_CODE/!p')
  ADMIN_DASHBOARD_STATUS=$(echo "$ADMIN_DASHBOARD_RESPONSE" | grep -o 'STATUS_CODE:[0-9]*' | cut -d':' -f2)
  
  show_test_result "ADMIN DASHBOARD ACCESS" "$ADMIN_DASHBOARD_STATUS" "$ADMIN_DASHBOARD_BODY"
  echo "$ADMIN_DASHBOARD_BODY" > "$TEST_DIR/admin_dashboard_response.json"
else
  echo -e "\n${YELLOW}Skipping protected and admin routes tests as no access token is available.${NC}"
fi

# -----------------
# LOGOUT TESTS
# -----------------
if [[ -n "$REFRESH_TOKEN" ]]; then
  echo -e "\n${CYAN}=== Testing Logout Functionality ===${NC}"
  
  # 15. LOGOUT TEST
  echo -e "\n${CYAN}=== Testing Logout Endpoint ===${NC}"
  
  LOGOUT_RESPONSE=$(curl -s -X POST "$BASE_URL/api/auth/logout" \
    -H "Content-Type: application/json" \
    -d "{\"refreshToken\":\"$REFRESH_TOKEN\"}" \
    -w "\nSTATUS_CODE:%{http_code}")
  
  LOGOUT_BODY=$(echo "$LOGOUT_RESPONSE" | sed -n '/^STATUS_CODE/!p')
  LOGOUT_STATUS=$(echo "$LOGOUT_RESPONSE" | grep -o 'STATUS_CODE:[0-9]*' | cut -d':' -f2)
  
  show_test_result "LOGOUT" "$LOGOUT_STATUS" "$LOGOUT_BODY"
  echo "$LOGOUT_BODY" > "$TEST_DIR/logout_response.json"
  
  # 16. VERIFY LOGOUT (Try refreshing token - should fail)
  echo -e "\n${CYAN}=== Verifying Token Invalidation After Logout ===${NC}"
  
  VERIFY_LOGOUT_RESPONSE=$(curl -s -X POST "$BASE_URL/api/auth/refresh" \
    -H "Content-Type: application/json" \
    -d "{\"refreshToken\":\"$REFRESH_TOKEN\"}" \
    -w "\nSTATUS_CODE:%{http_code}")
  
  VERIFY_LOGOUT_BODY=$(echo "$VERIFY_LOGOUT_RESPONSE" | sed -n '/^STATUS_CODE/!p')
  VERIFY_LOGOUT_STATUS=$(echo "$VERIFY_LOGOUT_RESPONSE" | grep -o 'STATUS_CODE:[0-9]*' | cut -d':' -f2)
  
  if [[ $VERIFY_LOGOUT_STATUS -ge 400 ]]; then
    echo -e "${GREEN}Token refresh failed after logout (expected behavior)!${NC}"
  else
    echo -e "${YELLOW}Warning: Token refresh after logout still works!${NC}"
  fi
  
  show_test_result "TOKEN INVALIDATION CHECK" "$VERIFY_LOGOUT_STATUS" "$VERIFY_LOGOUT_BODY"
  echo "$VERIFY_LOGOUT_BODY" > "$TEST_DIR/verify_logout_response.json"
else
  echo -e "\n${YELLOW}Skipping logout tests as no refresh token is available.${NC}"
fi

echo -e "\n${GREEN}All tests completed!${NC}"
echo -e "Test results and responses saved to: $TEST_DIR"
echo -e "\n${CYAN}=== Endpoint Testing Summary ===${NC}"
echo -e "1. Auth Routes: signup, verify-email, resend-verification, login, refresh, forgot-password, reset-password, logout"
echo -e "2. Protected Routes: profile (GET/PUT), change-password, dashboard"
echo -e "3. Admin Routes: users (GET), users/role (PUT), reports, dashboard"