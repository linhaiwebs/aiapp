import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { SubmissionController } from './submission.controller';
import { SubmissionService } from './submission.service';
import { Submission, TaskClaim, Task, FileEntity, TextCollection } from '../../entities';

@Module({
  imports: [TypeOrmModule.forFeature([Submission, TaskClaim, Task, FileEntity, TextCollection])],
  controllers: [SubmissionController],
  providers: [SubmissionService],
  exports: [SubmissionService],
})
export class SubmissionModule {}
