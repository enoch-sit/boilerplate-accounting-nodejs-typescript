// src/utils/logger.ts
import winston from 'winston';

const { combine, timestamp, printf, colorize, json } = winston.format;

// Custom log format for development
const devLogFormat = printf(({ level, message, timestamp, ...metadata }) => {
  return `[${timestamp}] ${level}: ${message} ${Object.keys(metadata).length ? JSON.stringify(metadata, null, 2) : ''}`;
});

// Create logger with different configurations based on environment
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: combine(
    timestamp(),
    process.env.NODE_ENV === 'production' ? json() : devLogFormat
  ),
  defaultMeta: { service: 'auth-service' },
  transports: [
    // Always log to console
    new winston.transports.Console({
      format: combine(
        colorize(),
        process.env.NODE_ENV === 'production' ? json() : devLogFormat
      )
    })
  ]
});

// Add file transports in production
if (process.env.NODE_ENV === 'production') {
  logger.add(
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' })
  );
  logger.add(
    new winston.transports.File({ filename: 'logs/combined.log' })
  );
}

export { logger };