// src/routes/admin.routes.ts
import { Router, Request, Response } from 'express';
import { authenticate, requireAdmin, requireSupervisor } from '../auth/auth.middleware';
import { User, UserRole } from '../models/user.model';
import { logger } from '../utils/logger';

const router = Router();

// Get all users (admin only)
router.get('/users', authenticate, requireAdmin, async (req: Request, res: Response) => {
  try {
    const users = await User.find().select('-password');
    res.status(200).json({ users });
  } catch (error) {
    logger.error('Error fetching users:', error);
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

// Update user role (admin only)
router.put('/users/:userId/role', authenticate, requireAdmin, async (req: Request, res: Response) => {
  try {
    const { userId } = req.params;
    const { role } = req.body;
    
    // Validate role
    if (!Object.values(UserRole).includes(role)) {
      return res.status(400).json({ error: 'Invalid role' });
    }
    
    const updatedUser = await User.findByIdAndUpdate(
      userId,
      { role },
      { new: true }
    ).select('-password');
    
    if (!updatedUser) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    logger.info(`User ${updatedUser.username}'s role updated to ${role} by ${req.user?.username}`);
    res.status(200).json({ user: updatedUser });
  } catch (error) {
    logger.error('Error updating user role:', error);
    res.status(500).json({ error: 'Failed to update user role' });
  }
});

// Supervisor routes - accessible by both supervisors and admins
router.get('/reports', authenticate, requireSupervisor, (req: Request, res: Response) => {
  res.status(200).json({ 
    message: 'Reports accessed successfully',
    role: req.user?.role
  });
});

// Enduser routes - accessible by all authenticated users (no special middleware needed)
router.get('/dashboard', authenticate, (req: Request, res: Response) => {
  res.status(200).json({
    message: 'User dashboard accessed successfully',
    role: req.user?.role
  });
});

export default router;