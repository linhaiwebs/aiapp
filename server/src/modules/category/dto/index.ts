import { IsString, IsOptional, IsBoolean, IsNumber, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateCategoryDto {
  @ApiProperty({ description: '分类名称' })
  @IsString()
  @MaxLength(50)
  name: string;

  @ApiProperty({ description: '分类编码' })
  @IsString()
  @MaxLength(50)
  code: string;

  @ApiProperty({ description: '类型(audio/image/video)' })
  @IsString()
  @MaxLength(20)
  type: string;

  @ApiProperty({ description: '描述', required: false })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiProperty({ description: '是否启用', required: false })
  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @ApiProperty({ description: '排序', required: false })
  @IsNumber()
  @IsOptional()
  sortOrder?: number;
}
