import express, { Express, NextFunction, Request, Response } from 'express';
import slotRoutes from './slotRoutes';
import { checkDbConnection } from './db';
import { log } from './logger';

export function buildApp(): Express {
  const app = express();

  app.use(express.json());

  // Logs every incoming request with a service tag, so a full request
  // flow across multiple services is visible just by watching
  // `docker compose logs -f` (or each terminal in local dev).
  app.use((req: Request, _res: Response, next: NextFunction) => {
    if (!req.path.startsWith('/health')) {
      log(`${req.method} ${req.path}`);
    }
    next();
  });


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

  app.use('/', slotRoutes);

  app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
    console.error('Unhandled error:', err);
    res.status(500).json({ error: 'Internal server error' });
  });

  return app;
}
