// src/services/password.service.ts
import crypto from 'crypto';
import { User } from '../models/user.model';
import { Verification, VerificationType } from '../models/verification.model';
import { emailService } from './email.service';
import { logger } from '../utils/logger';

export class PasswordService {
  /**
   * Generate a password reset token and send reset email
   */
  async generateResetToken(email: string): Promise<boolean> {
    try {
      // Find user by email
      const user = await User.findOne({ email });
      
      // If user doesn't exist, return true to prevent email enumeration
      if (!user) {
        logger.warn(`Password reset requested for non-existent email: ${email}`);
        return true;
      }
      
      // Delete any existing reset tokens for this user
      await Verification.deleteMany({
        userId: user._id,
        type: VerificationType.PASSWORD_RESET
      });
      
      // Generate reset token
      const token = crypto.randomBytes(32).toString('hex');
      
      // Set token expiration
      const expiresIn = process.env.PASSWORD_RESET_EXPIRES_IN || '1h';
      const expiresInMs = expiresIn.endsWith('h')
        ? parseInt(expiresIn) * 60 * 60 * 1000
        : parseInt(expiresIn) * 60 * 1000;
      
      // Save reset token
      await Verification.create({
        userId: user._id,
        type: VerificationType.PASSWORD_RESET,
        token,
        expires: new Date(Date.now() + expiresInMs)
      });
      
      // Send password reset email
      await emailService.sendPasswordResetEmail(
        user.email,
        user.username,
        token
      );
      
      logger.info(`Password reset token generated for user: ${user.username}`);
      return true;
    } catch (error) {
      logger.error('Generate reset token error:', error);
      return false;
    }
  }

  /**
   * Reset password using token
   */
  async resetPassword(token: string, newPassword: string): Promise<boolean> {
    try {
      // Find the verification record
      const verification = await Verification.findOne({
        token,
        type: VerificationType.PASSWORD_RESET,
        expires: { $gt: new Date() }
      });
      
      if (!verification) {
        logger.warn('Invalid or expired password reset token');
        return false;
      }
      
      // Find the user
      const user = await User.findById(verification.userId);
      if (!user) {
        logger.error(`User not found for reset token: ${token}`);
        return false;
      }
      
      // Update password
      user.password = newPassword; // Will be hashed by the pre-save hook
      await user.save();
      
      // Delete the verification record
      await Verification.deleteOne({ _id: verification._id });
      
      // Delete all refresh tokens for this user (force logout from all devices)
      // This would require importing the tokenService, which might create a circular dependency
      // Instead, we'll handle this in the route handler
      
      logger.info(`Password reset successful for user: ${user.username}`);
      return true;
    } catch (error) {
      logger.error('Reset password error:', error);
      return false;
    }
  }
}

export const passwordService = new PasswordService();
