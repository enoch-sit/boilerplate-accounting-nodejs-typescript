# Simple Authentication System with TypeScript and MongoDB

A robust authentication system built with TypeScript, Express, and MongoDB. Features include user registration, email verification, JWT authentication, password reset, and protected routes.

## Features

- **User Registration**: Secure signup with email verification
- **JWT Authentication**: Access and refresh tokens with expiration
- **Email Integration**: Verification emails and password reset functionality
- **Protected Routes**: Middleware for authenticated endpoints
- **Password Management**: Secure hashing and reset functionality
- **Database Integration**: MongoDB for data persistence

### Setting Up MongoDB on Windows

1. **Download and Install MongoDB**:
   - Visit the MongoDB download page and download the latest version for Windows.
   - Follow the installation instructions to install MongoDB Community Server.

2. **Start MongoDB Service**:
   - Open Command Prompt as Administrator.
   - Navigate to the MongoDB bin directory (e.g., `C:\Program Files\MongoDB\Server\6.0\bin`).
   - `mkdir C:\data\db`
   - `mkdir C:\data\log`
   - Run `mongod --dbpath C:\data\db` to start the MongoDB server.

3. **Test Connection**:
   - Open another Command Prompt.
   - Run `mongosh` to connect to the MongoDB shell. not `mongo`
   - Use `show dbs` to list databases and confirm the connection.

### Setting Up MongoDB on Linux

1. **Install MongoDB**:
   - For Ubuntu/Debian:

     ```bash
     sudo apt-get install -y mongodb-org
     ```

   - For CentOS/RHEL:

     ```bash
     sudo yum install -y mongodb-org
     ```

2. **Start MongoDB Service**:
   - Start the service with:

     ```bash
     sudo systemctl start mongod
     ```

   - Enable MongoDB to start on boot:

     ```bash
     sudo systemctl enable mongod
     ```

3. **Test Connection**:
   - Connect to MongoDB with:

     ```bash
     mongo
     ```

   - Use `show dbs` to list databases and confirm the connection.

### Setting Up MongoDB on AWS

1. **Create an Amazon DocumentDB Cluster**:
   - Navigate to the AWS Management Console.
   - Go to the Amazon DocumentDB service.
   - Create a new cluster, choosing instance type and other settings as needed.

2. **Connect to DocumentDB**:
   - Use the AWS CLI or SDK to connect to your DocumentDB cluster.
   - Example connection string:

     ```bash
     mongodb://username:password@docdb-2025-03-27.cluster-c123456789abcdef0.c123456789abcdef0.docdb.amazonaws.com:27017/?ssl=true&ssl_ca_certs=rds-combined-ca-bundle.pem
     ```

3. **Test Connection**:
   - Use a MongoDB client or the `mongo` shell to connect to your DocumentDB instance.
   - Use `show dbs` to list databases and confirm the connection.

- **Environment Configuration**: Separate settings for development and production

## Technologies

- **Backend**: Node.js, Express
- **Language**: TypeScript
- **Database**: MongoDB, Mongoose
- **Authentication**: JSON Web Tokens (JWT)
- **Email**: Nodemailer (MailHog for development, AWS SES for production)
- **Security**: Helmet, rate limiting, CORS
- **Logging**: Winston

## Quick Start

### Prerequisites

• Node.js (v18+)
• MongoDB (Local or Atlas)
• npm

### Installation

1. **Clone the repository**:

   ```bash
   git clone https://github.com/enoch-sit/boilerplate-auth-simple-nodejs-typescript.git
   cd boilerplate-auth-simple-nodejs-typescript
   ```

2. **Install dependencies**:

   ```bash
   npm install
   ```

3. **Set up environment variables**:
   • Create `.env.development` and `.env.production` files in the root directory.
   • Use the templates provided in the project documentation.

4. **Start the development server**:

   ```bash
   npm run dev
   ```

## Configuration

### Environment Variables

| Variable                | Description                          | Example                   |
|-------------------------|--------------------------------------|---------------------------|
| `MONGO_URI`             | MongoDB connection string            | `mongodb://localhost:27017/auth` |
| `JWT_ACCESS_SECRET`     | Secret key for access tokens         | `your_access_secret`      |
| `JWT_REFRESH_SECRET`    | Secret key for refresh tokens        | `your_refresh_secret`     |
| `EMAIL_HOST`            | SMTP server host                     | `smtp.mailservice.com`    |
| `EMAIL_PORT`            | SMTP server port                     | `587`                     |
| `EMAIL_USER`            | SMTP username                        | `user@example.com`        |
| `EMAIL_PASS`            | SMTP password                        | `password123`            |

### Email Setup

• **Development**: Use MailHog (included in Docker setup)

  ```bash
  docker run -d -p 1025:1025 -p 8025:8025 mailhog/mailhog
  ```

• **Production**: Configure AWS SES or another SMTP service.

## API Endpoints

| Endpoint                | Method | Description                     |
|-------------------------|--------|---------------------------------|
| `/api/auth/signup`      | POST   | Register a new user             |
| `/api/auth/login`       | POST   | Login with credentials          |
| `/api/auth/refresh`     | POST   | Refresh access token            |
| `/api/auth/verify-email`| POST   | Verify email with token         |
| `/api/profile`         | GET    | Get user profile (Protected)    |
| `/api/reset-password`   | POST   | Reset password with token       |

## Testing

### Register a User

```bash
curl -X POST http://localhost:3000/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"Password123!"}'
```

### Verify Email (Check MailHog UI at `http://localhost:8025`)

```bash
curl -X POST http://localhost:3000/api/auth/verify-email \
  -H "Content-Type: application/json" \
  -d '{"token":"ABC123"}'
```

### Login

```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"Password123!"}'
```

### Access Protected Route

```bash
curl -X GET http://localhost:3000/api/profile \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Testing with python

Here's how you can use Python with the `requests` library to automate testing for these endpoints. This script assumes you have the necessary server and MailHog running locally. Remember to replace placeholders like `your_access_token` or `reset_token_from_email` with the actual values.

To use MailHog for testing email functionality in your Windows development environment, you'll need to:

1. First make sure MailHog is running properly
2. Use any valid email format for testing
3. Check the MailHog web interface to retrieve verification codes

Here's how to do this:

### Setting up and using MailHog in Windows

1. **Start MailHog using Docker**:
   ```
   docker run -d -p 1025:1025 -p 8025:8025 mailhog/mailhog
   ```

2. **When testing, use any email address**:
   - You can use any valid email format like `test@example.com` or `yourusername@test.com`
   - The actual email address doesn't matter since MailHog will capture all outgoing emails in your development environment

3. **Access the MailHog web interface**:
   - Open your browser and go to: `http://localhost:8025`
   - This is the web UI where you can see all emails sent by your application

4. **Get verification codes**:
   - After registering in your application, check the MailHog web interface
   - You'll see the email containing your verification code
   - The code will be displayed prominently (it's a 6-character code in your implementation)

### Example testing flow

1. Run your app and MailHog
2. Register with username: `testuser`, email: `test@example.com`, password: `Password123!`
3. Go to `http://localhost:8025` and find the verification email
4. Copy the verification code (looks like `ABC123`)
5. Use that code in your verification step

Your application is properly configured for this workflow based on your `.env.development` file or run `testing\test.py`:

```
EMAIL_SERVICE=smtp
EMAIL_HOST=localhost
EMAIL_PORT=1025
```

These settings direct your application to send emails to MailHog running on the local SMTP port 1025, and you can then retrieve those emails via the MailHog web interface on port 8025.

```python
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

# 4. Access Protected Route
print("\n--- Access Protected Route ---")
if access_token:
    headers = {"Authorization": f"Bearer {access_token}"}
    profile_response = requests.get(f"{base_url}/profile", headers=headers)
    print("Profile Response:", profile_response.json())
else:
    print("Access token not available. Cannot access the protected route.")

# 5. Refresh Token
print("\n--- Refresh Token ---")
if refresh_token:
    refresh_data = {"refreshToken": refresh_token}
    refresh_response = requests.post(f"{base_url}/auth/refresh", json=refresh_data)
    print("Refresh Token Response:", refresh_response.json())
else:
    print("Refresh token not available. Cannot refresh the token.")

# 6. Forgot Password
print("\n--- Forgot Password ---")
forgot_email = input("Enter the email for password reset: ")
forgot_password_data = {"email": forgot_email}
forgot_password_response = requests.post(f"{base_url}/auth/forgot-password", json=forgot_password_data)
print("Forgot Password Response:", forgot_password_response.json())

# 7. Reset Password
print("\n--- Reset Password ---")
reset_token = input("Enter the reset token (from email): ")
new_password = input("Enter the new password: ")
reset_password_data = {
    "token": reset_token,
    "newPassword": new_password
}
reset_password_response = requests.post(f"{base_url}/auth/reset-password", json=reset_password_data)
print("Reset Password Response:", reset_password_response.json())
```

### Steps to Run the Script

1. Install the `requests` library if you haven't already:

   ```bash
   pip install requests
   ```

2. Save the script to a file (e.g., `test_api.py`).
3. Run the script with:

   ```bash
   python test_api.py
   ```

This script will interact with the API step by step and print the responses for each step. Let me know if you need help setting up or debugging! 🚀

## Deployment

### Production Considerations

1. **Database**: Use MongoDB Atlas for a managed MongoDB service.
2. **Email**: Configure AWS SES in `.env.production`.
3. **HTTPS**: Use a reverse proxy (Nginx) or cloud provider (AWS, Heroku).
4. **Environment Variables**: Store secrets securely (e.g., AWS Secrets Manager).

### Docker

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
CMD ["npm", "start"]
```

## License

MIT License. See `LICENSE` for details.
