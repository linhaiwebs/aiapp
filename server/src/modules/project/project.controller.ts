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
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ProjectService } from './project.service';
import { CreateProjectDto } from './dto';
import { Roles } from '../../common/decorators';
import { UserRole } from '../../entities';

@ApiTags('项目')
@Controller('projects')
export class ProjectController {
  constructor(private projectService: ProjectService) {}

  @Get()
  @ApiOperation({ summary: '项目列表' })
  async findAll(@Query('page') page = 1, @Query('pageSize') pageSize = 20) {
    return this.projectService.findAll(page, pageSize);
  }

  @Get(':id')
  @ApiOperation({ summary: '项目详情' })
  async findOne(@Param('id') id: string) {
    return this.projectService.findOne(id);
  }

  @Post()
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '创建项目' })
  async create(@Body() dto: CreateProjectDto) {
    return this.projectService.create(dto);
  }

  @Patch(':id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '更新项目' })
  async update(@Param('id') id: string, @Body() dto: CreateProjectDto) {
    return this.projectService.update(id, dto);
  }

  @Delete(':id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '删除项目' })
  async remove(@Param('id') id: string) {
    await this.projectService.remove(id);
    return { success: true };
  }

  @Get(':id/tasks')
  @ApiOperation({ summary: '获取项目下的任务列表' })
  async findTasks(
    @Param('id') id: string,
    @Query('page') page = 1,
    @Query('pageSize') pageSize = 10,
  ) {
    return this.projectService.findTasks(id, page, pageSize);
  }

  @Post(':id/tasks/batch')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '批量操作项目任务' })
  async batchTasks(
    @Param('id') id: string,
    @Body() dto: { action: string; ids: string[]; status?: string },
  ) {
    return this.projectService.batchTasks(id, dto);
  }
}
