// src/app.ts
import express from 'express';
import cors from 'cors';
import cookieParser from 'cookie-parser';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { connectDB } from './config/db.config';
import { initializeEmailTransporter } from './config/email.config';
import authRoutes from './routes/auth.routes';
import protectedRoutes from './routes/protected.routes';
import adminRoutes from './routes/admin.routes';
import { errorHandler, setupErrorHandling } from './utils/error-handler';
import { logger } from './utils/logger';

// Load the appropriate .env file based on environment
if (process.env.NODE_ENV === 'production') {
  require('dotenv').config({ path: '.env.production' });
} else {
  require('dotenv').config({ path: '.env.development' });
}

// Initialize database connection
connectDB();

// Initialize email service
initializeEmailTransporter();

// Initialize express app
const app = express();
const port = process.env.PORT || 3000;

// Security middleware
app.use(helmet());

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  standardHeaders: true,
  legacyHeaders: false
});
app.use('/api/auth', limiter);

// Standard middleware
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  credentials: true
}));
app.use(express.json());
app.use(cookieParser());

// Request logging
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`);
  next();
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api', protectedRoutes);
app.use('/api/admin', adminRoutes); // Add admin routes

// Health check
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// Error handling middleware
app.use(errorHandler);

// Setup global error handling
setupErrorHandling();

// Start the server
if (process.env.NODE_ENV !== 'test') {
  app.listen(port, () => {
    logger.info(`Server running in ${process.env.NODE_ENV} mode on port ${port}`);
  });
}

export default app;
