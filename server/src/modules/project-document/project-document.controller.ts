import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  Body,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ProjectDocumentService } from './project-document.service';
import { CreateProjectDocumentDto, BatchCreateProjectDocumentDto } from './dto';
import { Roles } from '../../common/decorators';
import { UserRole } from '../../entities';

@ApiTags('项目文档')
@Controller('projects/:projectId/documents')
export class ProjectDocumentController {
  constructor(private docService: ProjectDocumentService) {}

  @Get()
  @ApiOperation({ summary: '获取项目下的文档列表（不含内容）' })
  async list(@Param('projectId') projectId: string) {
    return this.docService.findByProject(projectId);
  }

  @Get(':docId')
  @ApiOperation({ summary: '获取单个文档详情（含内容）' })
  async detail(@Param('projectId') projectId: string, @Param('docId') docId: string) {
    return this.docService.findOne(projectId, docId);
  }

  @Post()
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '上传单个文档' })
  async create(@Param('projectId') projectId: string, @Body() dto: CreateProjectDocumentDto) {
    return this.docService.create(projectId, dto);
  }

  @Post('batch')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '批量上传文档' })
  async batchCreate(
    @Param('projectId') projectId: string,
    @Body() dto: BatchCreateProjectDocumentDto,
  ) {
    return this.docService.batchCreate(projectId, dto);
  }

  @Delete(':docId')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '删除文档' })
  async remove(@Param('projectId') projectId: string, @Param('docId') docId: string) {
    await this.docService.remove(projectId, docId);
    return { success: true };
  }
}
