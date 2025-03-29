// tests/auth.test.ts
import request from 'supertest';
import axios from 'axios';
import { MongoClient, Db } from 'mongodb';
import { createInterface } from 'readline';

// Update these configurations as needed
const API_URL = 'http://localhost:3000/api';
const MAILHOG_API = 'http://localhost:8025/api/v1';
const MONGODB_URI = 'mongodb://localhost:27017/auth_db';

// Set to true to enable manual input for verification codes and tokens
const USE_MANUAL_INPUT = true;

// Increase Jest timeout (longer for manual input)
jest.setTimeout(USE_MANUAL_INPUT ? 300000 : 60000); // 5 minutes for manual, 1 minute for automatic

// Test user credentials - use timestamp to ensure uniqueness
const timestamp = Date.now();
const TEST_USER = {
  username: `testuser_${timestamp}`,
  email: `testuser_${timestamp}@example.com`,
  password: 'Password123!'
};

// Store tokens across tests
let accessToken: string;
let refreshToken: string;
let verificationToken: string;
let passwordResetToken: string;
let userId: string;

// Create readline interface for user input if manual mode is enabled
let readline: ReturnType<typeof createInterface> | null = null;

if (USE_MANUAL_INPUT) {
  readline = createInterface({
    input: process.stdin,
    output: process.stdout
  });
}

// Helper function to prompt for input
function prompt(question: string): Promise<string> {
  return new Promise((resolve) => {
    if (readline) {
      readline.question(question, (answer) => {
        resolve(answer);
      });
    } else {
      resolve(''); // Return empty string if not in manual mode
    }
  });
}

// Email response interface for MailHog API v1
interface MessageSummary {
  ID: string;
  From: {
    Relays: string[];
    Mailbox: string;
    Domain: string;
    Params: string;
  };
  To: Array<{
    Relays: string[];
    Mailbox: string;
    Domain: string;
    Params: string;
  }>;
  Content: {
    Headers: {
      "Content-Transfer-Encoding"?: string[];
      "Content-Type"?: string[];
      Date?: string[];
      From?: string[];
      "MIME-Version"?: string[];
      "Message-ID"?: string[];
      Received?: string[];
      "Return-Path"?: string[];
      Subject?: string[];
      To?: string[];
    };
    Body: string;
    Size: number;
  };
  Created: string;
  MIME: any;
  Raw: {
    From: string;
    To: string[];
    Data: string;
    Helo: string;
  };
}

interface MessagesResponse {
  total: number;
  count: number;
  start: number;
  items: Array<{
    ID: string;
    From: {
      Relays: string[];
      Mailbox: string;
      Domain: string;
      Params: string;
    };
    To: Array<{
      Relays: string[];
      Mailbox: string;
      Domain: string;
      Params: string;
    }>;
    Content: {
      Headers: {
        "Content-Transfer-Encoding"?: string[];
        "Content-Type"?: string[];
        Date?: string[];
        From?: string[];
        "MIME-Version"?: string[];
        "Message-ID"?: string[];
        Received?: string[];
        "Return-Path"?: string[];
        Subject?: string[];
        To?: string[];
      };
      Body: string;
      Size: number;
    };
    Created: string;
    MIME: any;
  }>;
}

// Function to check if MailHog is running
async function checkMailHogConnection(): Promise<boolean> {
  try {
    const response = await axios.get(`${MAILHOG_API}/messages`);
    console.log('MailHog is connected and running');
    return true;
  } catch (error) {
    console.error('MailHog connection failed:', error instanceof Error ? error.message : String(error));
    return false;
  }
}

// Function to get all messages from MailHog
async function getMessages(): Promise<MessagesResponse> {
  const response = await axios.get<MessagesResponse>(`${MAILHOG_API}/messages`);
  return response.data;
}

// Function to get a specific message by ID
async function getMessage(messageId: string): Promise<MessageSummary> {
  const response = await axios.get<MessageSummary>(`${MAILHOG_API}/messages/${messageId}`);
  return response.data;
}

// Helper to wait with exponential backoff
async function wait(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Manually delete all messages
async function deleteAllMessages(): Promise<void> {
  try {
    await axios.delete(`${MAILHOG_API}/messages`);
    console.log('Deleted all messages from MailHog');
  } catch (error) {
    console.error('Failed to delete messages:', error instanceof Error ? error.message : String(error));
  }
}

// Function to automatically extract verification code from emails
async function autoExtractVerificationCode(): Promise<string | null> {
  let emailFound = false;
  let verificationCode = '';
  let attempts = 0;
  const maxAttempts = 15;
  
  console.log('Waiting for verification email...');
  
  while (!emailFound && attempts < maxAttempts) {
    attempts++;
    await wait(2000 * attempts); // Increase wait time with each attempt
    
    // Get messages
    const messagesResponse = await getMessages();
    console.log(`Attempt ${attempts}: Found ${messagesResponse.count} messages`);
    
    if (messagesResponse.items && messagesResponse.items.length > 0) {
      // Check each message
      for (const messageSummary of messagesResponse.items) {
        // Get full message details
        const message = await getMessage(messageSummary.ID);
        
        // Check if this is an email to our test user
        const toHeader = message.Content.Headers.To?.[0] || '';
        const fromHeader = message.Content.Headers.From?.[0] || '';
        const subjectHeader = message.Content.Headers.Subject?.[0] || '';
        
        if (toHeader.includes(TEST_USER.email) && subjectHeader.includes('Verify')) {
          emailFound = true;
          console.log('Found verification email:');
          console.log(`From: ${fromHeader}`);
          console.log(`To: ${toHeader}`);
          console.log(`Subject: ${subjectHeader}`);
          
          // Get full message body
          const fullMessage = await getMessage(message.ID);
          const emailBody = fullMessage.Content.Body;
          
          // Extract verification code - looking for 3-character code
          // Adjust this regex based on your actual email format
          const codeMatch = emailBody.match(/([A-Z0-9]{3})/);
          if (codeMatch && codeMatch[1]) {
            verificationCode = codeMatch[1];
            console.log(`Found verification code: ${verificationCode}`);
            break;
          } else {
            console.log('Verification code not found in email body');
            console.log('Email body snippet:', emailBody.substring(0, 200) + '...');
          }
        }
      }
    }
  }
  
  return emailFound ? verificationCode : null;
}

// Function to automatically extract password reset token from emails
async function autoExtractResetToken(): Promise<string | null> {
  let emailFound = false;
  let resetToken = '';
  let attempts = 0;
  const maxAttempts = 15;
  
  console.log('Waiting for password reset email...');
  
  while (!emailFound && attempts < maxAttempts) {
    attempts++;
    await wait(2000 * attempts); // Increase wait time with each attempt
    
    // Get messages
    const messagesResponse = await getMessages();
    console.log(`Attempt ${attempts}: Found ${messagesResponse.count} messages`);
    
    if (messagesResponse.items && messagesResponse.items.length > 0) {
      // Look at most recent messages first (reverse the array)
      const recentMessages = [...messagesResponse.items].reverse();
      
      // Check each message
      for (const messageSummary of recentMessages) {
        // Get full message details
        const message = await getMessage(messageSummary.ID);
        
        // Check if this is a password reset email to our test user
        const toHeader = message.Content.Headers.To?.[0] || '';
        const subjectHeader = message.Content.Headers.Subject?.[0] || '';
        
        if (toHeader.includes(TEST_USER.email) && subjectHeader.includes('Reset')) {
          emailFound = true;
          console.log('Found password reset email');
          
          // Get full message body
          const emailBody = message.Content.Body;
          
          // Extract reset token from URL in email
          // Adjust this regex based on your actual email format
          const tokenMatch = emailBody.match(/reset-password\?token=([a-f0-9]+)/);
          if (tokenMatch && tokenMatch[1]) {
            resetToken = tokenMatch[1];
            console.log(`Found reset token: ${resetToken.substring(0, 10)}...`);
            break;
          } else {
            console.log('Reset token not found in email body');
            console.log('Email body snippet:', emailBody.substring(0, 200) + '...');
          }
        }
      }
    }
  }
  
  return emailFound ? resetToken : null;
}

// Connect to MongoDB and clean up test data
let connection: MongoClient | null = null;
let db: Db | null = null;

beforeAll(async () => {
  // Connect to MongoDB
  connection = await MongoClient.connect(MONGODB_URI);
  db = connection.db();
  
  // Clear existing test data before starting
  if (db) {
    await db.collection('users').deleteMany({ email: { $regex: /^testuser_/ } });
  }
  
  // Verify MailHog connection
  const mailhogRunning = await checkMailHogConnection();
  if (!mailhogRunning) {
    throw new Error('MailHog is not running. Please start MailHog before running tests.');
  }
  
  // Clear all emails in MailHog
  await deleteAllMessages();
  
  if (USE_MANUAL_INPUT) {
    console.log(`\n====== STARTING INTERACTIVE AUTH TESTS ======`);
    console.log(`Test User: ${TEST_USER.username}`);
    console.log(`Test Email: ${TEST_USER.email}`);
    console.log(`\nPlease keep MailHog UI open at http://localhost:8025 to view emails\n`);
  }
});

afterAll(async () => {
  // Clean up test user data after tests
  if (db) {
    try {
      await db.collection('users').deleteMany({ email: TEST_USER.email });
      console.log('Cleaned up test user data');
    } catch (error) {
      console.error('Error cleaning up test data:', error);
    }
  }
  
  if (connection) {
    await connection.close();
    console.log('MongoDB connection closed');
  }
  
  // Close readline interface if it was opened
  if (readline) {
    readline.close();
  }
  
  if (USE_MANUAL_INPUT) {
    console.log('\n====== INTERACTIVE TESTS COMPLETED ======\n');
  }
});

describe('Authentication Flow Tests', () => {
  // Test 1: Sign Up
  test('should register a new user', async () => {
    console.log(`Registering user: ${TEST_USER.username} with email: ${TEST_USER.email}`);
    
    const response = await request(API_URL)
      .post('/auth/signup')
      .send(TEST_USER);
    
    expect(response.status).toBe(201);
    expect(response.body).toHaveProperty('message');
    expect(response.body).toHaveProperty('userId');
    
    userId = response.body.userId;
    console.log('Sign Up Response:', response.body);
  });
  
  // Test 2: Check for verification email and verify email
  test('should receive verification email and verify email', async () => {
    let verificationCode = '';
    
    // Either get manual input or try automatic extraction
    if (USE_MANUAL_INPUT) {
      console.log('\n📧 Check MailHog UI at http://localhost:8025');
      console.log(`Look for a verification email sent to: ${TEST_USER.email}`);
      console.log('The verification code is typically a 3-character alphanumeric code');
      
      verificationCode = await prompt('\nEnter the verification code from the email: ');
      console.log(`Using verification code: ${verificationCode}`);
    } else {
      const extractedCode = await autoExtractVerificationCode();
      
      if (!extractedCode) {
        // If we can't auto-extract, prompt the user
        console.log('\n📧 Automatic code extraction failed. Please check MailHog UI at http://localhost:8025');
        console.log(`Look for a verification email sent to: ${TEST_USER.email}`);
        
        verificationCode = await prompt('\nEnter the verification code from the email: ');
      } else {
        verificationCode = extractedCode;
      }
    }
    
    expect(verificationCode).toBeTruthy();
    verificationToken = verificationCode;
    
    // Verify email using the token
    const response = await request(API_URL)
      .post('/auth/verify-email')
      .send({ token: verificationToken });
    
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('message', 'Email verified successfully');
    console.log('✅ Email verified successfully');
  });
  
  // Test 3: Login
  test('should login with verified credentials', async () => {
    const response = await request(API_URL)
      .post('/auth/login')
      .send({
        username: TEST_USER.username,
        password: TEST_USER.password
      });
    
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('accessToken');
    expect(response.body).toHaveProperty('refreshToken');
    
    accessToken = response.body.accessToken;
    refreshToken = response.body.refreshToken;
    
    console.log('✅ Login successful');
  });
  
  // Test 4: Access Protected Route
  test('should access protected profile endpoint', async () => {
    const response = await request(API_URL)
      .get('/profile')
      .set('Authorization', `Bearer ${accessToken}`);
    
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('user');
    
    console.log('✅ Successfully accessed protected route');
  });
  
  // Test 5: Refresh Token
  test('should refresh access token', async () => {
    const response = await request(API_URL)
      .post('/auth/refresh')
      .send({ refreshToken });
    
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('accessToken');
    
    // Update access token for future tests
    accessToken = response.body.accessToken;
    
    console.log('✅ Successfully refreshed token');
  });
  
  // Test 6: Forgot Password
  test('should request password reset', async () => {
    // Request password reset
    const response = await request(API_URL)
      .post('/auth/forgot-password')
      .send({ email: TEST_USER.email });
    
    expect(response.status).toBe(200);
    console.log('✅ Password reset requested');
    
    let resetToken = '';
    
    // Either get manual input or try automatic extraction
    if (USE_MANUAL_INPUT) {
      console.log('\n📧 Check MailHog UI for the password reset email');
      console.log(`Look for a reset email sent to: ${TEST_USER.email}`);
      console.log('Find the reset token in the reset password link');
      console.log('The link should look like: /reset-password?token=SOME_LONG_TOKEN');
      
      resetToken = await prompt('\nEnter the reset token from the email: ');
      console.log(`Using reset token: ${resetToken.substring(0, 10)}...`);
    } else {
      const extractedToken = await autoExtractResetToken();
      
      if (!extractedToken) {
        // If we can't auto-extract, prompt the user
        console.log('\n📧 Automatic token extraction failed. Please check MailHog UI at http://localhost:8025');
        console.log(`Look for a reset email sent to: ${TEST_USER.email}`);
        
        resetToken = await prompt('\nEnter the reset token from the email: ');
      } else {
        resetToken = extractedToken;
      }
    }
    
    expect(resetToken).toBeTruthy();
    passwordResetToken = resetToken;
  });
  
  // Test 7: Reset Password
  test('should reset password with token', async () => {
    const newPassword = 'NewPassword123!';
    
    const response = await request(API_URL)
      .post('/auth/reset-password')
      .send({
        token: passwordResetToken,
        newPassword
      });
    
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('message', 'Password reset successful');
    
    console.log('✅ Password reset successful');
    
    // Login with new password to verify it was changed
    const loginResponse = await request(API_URL)
      .post('/auth/login')
      .send({
        username: TEST_USER.username,
        password: newPassword
      });
    
    expect(loginResponse.status).toBe(200);
    expect(loginResponse.body).toHaveProperty('accessToken');
    console.log('✅ Successfully logged in with new password');
  });
  
  // Test 8: Logout
  test('should logout user', async () => {
    const response = await request(API_URL)
      .post('/auth/logout')
      .send({ refreshToken });
    
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('message', 'Logout successful');
    
    console.log('✅ Logout successful');
  });
});