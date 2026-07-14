import 'dotenv/config';

interface AppConfig {
  port: number;
  databaseUrl: string;
  nodeEnv: 'development' | 'production' | 'test';
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
  port: Number(getEnv('PORT') ?? 3002),
  databaseUrl: requireEnv('DATABASE_URL'),
  nodeEnv: (getEnv('NODE_ENV') as AppConfig['nodeEnv']) ?? 'development',
};
