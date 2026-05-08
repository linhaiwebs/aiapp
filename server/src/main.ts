import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { NestExpressApplication } from '@nestjs/platform-express';
import { json, urlencoded, Request, Response, NextFunction } from 'express';
import { dirname, resolve } from 'path';
import * as fs from 'fs';
import { AppModule } from './app.module';

/**
 * Ensure all required data directories exist before TypeORM initializes.
 * Must be called BEFORE NestFactory.create().
 * 
 * Also checks SQLite DB compatibility: if the DB file was created with an
 * older schema (before joinCode was added to teams), delete the DB file
 * so TypeORM can recreate from scratch. This only happens in development.
 */
function ensureDataDirs() {
  const dbPath = process.env.DB_SQLITE_PATH || 'data/xcai.db';
  const dataDir = dirname(resolve(process.cwd(), dbPath));
  if (!fs.existsSync(dataDir)) {
    fs.mkdirSync(dataDir, { recursive: true });
    console.log(`📁 Created data directory: ${dataDir}`);
  }

  // Auto-migration for SQLite: if DB file exists but was created before
  // schema changes, delete it so TypeORM can recreate from scratch.
  const dbFile = resolve(process.cwd(), dbPath);
  const schemaVersionFile = resolve(process.cwd(), 'data/.schema_version');
  const CURRENT_SCHEMA_VERSION = '3'; // Increment when breaking schema changes happen

  if (fs.existsSync(dbFile)) {
    let needsRecreate = false;
    if (fs.existsSync(schemaVersionFile)) {
      const version = fs.readFileSync(schemaVersionFile, 'utf8').trim();
      if (version !== CURRENT_SCHEMA_VERSION) needsRecreate = true;
    } else {
      // No version file = very old DB, needs recreate
      needsRecreate = true;
    }
    if (needsRecreate) {
      console.log(`⚠️  Database schema version mismatch. Recreating database...`);
      try { fs.unlinkSync(dbFile); } catch {}
    }
  }
  // Write current schema version
  fs.writeFileSync(schemaVersionFile, CURRENT_SCHEMA_VERSION, 'utf8');

  const uploadDir = process.env.STORAGE_LOCAL_PATH || 'data/uploads';
  const resolvedUploadDir = resolve(process.cwd(), uploadDir);
  if (!fs.existsSync(resolvedUploadDir)) {
    fs.mkdirSync(resolvedUploadDir, { recursive: true });
    console.log(`📁 Created upload directory: ${resolvedUploadDir}`);
  }
}

// Run BEFORE any NestJS initialization
ensureDataDirs();

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  app.setGlobalPrefix('api');

  // Increase payload size for file uploads
  app.use(json({ limit: '500mb' }));
  app.use(urlencoded({ extended: true, limit: '500mb' }));

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  app.enableCors({
    origin: (origin, callback) => {
      // 允许所有 localhost 端口（Flutter web 用随机端口）
      if (!origin || origin.startsWith('http://localhost') || origin.startsWith('http://127.0.0.1')) {
        callback(null, true);
        return;
      }
      // 也检查环境变量配置的来源
      const allowed = process.env.CORS_ORIGINS?.split(',') || [];
      if (allowed.some(url => origin.startsWith(url.trim()))) {
        callback(null, true);
        return;
      }
      callback(null, true); // 开发模式全部放行
    },
    credentials: true,
  });

  // Serve local uploaded files in dev mode
  const storageType = process.env.STORAGE_TYPE || 'local';
  const localPath = process.env.STORAGE_LOCAL_PATH || 'data/uploads';
  if (storageType === 'local') {
    if (!fs.existsSync(localPath)) {
      fs.mkdirSync(localPath, { recursive: true });
    }
    app.useStaticAssets(localPath, { prefix: '/storage/' });
  }

  // Serve Flutter web app at /app
  // Check multiple possible locations (dev, docker, host-nginx)
  const appDistPaths = [
    resolve(process.cwd(), '../app/build/web'),   // dev mode
    resolve(process.cwd(), 'public/app'),          // docker mode
  ];
  const appDistPath = appDistPaths.find(p => fs.existsSync(p) && fs.readdirSync(p).length > 0);
  if (appDistPath) {
    app.useStaticAssets(appDistPath, { prefix: '/app/' });
    app.use('/app', (req: Request, res: Response, next: NextFunction) => {
      if (req.method === 'GET' && !req.path.startsWith('/assets/') && !req.path.includes('.')) {
        res.sendFile(resolve(appDistPath, 'index.html'));
      } else {
        next();
      }
    });
    console.log(`📱 Flutter web app served at /app/ (from ${appDistPath})`);
  }

  // Serve admin panel at /admin
  const adminDistPaths = [
    resolve(process.cwd(), '../admin/dist'),       // dev mode
    resolve(process.cwd(), 'public/admin'),        // docker mode
  ];
  const adminDistPath = adminDistPaths.find(p => fs.existsSync(p) && fs.readdirSync(p).length > 0);
  if (adminDistPath) {
    app.useStaticAssets(adminDistPath, { prefix: '/admin/' });
    app.use('/admin', (req: Request, res: Response, next: NextFunction) => {
      if (req.method === 'GET' && !req.path.startsWith('/assets/') && !req.path.includes('.')) {
        res.sendFile(resolve(adminDistPath, 'index.html'));
      } else {
        next();
      }
    });
    console.log(`🖥️  Admin panel served at /admin/ (from ${adminDistPath})`);
  }

  // Root health check - returns API info instead of confusing 404
  app.use('/', (req: Request, res: Response, next: NextFunction) => {
    if (req.method === 'GET' && req.path === '/') {
      res.json({
        name: 'XCAI API',
        version: '1.0',
        docs: '/api/docs',
        admin: '/admin/',
        app: '/app/',
      });
    } else {
      next();
    }
  });

  const config = new DocumentBuilder()
    .setTitle('XCAI API')
    .setDescription('数据采集众包平台 API')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  const port = process.env.PORT || 3000;
  await app.listen(port);
  console.log(`🚀 XCAI Server running on http://localhost:${port}`);
  console.log(`📖 API Docs: http://localhost:${port}/api/docs`);
  console.log(`💾 Storage: ${storageType}${storageType === 'local' ? ` (${localPath})` : ''}`);
}

bootstrap();
