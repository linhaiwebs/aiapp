import { registerAs } from '@nestjs/config';

export const appConfig = registerAs('app', () => ({
  port: parseInt(process.env.PORT || '3000', 10),
  corsOrigins: process.env.CORS_ORIGINS || 'http://localhost:3000,http://localhost:8000',
  env: process.env.NODE_ENV || 'development',
}));

export const databaseConfig = registerAs('database', () => {
  const isDev = (process.env.NODE_ENV || 'development') === 'development';
  const dbType = process.env.DB_TYPE || (isDev ? 'sqlite' : 'postgres');

  if (dbType === 'sqlite') {
    return {
      type: 'sqlite' as const,
      database: process.env.DB_SQLITE_PATH || 'data/xcai.db',
      synchronize: process.env.DB_SYNCHRONIZE !== 'false', // default true for sqlite
      logging: process.env.DB_LOGGING === 'true',
    };
  }

  return {
    type: 'postgres' as const,
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '5432', 10),
    username: process.env.DB_USERNAME || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
    database: process.env.DB_DATABASE || 'xcai',
    synchronize: process.env.DB_SYNCHRONIZE === 'true',
    logging: process.env.DB_LOGGING === 'true',
  };
});

export const redisConfig = registerAs('redis', () => ({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379', 10),
  password: process.env.REDIS_PASSWORD || '',
  db: parseInt(process.env.REDIS_DB || '0', 10),
  enabled: process.env.REDIS_ENABLED === 'true', // disabled by default in dev
}));

export const storageConfig = registerAs('storage', () => {
  const isDev = (process.env.NODE_ENV || 'development') === 'development';
  return {
    type: process.env.STORAGE_TYPE || (isDev ? 'local' : 'minio'),
    // MinIO config
    endPoint: process.env.MINIO_ENDPOINT || 'localhost',
    port: parseInt(process.env.MINIO_PORT || '9000', 10),
    accessKey: process.env.MINIO_ACCESS_KEY || 'minioadmin',
    secretKey: process.env.MINIO_SECRET_KEY || 'minioadmin',
    bucket: process.env.MINIO_BUCKET || 'xcai',
    useSSL: process.env.MINIO_USE_SSL === 'true',
    // Local storage config
    localPath: process.env.STORAGE_LOCAL_PATH || 'data/uploads',
  };
});

export const jwtConfig = registerAs('jwt', () => ({
  secret: process.env.JWT_SECRET || 'xcai-jwt-secret-change-in-production',
  accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '15m',
  refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d',
}));

export const realNameConfig = registerAs('realName', () => ({
  mcpUrl: process.env.REAL_NAME_MCP_URL || '',
}));

export const smsConfig = registerAs('sms', () => ({
  provider: process.env.SMS_PROVIDER || 'mock', // 'aliyun' | 'mcp' | 'mock'
  accessKeyId: process.env.SMS_ACCESS_KEY_ID || '',
  accessKeySecret: process.env.SMS_ACCESS_KEY_SECRET || '',
  signName: process.env.SMS_SIGN_NAME || '',
  templateCode: process.env.SMS_TEMPLATE_CODE || '',
  // MCP SMS config (阿里云市场 MCP 服务)
  mcpUrl: process.env.SMS_MCP_URL || '',
  mcpTemplateId: process.env.SMS_MCP_TEMPLATE_ID || 'lxym_20111_sdgsfhwqgvyh',
  // Rate limiting
  codeLength: parseInt(process.env.SMS_CODE_LENGTH || '6', 10),
  codeTtlSeconds: parseInt(process.env.SMS_CODE_TTL || '300', 10),   // 5 minutes
  codeCooldownSeconds: parseInt(process.env.SMS_CODE_COOLDOWN || '60', 10), // 1 minute between sends
  maxSendPerDay: parseInt(process.env.SMS_MAX_SEND_PER_DAY || '10', 10),
}));
