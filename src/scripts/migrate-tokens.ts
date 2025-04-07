// src/scripts/migrate-tokens.ts
import mongoose from 'mongoose';
import { config } from 'dotenv';
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

// Connect to the old database first, then migrate tokens to the new database
async function migrateTokens() {
  // Create separate mongoose instances to handle two simultaneous connections
  const oldMongoose = mongoose.createConnection(OLD_DB_URI);
  const newMongoose = mongoose.createConnection(NEW_DB_URI);

  try {
    logger.info('Starting token migration...');

    // Define the old Token model schema
    // Note: This should match your old schema structure
    const OldTokenSchema = new mongoose.Schema({
      userId: mongoose.Schema.Types.ObjectId,
      refreshToken: String,
      expires: Date
    });

    // Wait for connection to old database
    await oldMongoose.asPromise();
    logger.info('Connected to old database');

    // Create model using old schema
    const OldToken = oldMongoose.model('Token', OldTokenSchema);

    // Wait for connection to new database
    await newMongoose.asPromise();
    logger.info('Connected to new database');

    // Define the new Token model schema
    const NewTokenSchema = new mongoose.Schema({
      userId: mongoose.Schema.Types.ObjectId,
      refreshToken: String,
      expires: Date
    });
    const NewToken = newMongoose.model('Token', NewTokenSchema);

    // Fetch all tokens from the old database
    const oldTokens = await OldToken.find({});
    logger.info(`Found ${oldTokens.length} tokens to migrate`);

    // Prepare arrays for batch processing
    const tokenBatch = [];
    let successCount = 0;
    let failCount = 0;

    // Process tokens
    for (const oldToken of oldTokens) {
      try {
        // Convert the old token data to a regular object
        const tokenData = oldToken.toObject();

        // Create a new token with the same data
        const newToken = {
          ...tokenData,
          _id: tokenData._id // Keep the same ID
        };

        tokenBatch.push(newToken);
        successCount++;
      } catch (error) {
        logger.error(`Failed to process token ${oldToken._id}: ${error}`);
        failCount++;
      }
    }

    // Insert all tokens into the new database
    if (tokenBatch.length > 0) {
      await NewToken.insertMany(tokenBatch, { ordered: false });
      logger.info(`Migrated ${tokenBatch.length} tokens successfully`);
    }

    logger.info(`Token migration completed: ${successCount} succeeded, ${failCount} failed`);
    
  } catch (error) {
    logger.error(`Token migration failed: ${error}`);
  } finally {
    // Close connections properly
    await oldMongoose.close();
    await newMongoose.close();
    logger.info('Database connections closed');
  }
}

// Run the migration
migrateTokens()
  .then(() => {
    logger.info('Token migration script completed');
    process.exit(0);
  })
  .catch((error) => {
    logger.error(`Token migration script failed: ${error}`);
    process.exit(1);
  });