import express, { Express, Request, Response } from 'express';

export function buildHealthApp(isReady: () => boolean): Express {
  const app = express();

  app.get('/health/live', (_req: Request, res: Response) => {
    res.status(200).json({ status: 'ok' });
  });

  // Readiness reflects whether the RabbitMQ consumer is actually
  // connected and consuming - not just whether the process is running.
  // A pod that's "alive" but disconnected from the queue should be
  // pulled from receiving new work by anything that checks readiness.
  app.get('/health/ready', (_req: Request, res: Response) => {
    if (isReady()) {
      res.status(200).json({ status: 'ready' });
    } else {
      res.status(503).json({ status: 'not ready' });
    }
  });

  return app;
}
