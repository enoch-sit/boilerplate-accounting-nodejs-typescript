// src/scripts/migrate-users.ts
import mongoose from 'mongoose';
import { config } from 'dotenv';
import { User, UserRole } from '../models/user.model';
import { logger } from '../utils/logger';

// Load environment variables
if (process.env.NODE_ENV === 'production') {
  config({ path: '.env.production' });
} else {
  config({ path: '.env.development' });
}

// Connection URIs for old and new databases
const OLD_DB_URI = process.env.OLD_MONGODB_URI || 'mongodb://localhost:27017/old-auth-db';
const NEW_DB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/auth-db';

// Connect to the old database first, then migrate data to the new database
async function migrateUsers() {
  // Create separate mongoose instances to handle two simultaneous connections
  const oldMongoose = mongoose.createConnection(OLD_DB_URI);
  const newMongoose = mongoose.createConnection(NEW_DB_URI);

  try {
    logger.info('Starting user migration...');

    // Define the old User model schema
    // Note: This should match your old schema structure
    const OldUserSchema = new mongoose.Schema({
      username: String,
      email: String,
      password: String,
      isVerified: Boolean
      // Add any other fields that existed in your old schema
    });

    // Wait for connection to old database
    await oldMongoose.asPromise();
    logger.info('Connected to old database');

    // Create model using old schema
    const OldUser = oldMongoose.model('User', OldUserSchema);

    // Wait for connection to new database
    await newMongoose.asPromise();
    logger.info('Connected to new database');

    // Set up the new User model on this connection
    // This is just for reference - we'll use the actual import in practice
    const NewUserSchema = new mongoose.Schema({
      username: String,
      email: String,
      password: String,
      isVerified: Boolean,
      role: {
        type: String,
        enum: Object.values(UserRole),
        default: UserRole.ENDUSER
      }
    });
    const NewUser = newMongoose.model('User', NewUserSchema);

    // Fetch all users from the old database
    const oldUsers = await OldUser.find({});
    logger.info(`Found ${oldUsers.length} users to migrate`);

    // Prepare arrays for batch processing
    const userBatch = [];
    let successCount = 0;
    let failCount = 0;

    // Process users - adding role field
    for (const oldUser of oldUsers) {
      try {
        // Convert the old user data to a regular object
        const userData = oldUser.toObject();

        // Determine the role to assign
        // You can customize this logic based on your needs
        // For example, you might want to assign admin role to specific emails
        let role = UserRole.ENDUSER;
        
        // Example: If username includes "admin", make them an admin
        if (userData.username && userData.username.toLowerCase().includes('admin')) {
          role = UserRole.ADMIN;
        }
        // Example: If username includes "supervisor", make them a supervisor
        else if (userData.username && userData.username.toLowerCase().includes('supervisor')) {
          role = UserRole.SUPERVISOR;
        }

        // Create a new user with the appropriate role
        const newUser = {
          ...userData,
          role,
          _id: userData._id // Keep the same ID to maintain references
        };

        userBatch.push(newUser);
        successCount++;
      } catch (error) {
        logger.error(`Failed to process user ${oldUser._id}: ${error}`);
        failCount++;
      }
    }

    // Insert all users into the new database
    if (userBatch.length > 0) {
      await NewUser.insertMany(userBatch, { ordered: false });
      logger.info(`Migrated ${userBatch.length} users successfully`);
    }

    logger.info(`Migration completed: ${successCount} succeeded, ${failCount} failed`);
    
  } catch (error) {
    logger.error(`Migration failed: ${error}`);
  } finally {
    // Close connections properly
    await oldMongoose.close();
    await newMongoose.close();
    logger.info('Database connections closed');
  }
}

// Run the migration
migrateUsers()
  .then(() => {
    logger.info('Migration script completed');
    process.exit(0);
  })
  .catch((error) => {
    logger.error(`Migration script failed: ${error}`);
    process.exit(1);
  });