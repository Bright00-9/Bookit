import express, { Express, NextFunction, Request, Response } from 'express';
import bookingRoutes from './bookingRoutes';
import { checkDbConnection } from './db';

export function buildApp(): Express {
  const app = express();

  app.use(express.json());

  app.get('/health/live', (_req: Request, res: Response) => {
    res.status(200).json({ status: 'ok' });
  });

  app.get('/health/ready', async (_req: Request, res: Response) => {
    try {
      await checkDbConnection();
      res.status(200).json({ status: 'ready' });
    } catch (err) {
      res.status(503).json({ status: 'not ready', error: (err as Error).message });
    }
  });

  app.use('/', bookingRoutes);

  app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
    console.error('Unhandled error:', err);
    res.status(500).json({ error: 'Internal server error' });
  });

  return app;
}
