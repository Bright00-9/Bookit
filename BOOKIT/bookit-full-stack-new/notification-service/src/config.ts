import 'dotenv/config';

interface AppConfig {
  port: number;
  nodeEnv: 'development' | 'production' | 'test';
  rabbitUrl: string;
  bookingEventsQueue: string;
}

function getEnv(key: string): string | undefined {
  return process.env[key];
}

export const config: AppConfig = {
  port: Number(getEnv('PORT') ?? 3004),
  nodeEnv: (getEnv('NODE_ENV') as AppConfig['nodeEnv']) ?? 'development',
  rabbitUrl: getEnv('RABBIT_URL') ?? 'amqp://localhost:5672',
  bookingEventsQueue: getEnv('BOOKING_EVENTS_QUEUE') ?? 'booking-events',
};
