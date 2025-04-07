// src/scripts/migrate-all.ts
import { exec } from 'child_process';
import { promisify } from 'util';
import { logger } from '../utils/logger';

const execPromise = promisify(exec);

/**
 * Run all migration scripts in sequence
 */
async function runMigration() {
  try {
    logger.info('=== Starting complete database migration ===');
    
    // Step 1: Migrate users
    logger.info('Step 1: Migrating users...');
    await execPromise('npx ts-node src/scripts/migrate-users.ts');
    
    // Step 2: Migrate tokens
    logger.info('Step 2: Migrating tokens...');
    await execPromise('npx ts-node src/scripts/migrate-tokens.ts');
    
    // Step 3: Migrate verification records
    logger.info('Step 3: Migrating verification records...');
    await execPromise('npx ts-node src/scripts/migrate-verifications.ts');
    
    logger.info('=== Migration completed successfully ===');
  } catch (error) {
    logger.error(`Migration failed: ${error}`);
    process.exit(1);
  }
}

// Run the complete migration process
runMigration()
  .then(() => {
    logger.info('All migration tasks completed');
    process.exit(0);
  })
  .catch((error) => {
    logger.error(`Migration failed: ${error}`);
    process.exit(1);
  });