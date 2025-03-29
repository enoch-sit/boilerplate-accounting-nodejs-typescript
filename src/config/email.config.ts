// src/config/email.config.ts
// Import Nodemailer for email operations
import nodemailer from 'nodemailer';
// Import logger utility for logging email service status
import { logger } from '../utils/logger';

// Define the structure for email configuration
interface EmailConfig {
  service: string;
  host: string;
  port: number;
  secure: boolean;
  auth: {
    user: string;
    pass: string;
  };
}

// Variable to hold the email transporter instance
let transporter: nodemailer.Transporter;

// Function to initialize the email transporter based on environment
export const initializeEmailTransporter = (): void => {
  try {
    // Set up email configuration using environment variables with defaults
    const config: EmailConfig = {
      service: process.env.EMAIL_SERVICE || 'smtp',
      host: process.env.EMAIL_HOST || 'localhost',
      port: parseInt(process.env.EMAIL_PORT || '1025', 10),
      secure: process.env.NODE_ENV === 'production',
      auth: {
        user: process.env.EMAIL_USER || 'test',
        pass: process.env.EMAIL_PASS || 'test'
      }
    };

    // Special case for development - using MailHog or other local SMTP server
    if (process.env.NODE_ENV === 'development') {
      transporter = nodemailer.createTransport({
        host: config.host,
        port: config.port,
        secure: false,
        auth: {
          user: config.auth.user,
          pass: config.auth.pass
        },
        tls: {
          rejectUnauthorized: false
        }
      });
      // Log successful initialization in development mode
      logger.info('Email service initialized in development mode');
      return;
    }

    // Production setup
    transporter = nodemailer.createTransport({
      service: config.service,
      host: config.host,
      port: config.port,
      secure: config.secure,
      auth: {
        user: config.auth.user,
        pass: config.auth.pass
      }
    });

    // Log successful initialization in production mode
    logger.info('Email service initialized in production mode');
  } catch (error) {
    // Log any errors that occur during initialization
    logger.error('Email service initialization error:', error);
    // Exit the application if initialization fails
    process.exit(1);
  }
};

// Function to retrieve the initialized email transporter
export const getEmailTransporter = (): nodemailer.Transporter => {
  if (!transporter) {
    throw new Error('Email transporter not initialized');
  }
  return transporter;
};
