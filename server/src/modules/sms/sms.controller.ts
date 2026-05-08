import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { SmsService } from './sms.service';

@ApiTags('短信验证码')
@Controller('sms')
export class SmsController {
  constructor(private readonly smsService: SmsService) {}

  @Get('logs')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '查看验证码发送记录（管理员）' })
  @ApiQuery({ name: 'phone', required: false, description: '按手机号筛选' })
  getLogs(@Query('phone') phone?: string) {
    return {
      items: this.smsService.getLogs(phone),
      total: this.smsService.getLogs(phone).length,
    };
  }
}
