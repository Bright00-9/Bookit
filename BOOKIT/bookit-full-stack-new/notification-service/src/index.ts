import { config } from './config';
import { startConsumer, closeConsumer } from './consumer';
import { ConsoleNotifier } from './notifier';
import { buildHealthApp } from './healthApp';

let consumerReady = false;

async function main(): Promise<void> {
  const notifier = new ConsoleNotifier();

  const app = buildHealthApp(() => consumerReady);
  const server = app.listen(config.port, () => {
    console.log(`notification-service health server listening on port ${config.port}`);
  });

  try {
    await startConsumer(notifier);
    consumerReady = true;
  } catch (err) {
    console.error('Failed to start consumer:', err);
    // Exit non-zero so an orchestrator (Docker/Kubernetes restart policy)
    // knows this instance failed to start and should be retried, rather
    // than sitting alive but silently not consuming anything.
    process.exit(1);
  }

  async function shutdown(signal: string): Promise<void> {
    console.log(`Received ${signal}, shutting down gracefully...`);
    consumerReady = false;
    await closeConsumer();
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
}

main();
