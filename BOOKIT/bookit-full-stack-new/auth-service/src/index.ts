import { buildApp } from './app';
import { config } from './config';
import { pool } from './db';

const app = buildApp();

const server = app.listen(config.port, () => {
  console.log(`auth-service listening on port ${config.port} (${config.nodeEnv})`);
});

// Graceful shutdown matters in Kubernetes: when a pod is terminated
// (deployment rollout, scale-down, node drain), it receives SIGTERM and
// has a grace period to finish in-flight requests and close connections
// cleanly before being force-killed with SIGKILL.
async function shutdown(signal: string): Promise<void> {
  console.log(`Received ${signal}, shutting down gracefully...`);
  server.close(async () => {
    await pool.end();
    console.log('Shutdown complete');
    process.exit(0);
  });

  // Safety net: force-exit if shutdown hangs longer than 10s.
  setTimeout(() => {
    console.error('Forced shutdown after timeout');
    process.exit(1);
  }, 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
