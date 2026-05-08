import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
  User,
  Task,
  TaskClaim,
  Submission,
  Project,
  FileEntity,
  Team,
  TextCollection,
} from '../../entities';
import { AdminService } from './admin.service';
import { AdminController } from './admin.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, Task, TaskClaim, Submission, Project, FileEntity, Team, TextCollection]),
  ],
  controllers: [AdminController],
  providers: [AdminService],
  exports: [AdminService],
})
export class AdminModule {}
