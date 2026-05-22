import { Controller, Get, Post, Body } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';

@ApiTags('应用')
@Controller('app')
export class AppController {
  @Get('version')
  @ApiOperation({ summary: '获取最新版本信息（APP 热更新检查）' })
  getVersion() {
    return {
      version: process.env.APP_VERSION || '0.1.0',
      versionCode: parseInt(process.env.APP_VERSION_CODE || '1', 10),
      downloadUrl: process.env.APP_DOWNLOAD_URL || 'https://blackend.duanfukeji.com/dist/app-release.apk',
      changelog: process.env.APP_CHANGELOG || '',
      forceUpdate: process.env.APP_FORCE_UPDATE === 'true',
    };
  }

  @Post('log')
  @ApiOperation({ summary: '客户端调试日志（仅打印到服务端控制台）' })
  clientLog(@Body() body: { tag: string; msg: string }) {
    console.log(`[CLIENT:${body.tag || 'INFO'}] ${body.msg || ''}`);
    return { ok: true };
  }
}
