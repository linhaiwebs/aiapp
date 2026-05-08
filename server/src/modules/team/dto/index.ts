import { IsString, IsOptional, IsBoolean, IsEmail } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateTeamDto {
  @ApiProperty({ description: '团队名称' })
  @IsString()
  name: string;

  @ApiProperty({ description: '团队描述', required: false })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiProperty({ description: '负责人ID', required: false })
  @IsString()
  @IsOptional()
  leaderId?: string;

  @ApiProperty({ description: '负责人名称', required: false })
  @IsString()
  @IsOptional()
  leaderName?: string;

  @ApiProperty({ description: '是否启用', required: false })
  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}

export class AddTeamMemberDto {
  @ApiProperty({ description: '用户ID' })
  @IsString()
  userId: string;

  @ApiProperty({ description: '用户名', required: false })
  @IsString()
  @IsOptional()
  userName?: string;

  @ApiProperty({ description: '手机号', required: false })
  @IsString()
  @IsOptional()
  phone?: string;

  @ApiProperty({ description: '邮箱', required: false })
  @IsEmail()
  @IsOptional()
  email?: string;

  @ApiProperty({ description: '角色', required: false, enum: ['leader', 'member'] })
  @IsString()
  @IsOptional()
  role?: 'leader' | 'member';
}

export class InviteMemberDto {
  @ApiProperty({ description: '手机号或邮箱' })
  @IsString()
  contact: string;

  @ApiProperty({ description: '用户名', required: false })
  @IsString()
  @IsOptional()
  userName?: string;
}
