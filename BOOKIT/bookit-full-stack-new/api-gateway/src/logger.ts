const SERVICE_NAME = 'api-gateway';

function timestamp(): string {
  return new Date().toISOString().split('T')[1].replace('Z', '');
}

export function log(message: string): void {
  console.log(`[${SERVICE_NAME} ${timestamp()}] ${message}`);
}

export function logError(message: string, err?: unknown): void {
  console.error(`[${SERVICE_NAME} ${timestamp()}] ⚠ ${message}`, err ?? '');
}
