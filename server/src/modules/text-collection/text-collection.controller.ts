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
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiConsumes } from '@nestjs/swagger';
import { TextCollectionService } from './text-collection.service';
import { UploadTextDto, BatchUploadTextDto, AssignTextDto, TextFilterDto } from './dto';
import { CurrentUser, Roles } from '../../common/decorators';
import { UserRole, TextStatus } from '../../entities';

@ApiTags('文本采集')
@Controller('text-collections')
export class TextCollectionController {
  constructor(private textService: TextCollectionService) {}

  @Get()
  @ApiOperation({ summary: '文本列表' })
  async findAll(@Query() filter: TextFilterDto) {
    return this.textService.findAll(filter);
  }

  @Get('stats/:taskId')
  @ApiOperation({ summary: '文本统计' })
  async getStats(@Param('taskId') taskId: string) {
    return this.textService.getTextStats(taskId);
  }

  @Get(':id')
  @ApiOperation({ summary: '文本详情' })
  async findOne(@Param('id') id: string) {
    return this.textService.findOne(id);
  }

  @Post()
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '上传单条文本' })
  async create(@Body() dto: UploadTextDto) {
    return this.textService.upload(dto);
  }

  @Post('batch')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '批量上传文本' })
  async batchCreate(@Body() dto: BatchUploadTextDto) {
    return this.textService.batchUpload(dto);
  }

  @Post('upload-template/:taskId')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: '上传文本模板文件' })
  @UseInterceptors(FileInterceptor('file'))
  async uploadTemplate(
    @Param('taskId') taskId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    const content = file.buffer.toString('utf-8');
    const format = file.originalname.endsWith('.sml') ? 'sml' : 'plain';
    return this.textService.uploadFromTemplate(taskId, content, format, file.originalname);
  }

  @Post('assign')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '分配文本' })
  async assign(@Body() dto: AssignTextDto) {
    return this.textService.assignTexts(dto);
  }

  @Post('recycle')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '回收过期文本' })
  async recycle() {
    return this.textService.recycleExpiredTexts();
  }

  @Get('mine')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '获取我分配到的文本列表' })
  async getMyTexts(
    @Query('claimId') claimId: string,
    @CurrentUser('userId') userId: string,
  ) {
    return this.textService.getMyTexts(claimId, userId);
  }

  @Patch(':id/status')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '更新文本采集状态' })
  async updateStatus(
    @Param('id') id: string,
    @CurrentUser('userId') userId: string,
    @Body('status') status: TextStatus,
    @Body('fileId') fileId?: string,
  ) {
    return this.textService.updateTextStatus(id, status, userId, fileId);
  }

  @Patch(':id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '更新文本' })
  async update(@Param('id') id: string, @Body() dto: Partial<Record<string, any>>) {
    return this.textService.update(id, dto);
  }

  @Delete(':id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '删除文本' })
  async remove(@Param('id') id: string) {
    await this.textService.remove(id);
    return { success: true };
  }
}
