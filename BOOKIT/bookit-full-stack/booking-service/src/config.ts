import 'dotenv/config';

interface AppConfig {
  port: number;
  databaseUrl: string;
  nodeEnv: 'development' | 'production' | 'test';
  availabilityServiceUrl: string;
  rabbitUrl: string;
  bookingEventsQueue: string;
}

function getEnv(key: string): string | undefined {
  return process.env[key];
}

function requireEnv(key: string): string {
  const value = getEnv(key);
  if (!value) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
}

export const config: AppConfig = {
  port: Number(getEnv('PORT') ?? 3003),
  databaseUrl: requireEnv('DATABASE_URL'),
  nodeEnv: (getEnv('NODE_ENV') as AppConfig['nodeEnv']) ?? 'development',
  availabilityServiceUrl: getEnv('AVAILABILITY_SERVICE_URL') ?? 'http://localhost:3002',
  // RabbitMQ locally stands in for SQS in production - same "fire an event,
  // let a consumer process it independently" pattern you're studying for
  // SAA-C03. Swapping this for the AWS SDK's SQS client later is a
  // contained change, isolated to messageBus.ts.
  rabbitUrl: getEnv('RABBIT_URL') ?? 'amqp://localhost:5672',
  bookingEventsQueue: getEnv('BOOKING_EVENTS_QUEUE') ?? 'booking-events',
};
