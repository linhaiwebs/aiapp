import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ThrottlerModule } from '@nestjs/throttler';
import { AuthModule } from './modules/auth/auth.module';
import { TaskModule } from './modules/task/task.module';
import { SubmissionModule } from './modules/submission/submission.module';
import { ProjectModule } from './modules/project/project.module';
import { FileModule } from './modules/file/file.module';
import { QcModule } from './modules/qc/qc.module';
import { UserModule } from './modules/user/user.module';
import { CategoryModule } from './modules/category/category.module';
import { AdminModule } from './modules/admin/admin.module';
import { TeamModule } from './modules/team/team.module';
import { TextCollectionModule } from './modules/text-collection/text-collection.module';
import { SmsModule } from './modules/sms/sms.module';
import { RealNameModule } from './modules/real-name/real-name.module';
import { SeedModule } from './modules/seed/seed.module';
import { AppVersionModule } from './modules/app/app.module';
import { appConfig, databaseConfig, redisConfig, storageConfig, jwtConfig, smsConfig, realNameConfig } from './config';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [appConfig, databaseConfig, redisConfig, storageConfig, jwtConfig, smsConfig, realNameConfig],
      envFilePath: ['.env.local', '.env'],
    }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => {
        const dbType = configService.get<string>('database.type');
        if (dbType === 'sqlite') {
          return {
            type: 'sqljs',
            location: configService.get<string>('database.database'),
            autoSave: true,
            entities: [__dirname + '/entities/**/*.entity{.ts,.js}'],
            synchronize: configService.get<boolean>('database.synchronize'),
            logging: configService.get<boolean>('database.logging'),
          };
        }
        return {
          type: 'postgres',
          host: configService.get<string>('database.host'),
          port: configService.get<number>('database.port'),
          username: configService.get<string>('database.username'),
          password: configService.get<string>('database.password'),
          database: configService.get<string>('database.database'),
          entities: [__dirname + '/entities/**/*.entity{.ts,.js}'],
          synchronize: configService.get<boolean>('database.synchronize'),
          logging: configService.get<boolean>('database.logging'),
          uuidExtension: 'pgcrypto',
        };
      },
    }),
    ThrottlerModule.forRoot([
      {
        ttl: 60000,
        limit: 100,
      },
    ]),
    AuthModule,
    TaskModule,
    SubmissionModule,
    ProjectModule,
    FileModule,
    QcModule,
    UserModule,
    CategoryModule,
    AdminModule,
    TeamModule,
    TextCollectionModule,
    SmsModule,
    RealNameModule,
    SeedModule,
    AppVersionModule,
  ],
})
export class AppModule {}
