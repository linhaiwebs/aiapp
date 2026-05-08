import { IsString, IsNotEmpty, MinLength, MaxLength, IsOptional } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class RegisterDto {
  @ApiProperty({ description: '手机号', example: '13800138000' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(20)
  phone: string;

  @ApiProperty({ description: '密码', example: 'password123' })
  @IsString()
  @IsNotEmpty()
  @MinLength(6)
  @MaxLength(50)
  password: string;

  @ApiProperty({ description: '短信验证码', example: '123456' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(6)
  smsCode: string;

  @ApiProperty({ description: '昵称', required: false })
  @IsString()
  @IsOptional()
  @MaxLength(50)
  nickname?: string;
}

export class LoginDto {
  @ApiProperty({ description: '手机号' })
  @IsString()
  @IsNotEmpty()
  phone: string;

  @ApiProperty({ description: '密码' })
  @IsString()
  @IsNotEmpty()
  password: string;
}

export class SmsLoginDto {
  @ApiProperty({ description: '手机号' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(20)
  phone: string;

  @ApiProperty({ description: '短信验证码' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(6)
  smsCode: string;
}

export class SendSmsDto {
  @ApiProperty({ description: '手机号' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(20)
  phone: string;
}

export class WechatLoginDto {
  @ApiProperty({ description: '微信授权码' })
  @IsString()
  @IsNotEmpty()
  code: string;
}

export class QQLoginDto {
  @ApiProperty({ description: 'QQ授权码' })
  @IsString()
  @IsNotEmpty()
  code: string;
}

export class RefreshTokenDto {
  @ApiProperty({ description: '刷新令牌' })
  @IsString()
  @IsNotEmpty()
  refreshToken: string;
}

export class RealNameVerifyDto {
  @ApiProperty({ description: '真实姓名' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  realName: string;

  @ApiProperty({ description: '身份证号' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(20)
  idCardNumber: string;

  @ApiProperty({ description: '身份证正面照URL', required: false })
  @IsString()
  @IsOptional()
  idCardFrontUrl?: string;

  @ApiProperty({ description: '身份证背面照URL', required: false })
  @IsString()
  @IsOptional()
  idCardBackUrl?: string;
}
