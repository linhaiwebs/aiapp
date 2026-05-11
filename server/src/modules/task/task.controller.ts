import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { TaskService } from './task.service';
import { CreateTaskDto, UpdateTaskDto, TaskFilterDto } from './dto';
import { CurrentUser, Roles } from '../../common/decorators';
import { UserRole, TaskStatus } from '../../entities';
import { TeamLeaderGuard } from '../../common/guards/team-leader.guard';
import { RolesGuard } from '../auth/guards/roles.guard';

@ApiTags('任务')
@Controller('tasks')
export class TaskController {
  constructor(private taskService: TaskService) {}

  @Get('search')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '搜索任务（团队隔离）' })
  async search(
    @CurrentUser('userId') userId: string,
    @CurrentUser('role') role: string,
    @Query('keyword') keyword: string,
    @Query('page') page: number = 1,
  ) {
    const [items, total] = await this.taskService.search(keyword, Number(page), 20, userId, role);
    return { items, total };
  }

  @Get('claims/mine')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '我的任务领取记录' })
  async getMyClaims(
    @CurrentUser('userId') userId: string,
    @Query('status') status?: string,
  ) {
    return this.taskService.getUserClaims(userId, status as any);
  }

  @Get('claims/pending')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @UseGuards(TeamLeaderGuard)
  @ApiOperation({ summary: '待审批的任务申请' })
  async getPendingClaims(
    @Query('taskId') taskId?: string,
    @Query('page') page = 1,
    @Query('pageSize') pageSize = 20,
  ) {
    return this.taskService.getPendingClaims(taskId, page, pageSize);
  }

  @Get('claims/approved')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '已批准认领记录（广场 Feed）' })
  async getApprovedClaims(
    @Query('page') page = 1,
    @Query('pageSize') pageSize = 20,
    @Query('teamId') teamId?: string,
  ) {
    return this.taskService.getApprovedClaims(page, pageSize, teamId);
  }

  @Get('claims/all')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: '管理后台全量认领查询' })
  async getAllClaims(
    @Query('page') page = 1,
    @Query('pageSize') pageSize = 20,
    @Query('status') status?: string,
    @Query('teamId') teamId?: string,
    @Query('userId') userId?: string,
    @Query('taskId') taskId?: string,
  ) {
    return this.taskService.getAllClaims(page, pageSize, { status, teamId, userId, taskId });
  }

  @Get()
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '任务列表（团队隔离）' })
  async findAll(
    @Query() filter: TaskFilterDto,
    @CurrentUser('userId') userId: string,
    @CurrentUser('role') role: string,
  ) {
    return this.taskService.findAll(filter, userId, role);
  }

  @Get(':id')
  @ApiOperation({ summary: '任务详情' })
  async findOne(@Param('id') id: string) {
    return this.taskService.findOne(id);
  }

  @Post()
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: '创建任务' })
  async create(@Body() dto: CreateTaskDto) {
    return this.taskService.create(dto);
  }

  @Patch(':id')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: '更新任务' })
  async update(@Param('id') id: string, @Body() dto: UpdateTaskDto) {
    return this.taskService.update(id, dto);
  }

  @Delete(':id')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.SUPER_ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: '删除任务' })
  async remove(@Param('id') id: string) {
    await this.taskService.remove(id);
    return { success: true };
  }

  @Post(':id/claim')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '申请任务（需审核员审批）' })
  async claim(
    @Param('id') taskId: string,
    @CurrentUser('userId') userId: string,
    @CurrentUser('role') role: string,
  ) {
    return this.taskService.claim(userId, taskId, role);
  }

  @Post(':id/abandon')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '放弃任务' })
  async abandon(
    @Param('id') taskId: string,
    @CurrentUser('userId') userId: string,
    @Body('claimId') claimId: string,
  ) {
    await this.taskService.abandon(userId, claimId);
    return { success: true };
  }

  @Post('claims/:claimId/approve')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @UseGuards(TeamLeaderGuard)
  @ApiOperation({ summary: '审批通过任务申请' })
  async approveClaim(
    @Param('claimId') claimId: string,
    @CurrentUser('userId') reviewerId: string,
  ) {
    return this.taskService.approveClaim(claimId, reviewerId);
  }

  @Post('claims/:claimId/reject')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @UseGuards(TeamLeaderGuard)
  @ApiOperation({ summary: '拒绝任务申请' })
  async rejectClaim(
    @Param('claimId') claimId: string,
    @CurrentUser('userId') reviewerId: string,
    @Body('reason') reason?: string,
  ) {
    return this.taskService.rejectClaim(claimId, reviewerId, reason);
  }

  @Delete('data/all')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.SUPER_ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: '清除所有任务数据' })
  async clearAllData() {
    return this.taskService.clearAllTaskData();
  }

  @Post('batch-delete')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.SUPER_ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: '批量删除任务' })
  async batchRemove(@Body('ids') ids: string[]) {
    await this.taskService.batchRemove(ids);
    return { success: true };
  }

  @Post('batch-status')
  @UseGuards(AuthGuard('jwt'), RolesGuard)
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: '批量修改任务状态' })
  async batchUpdateStatus(
    @Body('ids') ids: string[],
    @Body('status') status: string,
  ) {
    await this.taskService.batchUpdateStatus(ids, status as TaskStatus);
    return { success: true };
  }
}
