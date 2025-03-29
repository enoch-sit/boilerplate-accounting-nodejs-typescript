// src/auth/auth.middleware.ts
import { Request, Response, NextFunction } from 'express';
import { tokenService } from './token.service';
import { logger } from '../utils/logger';

declare global {
  namespace Express {
    interface Request {
      user?: {
        userId: string;
        username: string;
      };
    }
  }
}

/**
 * Authentication middleware that verifies JWT tokens
 */
export const authenticate = (req: Request, res: Response, next: NextFunction) => {
  try {
    // Get token from header or cookie
    let token: string | undefined;
    
    // Check Authorization header
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      token = authHeader.substring(7);
    } 
    // Check cookie
    else if (req.cookies && req.cookies.accessToken) {
      token = req.cookies.accessToken;
    }
    
    if (!token) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    
    // Verify token
    const decoded = tokenService.verifyAccessToken(token);
    
    if (!decoded) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }
    
    // Attach user info to request
    req.user = {
      userId: decoded.sub,
      username: decoded.username
    };
    
    next();
  } catch (error) {
    logger.error('Authentication error:', error);
    return res.status(401).json({ error: 'Authentication failed' });
  }
};

/**
 * Check if user is authenticated but don't require authentication
 */
export const optionalAuth = (req: Request, res: Response, next: NextFunction) => {
  try {
    // Get token from header or cookie
    let token: string | undefined;
    
    // Check Authorization header
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      token = authHeader.substring(7);
    } 
    // Check cookie
    else if (req.cookies && req.cookies.accessToken) {
      token = req.cookies.accessToken;
    }
    
    if (token) {
      // Verify token
      const decoded = tokenService.verifyAccessToken(token);
      
      if (decoded) {
        // Attach user info to request
        req.user = {
          userId: decoded.sub,
          username: decoded.username
        };
      }
    }
    
    next();
  } catch (error) {
    // Just continue without authentication
    next();
  }
};