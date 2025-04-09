// tests/email.test.ts
import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';
import request from 'supertest';
import nodemailer from 'nodemailer';
import { Verification, VerificationType } from '../src/models/verification.model';
import { User } from '../src/models/user.model';
import axios from 'axios';

// Mock the database connection to prevent app from connecting to real MongoDB
jest.mock('../src/config/db.config', () => ({
  connectDB: jest.fn().mockResolvedValue(true)
}));

// Mock nodemailer
jest.mock('nodemailer');

// Need to declare app variable before import to avoid type errors
let app: any;

// Create mock for the email transporter
const mockTransporter = {
  sendMail: jest.fn().mockResolvedValue({
    messageId: 'test-message-id'
  }),
  verify: jest.fn().mockResolvedValue(true)
};

// Mock email config to return our mock transporter
jest.mock('../src/config/email.config', () => ({
  initializeEmailTransporter: jest.fn(),
  getEmailTransporter: jest.fn().mockReturnValue(mockTransporter)
}));

// Set environment variables for testing
process.env.NODE_ENV = 'test';
process.env.JWT_ACCESS_SECRET = 'test-secret';
process.env.JWT_REFRESH_SECRET = 'test-secret';

// Configuration for tests
const MAILHOG_API = process.env.MAILHOG_API || 'http://localhost:8025';
const TEST_USER_EMAIL = 'test@example.com';
const TEST_USER_PASSWORD = 'TestPassword123!';

describe('Email Verification Tests with MailHog', () => {
  let mongoServer: MongoMemoryServer;
  let testUserId: string;
  
  // Setup function to run before all tests
  beforeAll(async () => {
    // Create in-memory MongoDB instance
    mongoServer = await MongoMemoryServer.create();
    process.env.MONGODB_URI = mongoServer.getUri();
    
    // Connect mongoose to the in-memory database
    await mongoose.connect(mongoServer.getUri());
    
    // Import app after mocking dependencies
    app = require('../src/app').default;
  });
  
  // Cleanup after all tests
  afterAll(async () => {
    // Disconnect and close the in-memory MongoDB instance
    if (mongoose.connection) await mongoose.disconnect();
    if (mongoServer) await mongoServer.stop();
  });
  
  // Clear database and reset mocks between tests
  beforeEach(async () => {
    // Clear collections
    await User.deleteMany({});
    await Verification.deleteMany({});
    
    // Reset mock call history
    mockTransporter.sendMail.mockClear();
    
    // Clear MailHog messages if available
    try {
      await axios.delete(`${MAILHOG_API}/api/v1/messages`);
    } catch (error) {
      // If MailHog is not available, just continue with the test
      console.warn('MailHog not available. Testing will continue without clearing messages.');
    }
  });
  
  // Test 1: User registration sends verification email
  test('User registration sends verification email to MailHog', async () => {
    // Register new user
    const response = await request(app)
      .post('/api/auth/signup')
      .send({
        username: 'mailhogtest',
        email: TEST_USER_EMAIL,
        password: TEST_USER_PASSWORD
      });
    
    expect(response.status).toBe(201);
    expect(response.body).toHaveProperty('userId');
    testUserId = response.body.userId;
    
    // Verify email sending was triggered
    expect(mockTransporter.sendMail).toHaveBeenCalled();
    
    // Check email was sent with correct data
    const emailCalls = mockTransporter.sendMail.mock.calls;
    const sentEmail = emailCalls.find((call: any) => call[0].to === TEST_USER_EMAIL);
    
    expect(sentEmail).toBeDefined();
    expect(sentEmail[0].subject).toContain('Verify');
    expect(sentEmail[0].html).toContain('verify');
    
    // Verify a verification record was created in database
    const verification = await Verification.findOne({ 
      userId: testUserId,
      type: VerificationType.EMAIL
    });
    
    expect(verification).toBeDefined();
    expect(verification).toHaveProperty('token');
  });
  
  // Test 2: Email verification flow with token from database
  test('Email verification flow works with token from database', async () => {
    // Register new user
    const signupResponse = await request(app)
      .post('/api/auth/signup')
      .send({
        username: 'verifytest',
        email: 'verify@example.com',
        password: TEST_USER_PASSWORD
      });
    
    expect(signupResponse.status).toBe(201);
    testUserId = signupResponse.body.userId;
    
    // Get verification token from database
    const verification = await Verification.findOne({
      userId: testUserId,
      type: VerificationType.EMAIL
    });
    
    expect(verification).toBeDefined();
    expect(verification).toHaveProperty('token');
    
    // Verify email with token
    const verifyResponse = await request(app)
      .post('/api/auth/verify-email')
      .send({
        token: verification!.token
      });
    
    expect(verifyResponse.status).toBe(200);
    
    // Check user is now verified
    const user = await User.findById(testUserId);
    expect(user).toBeDefined();
    expect(user!.isVerified).toBe(true);
    
    // Try to login with verified account
    const loginResponse = await request(app)
      .post('/api/auth/login')
      .send({
        username: 'verifytest',
        password: TEST_USER_PASSWORD
      });
    
    expect(loginResponse.status).toBe(200);
    expect(loginResponse.body).toHaveProperty('accessToken');
  });
  
  // Test 3: Password reset flow
  test('Password reset flow with MailHog', async () => {
    // Create and verify a user first
    const user = new User({
      username: 'resettest',
      email: 'reset@example.com',
      password: TEST_USER_PASSWORD,
      isVerified: true
    });
    
    await user.save();
    
    // Request password reset
    const forgotResponse = await request(app)
      .post('/api/auth/forgot-password')
      .send({
        email: 'reset@example.com'
      });
    
    expect(forgotResponse.status).toBe(200);
    
    // Verify reset email was sent
    expect(mockTransporter.sendMail).toHaveBeenCalled();
    const emailCalls = mockTransporter.sendMail.mock.calls;
    const resetEmail = emailCalls.find((call: any) => 
      call[0].to === 'reset@example.com' && 
      call[0].subject.includes('Reset')
    );
    expect(resetEmail).toBeDefined();
    
    // Get reset token from database
    const resetVerification = await Verification.findOne({
      userId: user._id,
      type: VerificationType.PASSWORD_RESET
    });
    
    expect(resetVerification).toBeDefined();
    expect(resetVerification).toHaveProperty('token');
    
    // Reset password
    const newPassword = 'NewPassword456!';
    const resetResponse = await request(app)
      .post('/api/auth/reset-password')
      .send({
        token: resetVerification!.token,
        newPassword
      });
    
    expect(resetResponse.status).toBe(200);
    
    // Try to login with new password
    const loginResponse = await request(app)
      .post('/api/auth/login')
      .send({
        username: 'resettest',
        password: newPassword
      });
    
    expect(loginResponse.status).toBe(200);
    expect(loginResponse.body).toHaveProperty('accessToken');
  });
});