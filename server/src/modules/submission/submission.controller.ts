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
import { SubmissionService } from './submission.service';
import { CreateSubmissionDto, UpdateSubmissionDto, SubmissionFilterDto } from './dto';
import { CurrentUser, Roles } from '../../common/decorators';
import { UserRole, SubmissionStatus } from '../../entities';

@ApiTags('提交')
@Controller('submissions')
export class SubmissionController {
  constructor(private submissionService: SubmissionService) {}

  @Post()
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '提交采集数据' })
  async create(
    @CurrentUser('userId') userId: string,
    @Body() dto: CreateSubmissionDto,
  ) {
    return this.submissionService.create(userId, dto);
  }

  @Get('mine')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '我的提交列表' })
  async findMine(
    @CurrentUser('userId') userId: string,
    @Query() filter: SubmissionFilterDto,
  ) {
    return this.submissionService.findByUser(
      userId,
      filter.status as SubmissionStatus,
      parseInt(filter.page || '1'),
      parseInt(filter.pageSize || '20'),
    );
  }

  @Get('pending-review')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '待审核列表' })
  async findPendingReview(
    @Query('page') page = 1,
    @Query('pageSize') pageSize = 20,
    @Query('taskId') taskId?: string,
  ) {
    return this.submissionService.findPendingReview(page, pageSize, taskId);
  }

  @Get('all')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '所有提交列表（管理）' })
  async findAll(
    @Query('page') page = 1,
    @Query('pageSize') pageSize = 20,
    @Query('status') status?: string,
    @Query('taskId') taskId?: string,
    @Query('userId') userId?: string,
    @Query('taskType') taskType?: string,
  ) {
    return this.submissionService.findAll({
      page,
      pageSize,
      status: status as SubmissionStatus,
      taskId,
      userId,
      taskType,
    });
  }

  @Get(':id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '提交详情' })
  async findOne(@Param('id') id: string) {
    // Admin can view any, user only their own (checked in service)
    return this.submissionService.findOne(id);
  }

  @Patch(':id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '修改提交' })
  async update(
    @Param('id') id: string,
    @CurrentUser('userId') userId: string,
    @Body() dto: CreateSubmissionDto,
  ) {
    return this.submissionService.update(id, userId, dto);
  }

  @Delete(':id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '删除草稿' })
  async remove(@Param('id') id: string, @CurrentUser('userId') userId: string) {
    await this.submissionService.remove(id, userId);
    return { success: true };
  }

  @Post(':id/approve')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '审核通过' })
  async approve(
    @Param('id') id: string,
    @CurrentUser('userId') userId: string,
  ) {
    return this.submissionService.approve(id, userId);
  }

  @Post(':id/reject')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '审核驳回' })
  async reject(
    @Param('id') id: string,
    @CurrentUser('userId') userId: string,
    @Body('reason') reason: string,
  ) {
    return this.submissionService.reject(id, userId, reason);
  }

  @Patch('admin/:id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '管理端修改提交' })
  async adminUpdate(
    @Param('id') id: string,
    @Body() dto: UpdateSubmissionDto,
  ) {
    return this.submissionService.adminUpdate(id, dto);
  }

  @Delete('admin/:id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '管理端删除提交' })
  async adminRemove(@Param('id') id: string) {
    await this.submissionService.adminRemove(id);
    return { success: true };
  }

  @Post('batch-delete')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '批量删除提交' })
  async batchRemove(@Body('ids') ids: string[]) {
    await this.submissionService.batchRemove(ids);
    return { success: true };
  }
}
