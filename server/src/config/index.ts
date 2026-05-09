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
  appCode: process.env.REAL_NAME_APP_CODE || process.env.SMS_APP_CODE || '',
  verifyHost: process.env.REAL_NAME_VERIFY_HOST || 'zidv2.market.alicloudapi.com',
  verifyPath: process.env.REAL_NAME_VERIFY_PATH || '/idcheck/Post',
  ocrHost: process.env.REAL_NAME_OCR_HOST || 'zidv2.market.alicloudapi.com',
  ocrFrontPath: process.env.REAL_NAME_OCR_FRONT_PATH || '/thirdnode/ImageAI/idcardfrontrecongnition',
  ocrBackPath: process.env.REAL_NAME_OCR_BACK_PATH || '/thirdnode/ImageAI/idcardbackrecongnition',
}));

export const smsConfig = registerAs('sms', () => ({
  provider: process.env.SMS_PROVIDER || 'mock', // 'market' | 'mock'
  // 阿里云市场短信服务 (cmapi00067513)
  appCode: process.env.SMS_APP_CODE || '',
  templateId: process.env.SMS_TEMPLATE_ID || 'lxym_20111_sdgsfhwqgvyh',
  marketHost: process.env.SMS_MARKET_HOST || 'send.market.alicloudapi.com',
  marketPath: process.env.SMS_MARKET_PATH || '/sms/send',
  // Rate limiting
  codeLength: parseInt(process.env.SMS_CODE_LENGTH || '6', 10),
  codeTtlSeconds: parseInt(process.env.SMS_CODE_TTL || '300', 10),
  codeCooldownSeconds: parseInt(process.env.SMS_CODE_COOLDOWN || '60', 10),
  maxSendPerDay: parseInt(process.env.SMS_MAX_SEND_PER_DAY || '10', 10),
}));
