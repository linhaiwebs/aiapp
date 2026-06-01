import { IsString, IsOptional, IsEnum, IsNumber, IsDateString, IsBoolean } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { TaskType, TaskDifficulty, TaskStatus, QcMethod, AudioFormat, AudioChannel, SampleRate, TextAssignMode } from '../../../entities';

export class CreateTaskDto {
  @ApiProperty({ description: '任务标题' })
  @IsString()
  title: string;

  @ApiProperty({ description: '任务描述', required: false })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiPropertyOptional({ description: '任务类型（不传则继承所属项目的类型）', enum: TaskType })
  @IsEnum(TaskType)
  @IsOptional()
  type?: TaskType;

  @ApiProperty({ description: '任务状态', enum: TaskStatus, required: false, default: TaskStatus.DRAFT })
  @IsEnum(TaskStatus)
  @IsOptional()
  status?: TaskStatus;

  @ApiProperty({ description: '任务难度', enum: TaskDifficulty, required: false })
  @IsEnum(TaskDifficulty)
  @IsOptional()
  difficulty?: TaskDifficulty;

  @ApiProperty({ description: '单价' })
  @Type(() => Number)
  @IsNumber()
  unitPrice: number;

  @ApiProperty({ description: '总数量' })
  @Type(() => Number)
  @IsNumber()
  totalQuantity: number;

  @ApiProperty({ description: '每人限领数量', required: false })
  @IsNumber()
  @IsOptional()
  maxClaimsPerUser?: number;

  @ApiProperty({ description: '地域限制', required: false })
  @IsString()
  @IsOptional()
  region?: string;

  @ApiProperty({ description: '语言要求', required: false })
  @IsString()
  @IsOptional()
  language?: string;

  @ApiProperty({ description: '质量分要求', required: false })
  @Type(() => Number)
  @IsNumber()
  @IsOptional()
  minQualityScore?: number;

  @ApiProperty({ description: '合格率要求', required: false })
  @Type(() => Number)
  @IsNumber()
  @IsOptional()
  passRateRequirement?: number;

  @ApiProperty({ description: '截止时间', required: false })
  @IsDateString()
  @IsOptional()
  deadline?: string;

  @ApiProperty({ description: '任务说明', required: false })
  @IsString()
  @IsOptional()
  instructions?: string;

  @ApiProperty({ description: '项目ID', required: false })
  @IsString()
  @IsOptional()
  projectId?: string;

  @ApiProperty({ description: '分类ID', required: false })
  @IsString()
  @IsOptional()
  categoryId?: string;

  @ApiProperty({ description: '团队ID（设置后仅团队成员可见）', required: false })
  @IsString()
  @IsOptional()
  teamId?: string;

  @ApiProperty({ description: '质检配置', required: false })
  @IsOptional()
  qcConfig?: Record<string, any>;

  @ApiProperty({ description: '类型特定配置', required: false })
  @IsOptional()
  typeConfig?: Record<string, any>;

  // ===== 质检方式 =====
  @ApiProperty({ description: '质检方式', enum: QcMethod, required: false })
  @IsEnum(QcMethod)
  @IsOptional()
  qcMethod?: QcMethod;

  // ===== 音频配置 =====
  @ApiProperty({ description: '音频格式', enum: AudioFormat, required: false })
  @IsEnum(AudioFormat)
  @IsOptional()
  audioFormat?: AudioFormat;

  @ApiProperty({ description: '声道', enum: AudioChannel, required: false })
  @IsEnum(AudioChannel)
  @IsOptional()
  audioChannel?: AudioChannel;

  @ApiProperty({ description: '采样率', enum: SampleRate, required: false })
  @IsEnum(SampleRate)
  @IsOptional()
  sampleRate?: SampleRate;

  @ApiProperty({ description: '噪音上限(dB)', required: false })
  @IsNumber()
  @IsOptional()
  noiseLimit?: number;

  @ApiProperty({ description: '最大语音长度(秒)', required: false })
  @IsNumber()
  @IsOptional()
  maxSpeechLength?: number;

  @ApiProperty({ description: '静音区预留时间(ms)', required: false })
  @IsNumber()
  @IsOptional()
  silencePadding?: number;

  // ===== 机器辅助 =====
  @ApiProperty({ description: '辅助识别', required: false })
  @IsBoolean()
  @IsOptional()
  assistRecognition?: boolean;

  @ApiProperty({ description: '静音检测', required: false })
  @IsBoolean()
  @IsOptional()
  silenceDetection?: boolean;

  @ApiProperty({ description: '声纹检测', required: false })
  @IsBoolean()
  @IsOptional()
  voiceprintDetection?: boolean;

  @ApiProperty({ description: '增幅检测', required: false })
  @IsBoolean()
  @IsOptional()
  gainDetection?: boolean;

  @ApiProperty({ description: '信号检测', required: false })
  @IsBoolean()
  @IsOptional()
  signalDetection?: boolean;

  // ===== 任务分配 =====
  @ApiProperty({ description: '是否允许多次领取', required: false })
  @IsBoolean()
  @IsOptional()
  allowMultipleClaims?: boolean;

  @ApiProperty({ description: '验收轮数', required: false })
  @IsNumber()
  @IsOptional()
  reviewRounds?: number;

  @ApiProperty({ description: '是否要求采样审核', required: false })
  @IsBoolean()
  @IsOptional()
  requireSample?: boolean;

  @ApiProperty({ description: '回收时间(小时)', required: false })
  @IsNumber()
  @IsOptional()
  recycleHours?: number;

  @ApiProperty({ description: '文本分配人数', required: false })
  @IsNumber()
  @IsOptional()
  textAssignCount?: number;

  @ApiProperty({ description: '每人分配条数（>0时优先于分配人数）', required: false })
  @IsNumber()
  @IsOptional()
  textPerUserCount?: number;

  @ApiProperty({ description: '是否复制多份文本分配', required: false })
  @IsBoolean()
  @IsOptional()
  textCopyForAssign?: boolean;

  @ApiProperty({ description: '文本分配模式：auto=自动 | even=平均分配 | per_user=每人指定', enum: TextAssignMode, required: false })
  @IsEnum(TextAssignMode)
  @IsOptional()
  textAssignMode?: TextAssignMode;
}

export class UpdateTaskDto {
  @IsString()
  @IsOptional()
  title?: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsEnum(TaskType)
  @IsOptional()
  type?: TaskType;

  @IsEnum(TaskDifficulty)
  @IsOptional()
  difficulty?: TaskDifficulty;

  @Type(() => Number)
  @IsNumber()
  @IsOptional()
  unitPrice?: number;

  @Type(() => Number)
  @IsNumber()
  @IsOptional()
  totalQuantity?: number;

  @Type(() => Number)
  @IsNumber()
  @IsOptional()
  maxClaimsPerUser?: number;

  @IsString()
  @IsOptional()
  region?: string;

  @IsString()
  @IsOptional()
  language?: string;

  @Type(() => Number)
  @IsNumber()
  @IsOptional()
  minQualityScore?: number;

  @Type(() => Number)
  @IsNumber()
  @IsOptional()
  passRateRequirement?: number;

  @IsEnum(TaskStatus)
  @IsOptional()
  status?: TaskStatus;

  @IsDateString()
  @IsOptional()
  deadline?: string;

  @IsString()
  @IsOptional()
  instructions?: string;

  @IsString()
  @IsOptional()
  projectId?: string;

  @IsString()
  @IsOptional()
  categoryId?: string;

  @IsString()
  @IsOptional()
  teamId?: string;

  @IsOptional()
  qcConfig?: Record<string, any>;

  @IsOptional()
  typeConfig?: Record<string, any>;

  @IsEnum(QcMethod)
  @IsOptional()
  qcMethod?: QcMethod;

  @IsEnum(AudioFormat)
  @IsOptional()
  audioFormat?: AudioFormat;

  @IsEnum(AudioChannel)
  @IsOptional()
  audioChannel?: AudioChannel;

  @IsEnum(SampleRate)
  @IsOptional()
  sampleRate?: SampleRate;

  @IsNumber()
  @IsOptional()
  noiseLimit?: number;

  @IsNumber()
  @IsOptional()
  maxSpeechLength?: number;

  @IsNumber()
  @IsOptional()
  silencePadding?: number;

  @IsBoolean()
  @IsOptional()
  assistRecognition?: boolean;

  @IsBoolean()
  @IsOptional()
  silenceDetection?: boolean;

  @IsBoolean()
  @IsOptional()
  voiceprintDetection?: boolean;

  @IsBoolean()
  @IsOptional()
  gainDetection?: boolean;

  @IsBoolean()
  @IsOptional()
  signalDetection?: boolean;

  @IsBoolean()
  @IsOptional()
  allowMultipleClaims?: boolean;

  @IsNumber()
  @IsOptional()
  reviewRounds?: number;

  @IsBoolean()
  @IsOptional()
  requireSample?: boolean;

  @IsNumber()
  @IsOptional()
  recycleHours?: number;

  @IsNumber()
  @IsOptional()
  textAssignCount?: number;

  @IsNumber()
  @IsOptional()
  textPerUserCount?: number;

  @IsBoolean()
  @IsOptional()
  textCopyForAssign?: boolean;

  @IsEnum(TextAssignMode)
  @IsOptional()
  textAssignMode?: TextAssignMode;
}

export class TaskFilterDto {
  @IsEnum(TaskType)
  @IsOptional()
  type?: TaskType;

  @IsOptional()
  status?: string;

  @IsEnum(TaskDifficulty)
  @IsOptional()
  difficulty?: TaskDifficulty;

  @Type(() => Number)
  @IsNumber()
  @IsOptional()
  minPrice?: number;

  @Type(() => Number)
  @IsNumber()
  @IsOptional()
  maxPrice?: number;

  @IsString()
  @IsOptional()
  region?: string;

  @IsString()
  @IsOptional()
  language?: string;

  @IsString()
  @IsOptional()
  categoryId?: string;

  @IsString()
  @IsOptional()
  projectId?: string;

  @IsString()
  @IsOptional()
  teamId?: string;

  @IsString()
  @IsOptional()
  keyword?: string;

  @Type(() => Number)
  @IsNumber()
  @IsOptional()
  page?: number;

  @Type(() => Number)
  @IsNumber()
  @IsOptional()
  pageSize?: number;
}
