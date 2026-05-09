import { IsString, IsOptional, IsDateString, IsBoolean, IsNumber } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateProjectDto {
  @ApiProperty({ description: '项目名称' })
  @IsString()
  name: string;

  @ApiProperty({ description: '项目描述', required: false })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiProperty({ description: '开始日期', required: false })
  @IsDateString()
  @IsOptional()
  startDate?: string;

  @ApiProperty({ description: '结束日期', required: false })
  @IsDateString()
  @IsOptional()
  endDate?: string;

  @ApiProperty({ description: '质检规则', required: false })
  @IsOptional()
  qcRules?: Record<string, any>;

  @ApiProperty({ description: '报酬模板', required: false })
  @IsOptional()
  paymentTemplate?: Record<string, any>;

  @ApiProperty({ description: '是否启用', required: false })
  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @ApiProperty({ description: '项目地区', required: false })
  @IsString()
  @IsOptional()
  region?: string;

  @ApiProperty({ description: '部门识别方式', required: false })
  @IsString()
  @IsOptional()
  department?: string;

  @ApiProperty({ description: '负责人ID', required: false })
  @IsString()
  @IsOptional()
  ownerId?: string;

  @ApiProperty({ description: '验收人ID', required: false })
  @IsString()
  @IsOptional()
  acceptorId?: string;

  @ApiProperty({ description: '是否需要授权签名', required: false })
  @IsBoolean()
  @IsOptional()
  requireSignature?: boolean;

  @ApiProperty({ description: '回收时间（小时）', required: false })
  @IsNumber()
  @IsOptional()
  recycleHours?: number;

  @ApiProperty({ description: '所属团队ID', required: false })
  @IsString()
  @IsOptional()
  teamId?: string;
}
