// src/auth/token.service.ts
import jwt, { SignOptions, Secret } from 'jsonwebtoken';
import { Token } from '../models/token.model';
import { Types } from 'mongoose';
import { logger } from '../utils/logger';
import { UserRole } from '../models/user.model';

export interface TokenPayload {
  sub: string;
  username: string;
  type: 'access' | 'refresh';
  role: UserRole;
}

/**
 * TokenService class handles the generation, verification, and management of JWT tokens.
 * It provides methods for creating access and refresh tokens, verifying them, and managing
 * refresh tokens in the database.
 */
export class TokenService {
  /**
   * Generate an access token for a user.
   * 
   * @param userId - The unique identifier of the user.
   * @param username - The username of the user.
   * @param role - The role of the user.
   * @returns A JWT access token string.
   */
  generateAccessToken(userId: string, username: string, role: UserRole): string {
    // Retrieve the secret key for access tokens from environment variables or use a default value
    const secretString = process.env.JWT_ACCESS_SECRET || 'access_secret';
    // Convert the secret string to a Buffer for use with JWT
    const secret = Buffer.from(secretString, 'utf8');
    // Set the expiration time for the access token, defaulting to 15 minutes if not specified
    const expiresIn = process.env.JWT_ACCESS_EXPIRES_IN || '15m';
    
    // Create the payload for the access token
    const payload: TokenPayload = { sub: userId, username, type: 'access', role };
    // Set the expiration option for the JWT
    const options = { expiresIn } as jwt.SignOptions;
    
    // Sign and return the JWT access token
    return jwt.sign(payload, secret, options);
  }

  /**
   * Generate a refresh token for a user and store it in the database.
   * 
   * @param userId - The unique identifier of the user.
   * @param username - The username of the user.
   * @param role - The role of the user.
   * @returns A Promise that resolves to a JWT refresh token string.
   */
  async generateRefreshToken(userId: string, username: string, role: UserRole): Promise<string> {
    // Retrieve the secret key for refresh tokens from environment variables or use a default value
    const secretString = process.env.JWT_REFRESH_SECRET || 'refresh_secret';
    // Convert the secret string to a Buffer for use with JWT
    const secret = Buffer.from(secretString, 'utf8');
    // Set the expiration time for the refresh token, defaulting to 7 days if not specified
    const expiresIn = process.env.JWT_REFRESH_EXPIRES_IN || '7d';
    
    // Calculate the expiry date for the refresh token
    const expiresInMs = expiresIn.endsWith('d')
      ? parseInt(expiresIn) * 24 * 60 * 60 * 1000
      : parseInt(expiresIn) * 60 * 1000;
    
    const expires = new Date(Date.now() + expiresInMs);
    
    // Create the payload for the refresh token
    const payload: TokenPayload = { sub: userId, username, type: 'refresh', role };
    // Set the expiration option for the JWT
    const options = { expiresIn } as jwt.SignOptions;
    
    // Sign and generate the JWT refresh token
    const refreshToken = jwt.sign(payload, secret, options);
    
    // Store the refresh token in the database
    await Token.create({
      userId: new Types.ObjectId(userId),
      refreshToken,
      expires
    });
    
    // Return the generated refresh token
    return refreshToken;
  }

  /**
   * Verify the validity of an access token.
   * 
   * @param token - The JWT access token to verify.
   * @returns The decoded TokenPayload if valid, null otherwise.
   */
  verifyAccessToken(token: string): TokenPayload | null {
    try {
      // Retrieve the secret key for access tokens from environment variables or use a default value
      const secretString = process.env.JWT_ACCESS_SECRET || 'access_secret';
      // Convert the secret string to a Buffer for use with JWT
      const secret = Buffer.from(secretString, 'utf8');
      // Verify the token and cast the result to TokenPayload
      const decoded = jwt.verify(token, secret) as TokenPayload;
      
      // Check if the token type is 'access'
      if (decoded.type !== 'access') {
        return null;
      }
      
      // Return the decoded payload if valid
      return decoded;
    } catch (error) {
      // Log any errors that occur during verification
      logger.error('Access token verification error:', error);
      return null;
    }
  }

  /**
   * Verify the validity of a refresh token and check its existence in the database.
   * 
   * @param token - The JWT refresh token to verify.
   * @returns A Promise that resolves to the decoded TokenPayload if valid, null otherwise.
   */
  async verifyRefreshToken(token: string): Promise<TokenPayload | null> {
    try {
      // Retrieve the secret key for refresh tokens from environment variables or use a default value
      const secretString = process.env.JWT_REFRESH_SECRET || 'refresh_secret';
      // Convert the secret string to a Buffer for use with JWT
      const secret = Buffer.from(secretString, 'utf8');
      // Verify the token and cast the result to TokenPayload
      const decoded = jwt.verify(token, secret) as TokenPayload;
      
      // Check if the token type is 'refresh'
      if (decoded.type !== 'refresh') {
        return null;
      }
      
      // Check if the token exists in the database and is still valid
      const tokenRecord = await Token.findOne({
        userId: new Types.ObjectId(decoded.sub),
        refreshToken: token,
        expires: { $gt: new Date() }
      });
      
      // If no valid token record is found, return null
      if (!tokenRecord) {
        return null;
      }
      
      // Return the decoded payload if valid
      return decoded;
    } catch (error) {
      // Log any errors that occur during verification
      logger.error('Refresh token verification error:', error);
      return null;
    }
  }

  /**
   * Delete a specific refresh token from the database.
   * 
   * @param token - The refresh token to delete.
   * @returns A Promise that resolves to true if the token was successfully deleted, false otherwise.
   */
  async deleteRefreshToken(token: string): Promise<boolean> {
    try {
      // Attempt to delete the refresh token from the database
      const result = await Token.deleteOne({ refreshToken: token });
      // Return true if at least one document was deleted, false otherwise
      return result.deletedCount > 0;
    } catch (error) {
      // Log any errors that occur during deletion
      logger.error('Delete refresh token error:', error);
      return false;
    }
  }

  /**
   * Delete all refresh tokens associated with a specific user from the database.
   * 
   * @param userId - The unique identifier of the user whose tokens should be deleted.
   * @returns A Promise that resolves to true if at least one token was successfully deleted, false otherwise.
   */
  async deleteAllUserRefreshTokens(userId: string): Promise<boolean> {
    try {
      // Attempt to delete all refresh tokens for the specified user from the database
      const result = await Token.deleteMany({ userId: new Types.ObjectId(userId) });
      // Return true if at least one document was deleted, false otherwise
      return result.deletedCount > 0;
    } catch (error) {
      // Log any errors that occur during deletion
      logger.error('Delete all refresh tokens error:', error);
      return false;
    }
  }
}

export const tokenService = new TokenService();
