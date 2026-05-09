import { IsString, IsOptional, IsEnum, IsNumber, IsBoolean } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';
import { TextFormat } from '../../../entities';

export class UploadTextDto {
  @ApiProperty({ description: '任务ID' })
  @IsString()
  taskId: string;

  @ApiProperty({ description: '文本内容（单条）' })
  @IsString()
  @IsOptional()
  content?: string;

  @ApiProperty({ description: '文本格式', enum: TextFormat, required: false })
  @IsEnum(TextFormat)
  @IsOptional()
  format?: TextFormat;

  @ApiProperty({ description: '排序序号', required: false })
  @IsNumber()
  @IsOptional()
  sortOrder?: number;
}

export class BatchUploadTextDto {
  @ApiProperty({ description: '任务ID' })
  @IsString()
  taskId: string;

  @ApiProperty({ description: '文本内容列表' })
  @IsOptional()
  texts?: string[];

  @ApiProperty({ description: '文本格式', enum: TextFormat, required: false })
  @IsEnum(TextFormat)
  @IsOptional()
  format?: TextFormat;
}

export class AssignTextDto {
  @ApiProperty({ description: '文本ID列表' })
  @IsOptional()
  textIds?: string[];

  @ApiProperty({ description: '分配给的用户ID' })
  @IsString()
  @IsOptional()
  assignedUserId?: string;

  @ApiProperty({ description: '是否平均分配', required: false })
  @IsBoolean()
  @IsOptional()
  autoAssign?: boolean;

  @ApiProperty({ description: '分配人数', required: false })
  @IsNumber()
  @IsOptional()
  assignCount?: number;

  @ApiProperty({ description: '每人分配条数（>0时优先于分配人数）', required: false })
  @IsNumber()
  @IsOptional()
  perUserCount?: number;

  @ApiProperty({ description: '是否复制多份分配', required: false })
  @IsBoolean()
  @IsOptional()
  copyForAssign?: boolean;
}

export class TextFilterDto {
  @IsString()
  @IsOptional()
  taskId?: string;

  @IsString()
  @IsOptional()
  status?: string;

  @IsString()
  @IsOptional()
  assignedUserId?: string;

  @Type(() => Number)
  @IsNumber()
  @IsOptional()
  page?: number;

  @Type(() => Number)
  @IsNumber()
  @IsOptional()
  pageSize?: number;
}
