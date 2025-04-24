// src/routes/admin.routes.ts
import { Router, Request, Response } from 'express';
import { authenticate, requireAdmin, requireSupervisor } from '../auth/auth.middleware';
import { User, UserRole } from '../models/user.model';
import { authService } from '../auth/auth.service';
import { logger } from '../utils/logger';
import { tokenService } from '../auth/token.service';
import { Types } from 'mongoose';

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

// Create a new user (admin only)
router.post('/users', authenticate, requireAdmin, async (req: Request, res: Response) => {
  try {
    const { username, email, password, role, skipVerification } = req.body;
    
    // Validate required fields
    if (!username || !email || !password) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    
    // Validate role if provided
    if (role && !Object.values(UserRole).includes(role)) {
      return res.status(400).json({ error: 'Invalid role' });
    }

    // Prevent non-admins from creating admin users
    if (role === UserRole.ADMIN) {
      logger.warn(`Admin user creation attempt by ${req.user?.username} - This action is restricted`);
      return res.status(403).json({ error: 'Creating admin users is restricted' });
    }
    
    // Create the user with the provided information
    const result = await authService.adminCreateUser(
      username,
      email,
      password,
      role || UserRole.ENDUSER,
      skipVerification === true
    );
    
    if (!result.success) {
      return res.status(400).json({ error: result.message });
    }
    
    logger.info(`User ${username} created by admin ${req.user?.username}`);
    res.status(201).json({
      message: result.message,
      userId: result.userId
    });
  } catch (error) {
    logger.error('Admin create user error:', error);
    res.status(500).json({ error: 'User creation failed' });
  }
});

// Create multiple users at once (admin only)
router.post('/users/batch', authenticate, requireAdmin, async (req: Request, res: Response) => {
  try {
    const { users, skipVerification = true } = req.body;
    
    // Validate input
    if (!users || !Array.isArray(users) || users.length === 0) {
      return res.status(400).json({ error: 'A non-empty array of users is required' });
    }
    
    // Validate each user has required fields
    for (const user of users) {
      if (!user.username || !user.email) {
        return res.status(400).json({ 
          error: 'Each user must have a username and email',
          invalidUser: user
        });
      }
      
      // Validate role if provided
      if (user.role && !Object.values(UserRole).includes(user.role)) {
        return res.status(400).json({ 
          error: 'Invalid role provided',
          invalidUser: user
        });
      }
      
      // Prevent creating admin users
      if (user.role === UserRole.ADMIN) {
        logger.warn(`Batch admin user creation attempt by ${req.user?.username} - This action is restricted`);
        return res.status(403).json({ 
          error: 'Creating admin users is restricted',
          invalidUser: user
        });
      }
    }
    
    // Create the users in batch
    const result = await authService.adminCreateBatchUsers(
      users,
      skipVerification === true
    );
    
    logger.info(`Batch user creation by admin ${req.user?.username}. Created: ${result.summary.successful}, Failed: ${result.summary.failed}, Total: ${result.summary.total}`);
    
    res.status(201).json({
      message: `${result.summary.successful} of ${result.summary.total} users created successfully`,
      results: result.results,
      summary: result.summary
    });
  } catch (error) {
    logger.error('Admin batch create users error:', error);
    res.status(500).json({ error: 'Batch user creation failed' });
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

// Delete a specific user (admin only)
router.delete('/users/:userId', authenticate, requireAdmin, async (req: Request, res: Response) => {
  try {
    const { userId } = req.params;
    
    // Prevent an admin from deleting themselves
    if (req.user?.userId === userId) {
      return res.status(400).json({ error: 'Cannot delete your own account' });
    }
    
    // Find the user to get their info for logging
    const user = await User.findById(userId);
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Check if trying to delete another admin (additional security)
    if (user.role === UserRole.ADMIN) {
      logger.warn(`Admin ${req.user?.username} attempted to delete another admin ${user.username}`);
      return res.status(403).json({ error: 'Cannot delete another admin user' });
    }
    
    // Delete the user
    await User.findByIdAndDelete(userId);
    
    // Delete all refresh tokens for the user (cleanup)
    await tokenService.deleteAllUserRefreshTokens(userId);
    
    logger.info(`User ${user.username} (${user.email}) deleted by admin ${req.user?.username}`);
    res.status(200).json({ 
      message: 'User deleted successfully',
      user: {
        username: user.username,
        email: user.email,
        role: user.role
      }
    });
  } catch (error) {
    logger.error('Error deleting user:', error);
    res.status(500).json({ error: 'Failed to delete user' });
  }
});

// Delete all users except admins (admin only)
router.delete('/users', authenticate, requireAdmin, async (req: Request, res: Response) => {
  try {
    const { confirmDelete, preserveAdmins = true } = req.body;
    
    // Require explicit confirmation to prevent accidental deletion
    if (confirmDelete !== 'DELETE_ALL_USERS') {
      return res.status(400).json({ 
        error: 'Confirmation required',
        message: 'To delete all users, include {"confirmDelete": "DELETE_ALL_USERS"} in the request body'
      });
    }
    
    let deleteFilter = {};
    
    // By default, preserve admin accounts
    if (preserveAdmins) {
      deleteFilter = { role: { $ne: UserRole.ADMIN } };
    }
    
    // Delete users based on filter
    const result = await User.deleteMany(deleteFilter);
    
    // Delete all associated refresh tokens
    if (!preserveAdmins) {
      // If deleting all users including admins, delete all tokens
      await tokenService.deleteAllRefreshTokens();
    } else {
      // If preserving admins, we'd need to find and delete non-admin tokens
      // This would require a more complex query with aggregation
      // For simplicity, we'll keep all tokens and let them expire naturally
      logger.info('Refresh tokens for non-admin users will expire naturally');
    }
    
    logger.info(`Bulk user deletion by admin ${req.user?.username}. ${result.deletedCount} users deleted.`);
    res.status(200).json({ 
      message: `${result.deletedCount} users deleted successfully`,
      preservedAdmins: preserveAdmins
    });
  } catch (error) {
    logger.error('Error bulk deleting users:', error);
    res.status(500).json({ error: 'Failed to delete users' });
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