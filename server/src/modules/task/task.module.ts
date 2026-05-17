import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TaskController } from './task.controller';
import { TaskService } from './task.service';
import { Task, TaskClaim, User, TeamMember, Project, TextCollection } from '../../entities';
import { TeamLeaderGuard } from '../../common/guards/team-leader.guard';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [TypeOrmModule.forFeature([Task, TaskClaim, User, TeamMember, Project, TextCollection]), AuthModule],
  controllers: [TaskController],
  providers: [TaskService, TeamLeaderGuard],
  exports: [TaskService],
})
export class TaskModule {}
