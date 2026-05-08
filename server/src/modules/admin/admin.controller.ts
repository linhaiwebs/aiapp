import { Controller, Get, Query, UseGuards, Res } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { Response } from 'express';
import { AdminService } from './admin.service';
import { Roles } from '../../common/decorators';
import { UserRole } from '../../entities';

@ApiTags('管理后台')
@Controller('admin')
@UseGuards(AuthGuard('jwt'))
@ApiBearerAuth()
@Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
export class AdminController {
  constructor(private adminService: AdminService) {}

  @Get('stats')
  @ApiOperation({ summary: '后台统计数据' })
  async getStats() {
    return this.adminService.getStats();
  }

  @Get('stats/trends')
  @ApiOperation({ summary: '趋势数据' })
  async getTrends() {
    return this.adminService.getTrends();
  }

  @Get('export/tasks')
  @ApiOperation({ summary: '导出任务信息' })
  async exportTasks(
    @Query('projectId') projectId?: string,
    @Query('format') format?: string,
    @Res() res?: Response,
  ) {
    const data = await this.adminService.exportTasks(projectId);
    if (!res) return data;
    if (format === 'json') {
      res.setHeader('Content-Type', 'application/json');
      res.setHeader('Content-Disposition', 'attachment; filename=tasks.json');
      res.json(data);
    } else {
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', 'attachment; filename=tasks.csv');
      res.send(this.adminService.toCSV(data, ['id', 'title', 'type', 'status', 'unitPrice', 'totalQuantity', 'claimedQuantity', 'completedQuantity', 'region', 'language', 'createdAt']));
    }
  }

  @Get('export/submissions')
  @ApiOperation({ summary: '导出采集信息' })
  async exportSubmissions(
    @Query('taskId') taskId?: string,
    @Query('format') format?: string,
    @Res() res?: Response,
  ) {
    const data = await this.adminService.exportSubmissions(taskId);
    if (!res) return data;
    if (format === 'json') {
      res.setHeader('Content-Type', 'application/json');
      res.setHeader('Content-Disposition', 'attachment; filename=submissions.json');
      res.json(data);
    } else {
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', 'attachment; filename=submissions.csv');
      res.send(this.adminService.toCSV(data, ['id', 'userId', 'taskId', 'status', 'qcScore', 'submittedAt', 'reviewedAt', 'rejectReason', 'createdAt']));
    }
  }

  @Get('export/audio-links')
  @ApiOperation({ summary: '导出音频文件链接' })
  async exportAudioLinks(
    @Query('taskId') taskId?: string,
    @Res() res?: Response,
  ) {
    const data = await this.adminService.exportAudioLinks(taskId);
    if (!res) return data;
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Content-Disposition', 'attachment; filename=audio_links.json');
    res.json(data);
  }
}
