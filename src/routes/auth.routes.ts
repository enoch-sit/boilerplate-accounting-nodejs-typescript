// src/routes/auth.routes.ts
import { Router, Request, Response } from 'express';
import { authService } from '../auth/auth.service';
import { passwordService } from '../services/password.service';
import { authenticate } from '../auth/auth.middleware';
import { logger } from '../utils/logger';

const router = Router();

// Register a new user
router.post('/signup', async (req: Request, res: Response) => {
  try {
    const { username, email, password } = req.body;
    
    if (!username || !email || !password) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    
    const result = await authService.signup(username, email, password);
    
    if (!result.success) {
      return res.status(400).json({ error: result.message });
    }
    
    res.status(201).json({
      message: result.message,
      userId: result.userId
    });
  } catch (error: any) {
    logger.error(`Signup error: ${error.message}`);
    res.status(500).json({ error: 'Registration failed' });
  }
});

// Verify email with confirmation code
router.post('/verify-email', async (req: Request, res: Response) => {
  try {
    const { token } = req.body;
    
    if (!token) {
      return res.status(400).json({ error: 'Token is required' });
    }
    
    const verified = await authService.verifyEmail(token);
    
    if (!verified) {
      return res.status(400).json({ error: 'Email verification failed' });
    }
    
    res.status(200).json({ message: 'Email verified successfully' });
  } catch (error: any) {
    logger.error(`Verify email error: ${error.message}`);
    res.status(500).json({ error: 'Email verification failed' });
  }
});

// Resend verification code
router.post('/resend-verification', async (req: Request, res: Response) => {
  try {
    const { email } = req.body;
    
    if (!email) {
      return res.status(400).json({ error: 'Email is required' });
    }
    
    const sent = await authService.resendVerificationCode(email);
    
    if (!sent) {
      return res.status(400).json({ error: 'Failed to resend verification code' });
    }
    
    res.status(200).json({ message: 'Verification code resent' });
  } catch (error: any) {
    logger.error(`Resend verification error: ${error.message}`);
    res.status(500).json({ error: 'Failed to resend verification code' });
  }
});

// Login
router.post('/login', async (req: Request, res: Response) => {
  try {
    const { username, password } = req.body;
    
    if (!username || !password) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    
    const result = await authService.login(username, password);
    
    if (!result.success) {
      return res.status(401).json({ error: result.message });
    }
    
    // Set HTTP-only cookie with access token
    if (result.accessToken) {
      res.cookie('accessToken', result.accessToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        maxAge: 15 * 60 * 1000 // 15 minutes
      });
    }
    
    // Set HTTP-only cookie with refresh token
    if (result.refreshToken) {
      res.cookie('refreshToken', result.refreshToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        path: '/api/auth/refresh',
        maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
      });
    }
    
    res.status(200).json({
      message: result.message,
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      user: result.user
    });
  } catch (error: any) {
    logger.error(`Login error: ${error.message}`);
    res.status(500).json({ error: 'Login failed' });
  }
});

// Refresh token
router.post('/refresh', async (req: Request, res: Response) => {
  try {
    // Get refresh token from cookie or request body
    const refreshToken = req.cookies.refreshToken || req.body.refreshToken;
    
    if (!refreshToken) {
      return res.status(400).json({ error: 'Refresh token is required' });
    }
    
    const result = await authService.refreshToken(refreshToken);
    
    if (!result.success) {
      return res.status(401).json({ error: result.message });
    }
    
    // Set HTTP-only cookie with new access token
    if (result.accessToken) {
      res.cookie('accessToken', result.accessToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        maxAge: 15 * 60 * 1000 // 15 minutes
      });
    }
    
    res.status(200).json({
      message: result.message,
      accessToken: result.accessToken
    });
  } catch (error: any) {
    logger.error(`Token refresh error: ${error.message}`);
    res.status(500).json({ error: 'Token refresh failed' });
  }
});

// Logout
router.post('/logout', async (req: Request, res: Response) => {
  try {
    // Get refresh token from cookie or request body
    const refreshToken = req.cookies.refreshToken || req.body.refreshToken;
    
    if (refreshToken) {
      await authService.logout(refreshToken);
    }
    
    // Clear cookies
    res.clearCookie('accessToken');
    res.clearCookie('refreshToken', { path: '/api/auth/refresh' });
    
    res.status(200).json({ message: 'Logout successful' });
  } catch (error: any) {
    logger.error(`Logout error: ${error.message}`);
    res.status(500).json({ error: 'Logout failed' });
  }
});

// Logout from all devices
router.post('/logout-all', authenticate, async (req: Request, res: Response) => {
  try {
    const userId = req.user?.userId;
    
    if (!userId) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    
    await authService.logoutAll(userId);
    
    // Clear cookies
    res.clearCookie('accessToken');
    res.clearCookie('refreshToken', { path: '/api/auth/refresh' });
    
    res.status(200).json({ message: 'Logged out from all devices' });
  } catch (error: any) {
    logger.error(`Logout all error: ${error.message}`);
    res.status(500).json({ error: 'Logout failed' });
  }
});

// Request password reset
router.post('/forgot-password', async (req: Request, res: Response) => {
  try {
    const { email } = req.body;
    
    if (!email) {
      return res.status(400).json({ error: 'Email is required' });
    }
    
    await passwordService.generateResetToken(email);
    
    // Always return success to prevent email enumeration
    res.status(200).json({
      message: 'If your email exists in our system, you will receive a password reset link'
    });
  } catch (error: any) {
    logger.error(`Forgot password error: ${error.message}`);
    // Still return success to prevent email enumeration
    res.status(200).json({
      message: 'If your email exists in our system, you will receive a password reset link'
    });
  }
});

// Reset password
router.post('/reset-password', async (req: Request, res: Response) => {
  try {
    const { token, newPassword } = req.body;
    
    if (!token || !newPassword) {
      return res.status(400).json({ error: 'Token and new password are required' });
    }
    
    const success = await passwordService.resetPassword(token, newPassword);
    
    if (!success) {
      return res.status(400).json({ error: 'Password reset failed' });
    }
    
    res.status(200).json({ message: 'Password reset successful' });
  } catch (error: any) {
    logger.error(`Reset password error: ${error.message}`);
    res.status(500).json({ error: 'Password reset failed' });
  }
});

export default router;