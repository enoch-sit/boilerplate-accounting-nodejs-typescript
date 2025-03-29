// src/utils/error-handler.ts
import { Request, Response, NextFunction } from 'express';
import { logger } from './logger';

export class AppError extends Error {
  constructor(message: string, public statusCode: number, public isOperational: boolean = true) {
    super(message);
    this.name = this.constructor.name;
    Error.captureStackTrace(this, this.constructor);
  }
}

export const errorHandler = (err: AppError, req: Request, res: Response, next: NextFunction) => {
  err.statusCode = err.statusCode || 500;
  err.isOperational = err.isOperational !== undefined ? err.isOperational : true;

  // Log error
  if (err.statusCode >= 500) {
    logger.error(`Error: ${err.message}`, { stack: err.stack });
  } else {
    logger.warn(`Error: ${err.message}`);
  }

  // Operational errors: trusted errors that can be handled
  if (err.isOperational) {
    return res.status(err.statusCode).json({
      error: err.message
    });
  }

  // Programming or other unknown errors: don't leak error details
  return res.status(500).json({
    error: 'Something went wrong'
  });
};

// Handle uncaught exceptions and unhandled rejections
export const setupErrorHandling = () => {
  process.on('uncaughtException', (err) => {
    logger.error('UNCAUGHT EXCEPTION:', err);
    process.exit(1);
  });

  process.on('unhandledRejection', (err) => {
    logger.error('UNHANDLED REJECTION:', err);
    process.exit(1);
  });
};
