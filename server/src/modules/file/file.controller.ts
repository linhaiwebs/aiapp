import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  Body,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  Req,
  Res,
  Headers,
  HttpStatus,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { AuthGuard } from '@nestjs/passport';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiConsumes } from '@nestjs/swagger';
import { Request, Response } from 'express';
import { FileService } from './file.service';
import { InitUploadDto, CompleteUploadDto } from './dto';
import { CurrentUser } from '../../common/decorators';

@ApiTags('文件')
@Controller('files')
export class FileController {
  constructor(private fileService: FileService) {}

  @Post('init')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '初始化文件上传' })
  async initUpload(
    @CurrentUser('userId') userId: string,
    @Body() dto: InitUploadDto,
  ) {
    return this.fileService.initUpload(userId, dto);
  }

  @Post('chunk')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: '上传文件分片' })
  @UseInterceptors(FileInterceptor('chunk'))
  async uploadChunk(
    @Body('fileId') fileId: string,
    @Body('chunkIndex') chunkIndex: number,
    @UploadedFile() chunk: Express.Multer.File,
  ) {
    return this.fileService.uploadChunk(
      fileId,
      parseInt(String(chunkIndex)),
      chunk.buffer,
    );
  }

  @Post('complete')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '完成文件上传' })
  async completeUpload(@Body() dto: CompleteUploadDto) {
    return this.fileService.completeUpload(dto);
  }

  @Post('upload')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: '简单文件上传(小文件)' })
  @UseInterceptors(FileInterceptor('file'))
  async simpleUpload(
    @CurrentUser('userId') userId: string,
    @UploadedFile() file: Express.Multer.File,
    @Body('taskId') taskId?: string,
    @Body('taskType') taskType?: string,
  ) {
    if (!file) {
      throw new BadRequestException('未接收到文件');
    }
    console.log(`[upload] start: userId=${userId}, name=${file.originalname}, size=${file.size}, mime=${file.mimetype}`);

    const initDto: InitUploadDto = {
      originalName: file.originalname,
      fileSize: file.size,
      mimeType: file.mimetype,
      taskId,
      taskType,
      totalChunks: 1,
    };

    try {
      const fileEntity = await this.fileService.initUpload(userId, initDto);
      await this.fileService.uploadChunk(fileEntity.id, 0, file.buffer);
      const result = await this.fileService.completeUpload({ fileId: fileEntity.id });
      console.log(`[upload] done: fileId=${result.id}, storedName=${result.storedName}`);
      return result;
    } catch (err) {
      console.error(`[upload] error:`, err instanceof Error ? err.message : err);
      throw err;
    }
  }

  @Get(':id/stream')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '流式播放文件（支持 Range 请求）' })
  async streamFile(
    @Param('id') id: string,
    @Res() res: Response,
    @Headers('range') rangeHeader?: string,
  ) {
    let range: { start: number; end: number } | undefined;

    if (rangeHeader) {
      const parts = rangeHeader.replace(/bytes=/, '').split('-');
      const start = parseInt(parts[0], 10);
      const end = parts[1] ? parseInt(parts[1], 10) : Infinity;
      range = { start, end: end === Infinity ? undefined! : end };
    }

    const { stream, mimeType, fileSize, fileName } = await this.fileService.getFileStream(id, range);

    res.set({
      'Content-Type': mimeType,
      'Accept-Ranges': 'bytes',
      'Content-Disposition': `inline; filename="${encodeURIComponent(fileName)}"`,
    });

    if (rangeHeader && range) {
      const end = range.end ?? fileSize - 1;
      const chunkSize = end - range.start + 1;
      res.status(HttpStatus.PARTIAL_CONTENT);
      res.set({
        'Content-Range': `bytes ${range.start}-${end}/${fileSize}`,
        'Content-Length': chunkSize,
      });
    } else {
      res.set({ 'Content-Length': fileSize });
    }

    stream.pipe(res);
  }

  @Get(':id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '获取文件信息' })
  async findOne(@Param('id') id: string) {
    const file = await this.fileService.findOne(id);
    const downloadUrl = await this.fileService.getDownloadUrl(id);
    return { ...file, downloadUrl };
  }

  @Get(':id/download-url')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '获取文件下载URL' })
  async getDownloadUrl(@Param('id') id: string) {
    const url = await this.fileService.getDownloadUrl(id);
    return { url };
  }

  @Delete(':id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '删除文件' })
  async remove(
    @Param('id') id: string,
    @CurrentUser('userId') userId: string,
  ) {
    await this.fileService.remove(id, userId);
    return { success: true };
  }
}
