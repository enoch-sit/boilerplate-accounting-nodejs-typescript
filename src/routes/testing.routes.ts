// src/routes/testing.routes.ts
import { Router, Request, Response } from 'express';
import { Verification, VerificationType } from '../models/verification.model';
import { logger } from '../utils/logger';
import mongoose from 'mongoose';

// This router should ONLY be enabled in development/testing environments
const router = Router();

// Get verification token for a user (development/testing only)
router.get('/verification-token/:userId/:type?', async (req: Request, res: Response) => {
  try {
    const { userId } = req.params;
    const type = req.params.type || VerificationType.EMAIL;
    
    if (!userId) {
      return res.status(400).json({ error: 'User ID is required' });
    }
    
    // Validate that the userId is a valid ObjectId
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ error: 'Invalid user ID format' });
    }
    
    // Find the most recent verification token for this user and type
    const verification = await Verification.findOne({
      userId: new mongoose.Types.ObjectId(userId),
      type
    }).sort({ createdAt: -1 });
    
    if (!verification) {
      return res.status(404).json({ error: 'No verification token found for this user' });
    }
    
    res.status(200).json({
      token: verification.token,
      expires: verification.expires,
      type: verification.type
    });
  } catch (error: any) {
    logger.error(`Testing route error: ${error.message}`);
    res.status(500).json({ error: 'Failed to retrieve verification token' });
  }
});

// Directly verify a user's email without token (development/testing only)
router.post('/verify-user/:userId', async (req: Request, res: Response) => {
  try {
    const { userId } = req.params;
    
    if (!userId) {
      return res.status(400).json({ error: 'User ID is required' });
    }
    
    // Validate that the userId is a valid ObjectId
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({ error: 'Invalid user ID format' });
    }
    
    // Import User model dynamically to avoid circular dependencies
    const { User } = require('../models/user.model');
    
    // Find and update the user
    const user = await User.findByIdAndUpdate(
      userId,
      { isEmailVerified: true },
      { new: true }
    );
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Optionally: delete any pending verification tokens
    await Verification.deleteMany({
      userId: new mongoose.Types.ObjectId(userId),
      type: VerificationType.EMAIL
    });
    
    res.status(200).json({
      message: 'User email verified successfully',
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
        isEmailVerified: user.isEmailVerified
      }
    });
  } catch (error: any) {
    logger.error(`Testing route error: ${error.message}`);
    res.status(500).json({ error: 'Failed to verify user' });
  }
});

export default router;