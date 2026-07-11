import 'dotenv/config';

interface AppConfig {
  port: number;
  jwtSecret: string;
  nodeEnv: 'development' | 'production' | 'test';
  frontendOrigin: string;
  services: {
    auth: string;
    booking: string;
    availability: string;
  };
  cookie: {
    name: string;
    maxAgeMs: number;
  };
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
  port: Number(getEnv('PORT') ?? 8080),
  jwtSecret: requireEnv('JWT_SECRET'),
  nodeEnv: (getEnv('NODE_ENV') as AppConfig['nodeEnv']) ?? 'development',
  // Exact origin allowed to send credentialed requests. Never use '*' here
  // once cookies/credentials are involved - browsers reject wildcard CORS
  // for credentialed requests anyway, but being explicit avoids ambiguity.
  frontendOrigin: getEnv('FRONTEND_ORIGIN') ?? 'http://localhost:5173',
  services: {
    auth: getEnv('AUTH_SERVICE_URL') ?? 'http://localhost:3001',
    booking: getEnv('BOOKING_SERVICE_URL') ?? 'http://localhost:3003',
    availability: getEnv('AVAILABILITY_SERVICE_URL') ?? 'http://localhost:3002',
  },
  cookie: {
    name: 'bookit_session',
    maxAgeMs: 60 * 60 * 1000, // 1 hour, matches JWT expiry in auth-service
  },
};
