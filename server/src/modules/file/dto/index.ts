import { IsString, IsOptional, IsNumber, IsBoolean } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class InitUploadDto {
  @ApiProperty({ description: '原始文件名' })
  @IsString()
  originalName: string;

  @ApiProperty({ description: '文件大小(字节)' })
  @IsNumber()
  fileSize: number;

  @ApiProperty({ description: 'MIME类型' })
  @IsString()
  mimeType: string;

  @ApiProperty({ description: '任务ID', required: false })
  @IsString()
  @IsOptional()
  taskId?: string;

  @ApiProperty({ description: '任务类型', required: false })
  @IsString()
  @IsOptional()
  taskType?: string;

  @ApiProperty({ description: '总分片数' })
  @IsNumber()
  totalChunks: number;
}

export class UploadChunkDto {
  @ApiProperty({ description: '文件ID' })
  @IsString()
  fileId: string;

  @ApiProperty({ description: '分片序号(从0开始)' })
  @IsNumber()
  chunkIndex: number;

  @ApiProperty({ description: '是否最后一片' })
  @IsBoolean()
  isLast: boolean;
}

export class CompleteUploadDto {
  @ApiProperty({ description: '文件ID' })
  @IsString()
  fileId: string;
}
