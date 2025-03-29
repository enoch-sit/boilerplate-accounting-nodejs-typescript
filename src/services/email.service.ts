// src/services/email.service.ts
import nodemailer from 'nodemailer';
import { getEmailTransporter } from '../config/email.config';
import { logger } from '../utils/logger';

/**
 * EmailService class handles sending verification and password reset emails.
 */
export class EmailService {
  /**
   * Sends a verification email to the specified email address with a verification code.
   * @param email - The recipient's email address.
   * @param username - The username of the recipient.
   * @param verificationCode - The verification code to be included in the email.
   * @returns A promise that resolves to true if the email was sent successfully, false otherwise.
   */
  async sendVerificationEmail(
    email: string,
    username: string,
    verificationCode: string
  ): Promise<boolean> {
    try {
    // Get the email transporter configured in email.config.ts
    const transporter = getEmailTransporter();
    // Set the frontend URL, defaulting to localhost if not specified in environment variables
    const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:3000';
      
    // Configure the email options
    const mailOptions = {
      from: process.env.EMAIL_FROM || 'noreply@example.com',
      to: email,
      subject: 'Verify Your Email',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2>Hello ${username},</h2>
          <p>Thank you for registering. Please use the following code to verify your email address:</p>
          <div style="background-color: #f4f4f4; padding: 10px; text-align: center; font-size: 24px; letter-spacing: 5px; font-weight: bold;">
            ${verificationCode}
          </div>
          <p>This code will expire in 15 minutes.</p>
          <p>If you didn't request this, please ignore this email.</p>
          <p>Best regards,<br>The Team</p>
        </div>
      `
    };
      
    // Send the email using the transporter
    await transporter.sendMail(mailOptions);
    // Log the successful sending of the verification email
    logger.info(`Verification email sent to ${email}`);
    return true;
    } catch (error) {
    // Log any errors that occurred while sending the verification email
    logger.error('Error sending verification email:', error);
    return false;
    }
  }

  /**
   * Sends a password reset email to the specified email address with a reset token.
   * @param email - The recipient's email address.
   * @param username - The username of the recipient.
   * @param resetToken - The reset token to be included in the email.
   * @returns A promise that resolves to true if the email was sent successfully, false otherwise.
   */
  async sendPasswordResetEmail(
    email: string,
    username: string,
    resetToken: string
  ): Promise<boolean> {
    try {
    // Get the email transporter configured in email.config.ts
    const transporter = getEmailTransporter();
    // Set the frontend URL, defaulting to localhost if not specified in environment variables
    const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:3000';
    // Construct the password reset link
    const resetLink = `${frontendUrl}/reset-password?token=${resetToken}`;
      
    // Configure the email options
    const mailOptions = {
      from: process.env.EMAIL_FROM || 'noreply@example.com',
      to: email,
      subject: 'Reset Your Password',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2>Hello ${username},</h2>
          <p>We received a request to reset your password. Click the button below to reset it:</p>
          <div style="text-align: center; margin: 20px 0;">
            <a href="${resetLink}" style="background-color: #4CAF50; color: white; padding: 10px 20px; text-decoration: none; border-radius: 4px; display: inline-block;">Reset Password</a>
          </div>
          <p>Or copy and paste this link in your browser:</p>
          <p>${resetLink}</p>
          <p>This link will expire in 1 hour.</p>
          <p>If you didn't request this, please ignore this email and your password will remain unchanged.</p>
          <p>Best regards,<br>The Team</p>
        </div>
      `
    };
      
    // Send the email using the transporter
    await transporter.sendMail(mailOptions);
    // Log the successful sending of the password reset email
    logger.info(`Password reset email sent to ${email}`);
    return true;
    } catch (error) {
    // Log any errors that occurred while sending the password reset email
    logger.error('Error sending password reset email:', error);
    return false;
    }
  }
}

export const emailService = new EmailService();
