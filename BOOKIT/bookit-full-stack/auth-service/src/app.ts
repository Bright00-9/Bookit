import express, { Express, NextFunction, Request, Response } from 'express';
import authRoutes from './authRoutes';
import { checkDbConnection } from './db';

export function buildApp(): Express {
  const app = express();

  app.use(express.json());

  // Liveness: is the process running at all.
  app.get('/health/live', (_req: Request, res: Response) => {
    res.status(200).json({ status: 'ok' });
  });

  // Readiness: is the process able to serve real traffic (DB reachable).
  // Kubernetes uses this distinction — a pod can be "alive" but not "ready"
  // (e.g. during DB failover), and should be pulled from the load balancer
  // without being restarted.
  app.get('/health/ready', async (_req: Request, res: Response) => {
    try {
      await checkDbConnection();
      res.status(200).json({ status: 'ready' });
    } catch (err) {
      res.status(503).json({ status: 'not ready', error: (err as Error).message });
    }
  });

  app.use('/auth', authRoutes);

  // Centralized error handler — catches anything thrown/rejected in routes
  // that wasn't already handled, so the process never crashes on an
  // unexpected error and callers always get a clean JSON error response.
  app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
    console.error('Unhandled error:', err);
    res.status(500).json({ error: 'Internal server error' });
  });

  return app;
}
