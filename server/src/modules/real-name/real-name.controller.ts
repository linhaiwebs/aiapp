import { Controller, Post, Body, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { RealNameService } from './real-name.service';
import { CurrentUser } from '../../common/decorators';

@ApiTags('实名认证')
@Controller('real-name')
export class RealNameController {
  constructor(private readonly realNameService: RealNameService) {}

  @Post('ocr-front')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '身份证正面OCR识别' })
  async ocrFront(@Body('base64Str') base64Str: string) {
    return this.realNameService.ocrFront(base64Str);
  }

  @Post('ocr-back')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '身份证反面OCR识别' })
  async ocrBack(@Body('base64Str') base64Str: string) {
    return this.realNameService.ocrBack(base64Str);
  }

  @Post('verify')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '身份证实名认证（姓名+身份证号校验）' })
  async verifyIdentity(
    @CurrentUser('userId') userId: string,
    @Body('cardNo') cardNo: string,
    @Body('realName') realName: string,
  ) {
    const result = await this.realNameService.verifyIdentity(cardNo, realName);
    return { ...result, userId };
  }
}
