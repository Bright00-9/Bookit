import express, { Express, NextFunction, Request, Response } from 'express';
import cookieParser from 'cookie-parser';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { config } from './config';
import authRoutes from './authRoutes';
import availabilityRoutes from './availabilityRoutes';
import bookingRoutes from './bookingRoutes';

export function buildApp(): Express {
  const app = express();

  // Sets a battery of security-related HTTP headers (X-Content-Type-Options,
  // X-Frame-Options, etc.) - the standard baseline for any public-facing
  // Express app, not just this gateway.
  app.use(helmet());

  // Only the actual frontend origin may make credentialed (cookie-bearing)
  // requests. This is the CORS half of cookie security - httpOnly stops
  // JS from reading the cookie, and this stops other origins' JS from
  // even getting a browser to send it.
  app.use(
    cors({
      origin: config.frontendOrigin,
      credentials: true,
    }),
  );

  app.use(cookieParser());
  app.use(express.json());

  // Global rate limit - protects every downstream service from being
  // hammered, since the gateway is the only path in. Without this, a
  // single client (or bug in the frontend) could overwhelm auth-service
  // or availability-service with unbounded traffic.
  app.use(
    rateLimit({
      windowMs: 15 * 60 * 1000,
      limit: 300,
      standardHeaders: true,
      legacyHeaders: false,
    }),
  );

  // Tighter limit specifically on login/signup - slows down credential
  // stuffing / brute-force attempts without affecting normal browsing.
  app.use(
    ['/auth/login', '/auth/signup'],
    rateLimit({
      windowMs: 15 * 60 * 1000,
      limit: 10,
      standardHeaders: true,
      legacyHeaders: false,
      message: { error: 'Too many attempts, please try again later' },
    }),
  );

  app.get('/health/live', (_req: Request, res: Response) => {
    res.status(200).json({ status: 'ok' });
  });

  app.use('/', authRoutes);
  app.use('/', availabilityRoutes);
  app.use('/', bookingRoutes);

  app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
    console.error('Unhandled gateway error:', err);
    res.status(500).json({ error: 'Internal server error' });
  });

  return app;
}
