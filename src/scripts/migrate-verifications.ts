// src/scripts/migrate-verifications.ts
import mongoose from 'mongoose';
import { config } from 'dotenv';
import { logger } from '../utils/logger';
import { VerificationType } from '../models/verification.model';

// Load environment variables
if (process.env.NODE_ENV === 'production') {
  config({ path: '.env.production' });
} else {
  config({ path: '.env.development' });
}

// Connection URIs for old and new databases
const OLD_DB_URI = process.env.OLD_MONGODB_URI || 'mongodb://localhost:27017/old-auth-db';
const NEW_DB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/auth-db';

// Connect to the old database first, then migrate verification records to the new database
async function migrateVerifications() {
  // Create separate mongoose instances to handle two simultaneous connections
  const oldMongoose = mongoose.createConnection(OLD_DB_URI);
  const newMongoose = mongoose.createConnection(NEW_DB_URI);

  try {
    logger.info('Starting verification records migration...');

    // Define the old Verification model schema
    // Note: This should match your old schema structure
    const OldVerificationSchema = new mongoose.Schema({
      userId: mongoose.Schema.Types.ObjectId,
      type: String,
      token: String,
      expires: Date
    });

    // Wait for connection to old database
    await oldMongoose.asPromise();
    logger.info('Connected to old database');

    // Create model using old schema
    const OldVerification = oldMongoose.model('Verification', OldVerificationSchema);

    // Wait for connection to new database
    await newMongoose.asPromise();
    logger.info('Connected to new database');

    // Define the new Verification model schema
    const NewVerificationSchema = new mongoose.Schema({
      userId: mongoose.Schema.Types.ObjectId,
      type: String,
      token: String,
      expires: Date
    });
    const NewVerification = newMongoose.model('Verification', NewVerificationSchema);

    // Fetch all verification records from the old database
    const oldVerifications = await OldVerification.find({});
    logger.info(`Found ${oldVerifications.length} verification records to migrate`);

    // Prepare arrays for batch processing
    const verificationBatch = [];
    let successCount = 0;
    let failCount = 0;

    // Process verification records
    for (const oldVerification of oldVerifications) {
      try {
        // Convert the old verification data to a regular object
        const verificationData = oldVerification.toObject();

        // Create a new verification record with the same data
        const newVerification = {
          ...verificationData,
          _id: verificationData._id // Keep the same ID
        };

        verificationBatch.push(newVerification);
        successCount++;
      } catch (error) {
        logger.error(`Failed to process verification record ${oldVerification._id}: ${error}`);
        failCount++;
      }
    }

    // Insert all verification records into the new database
    if (verificationBatch.length > 0) {
      await NewVerification.insertMany(verificationBatch, { ordered: false });
      logger.info(`Migrated ${verificationBatch.length} verification records successfully`);
    }

    logger.info(`Verification migration completed: ${successCount} succeeded, ${failCount} failed`);
    
  } catch (error) {
    logger.error(`Verification migration failed: ${error}`);
  } finally {
    // Close connections properly
    await oldMongoose.close();
    await newMongoose.close();
    logger.info('Database connections closed');
  }
}

// Run the migration
migrateVerifications()
  .then(() => {
    logger.info('Verification migration script completed');
    process.exit(0);
  })
  .catch((error) => {
    logger.error(`Verification migration script failed: ${error}`);
    process.exit(1);
  });