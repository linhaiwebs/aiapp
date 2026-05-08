import { IsString, IsOptional, IsArray, IsEnum } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateSubmissionDto {
  @ApiProperty({ description: '任务领取ID' })
  @IsString()
  claimId: string;

  @ApiProperty({ description: '文件ID列表', required: false, type: [String] })
  @IsArray()
  @IsOptional()
  fileIds?: string[];

  @ApiProperty({ description: '采集数据', required: false })
  @IsOptional()
  data?: Record<string, any>;

  @ApiProperty({ description: '标注信息', required: false })
  @IsOptional()
  annotations?: Record<string, any>;
}

export class UpdateSubmissionDto {
  @IsArray()
  @IsOptional()
  fileIds?: string[];

  @IsOptional()
  data?: Record<string, any>;

  @IsOptional()
  annotations?: Record<string, any>;
}

export class SubmissionFilterDto {
  @IsString()
  @IsOptional()
  status?: string;

  @IsString()
  @IsOptional()
  taskId?: string;

  @IsOptional()
  @IsString()
  page?: string;

  @IsOptional()
  @IsString()
  pageSize?: string;
}
