import { buildApp } from './app';
import { config } from './config';

const app = buildApp();

const server = app.listen(config.port, () => {
  console.log(`api-gateway listening on port ${config.port} (${config.nodeEnv})`);
});

async function shutdown(signal: string): Promise<void> {
  console.log(`Received ${signal}, shutting down gracefully...`);
  server.close(() => {
    console.log('Shutdown complete');
    process.exit(0);
  });

  setTimeout(() => {
    console.error('Forced shutdown after timeout');
    process.exit(1);
  }, 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
