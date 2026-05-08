import { Injectable, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Dysmsapi20170525, * as dysmsapi from '@alicloud/dysmsapi20170525';
import * as OpenApi from '@alicloud/openapi-client';
import * as Util from '@alicloud/tea-util';

interface SmsRecord {
  code: string;
  sentAt: number;     // timestamp ms
  verified: boolean;
}

/** 验证码日志条目（供后台查询） */
export interface SmsLogEntry {
  phone: string;
  code: string;
  sentAt: string;     // ISO date
  verified: boolean;
  expired: boolean;
  provider: string;
}

@Injectable()
export class SmsService {
  private client: Dysmsapi20170525 | null = null;
  private store = new Map<string, SmsRecord>();
  private dailyCount = new Map<string, number>();
  private dailyResetDate = new Date().toDateString();

  /** 验证码发送日志（保留最近 500 条） */
  private logs: SmsLogEntry[] = [];
  private readonly maxLogs = 500;

  private readonly provider: string;
  private readonly signName: string;
  private readonly templateCode: string;
  private readonly codeLength: number;
  private readonly codeTtlMs: number;
  private readonly cooldownMs: number;
  private readonly maxSendPerDay: number;

  constructor(private configService: ConfigService) {
    this.provider = this.configService.get<string>('sms.provider', 'mock');
    this.signName = this.configService.get<string>('sms.signName', '');
    this.templateCode = this.configService.get<string>('sms.templateCode', '');
    this.codeLength = this.configService.get<number>('sms.codeLength', 6);
    this.codeTtlMs = this.configService.get<number>('sms.codeTtlSeconds', 300) * 1000;
    this.cooldownMs = this.configService.get<number>('sms.codeCooldownSeconds', 60) * 1000;
    this.maxSendPerDay = this.configService.get<number>('sms.maxSendPerDay', 10);

    if (this.provider === 'aliyun') {
      const accessKeyId = this.configService.get<string>('sms.accessKeyId', '');
      const accessKeySecret = this.configService.get<string>('sms.accessKeySecret', '');
      if (!accessKeyId || !accessKeySecret) {
        console.warn('[SMS] Aliyun SMS configured but accessKeyId/accessKeySecret is empty. Falling back to mock mode.');
      } else {
        const config = new OpenApi.Config({
          accessKeyId,
          accessKeySecret,
          endpoint: 'dysmsapi.aliyuncs.com',
        });
        this.client = new Dysmsapi20170525(config);
        console.log('[SMS] Aliyun SMS client initialized');
      }
    } else {
      console.log('[SMS] Using mock SMS provider (codes logged to console)');
    }
  }

  async sendCode(phone: string): Promise<{ success: boolean; message: string; code?: string }> {
    const today = new Date().toDateString();
    if (today !== this.dailyResetDate) {
      this.dailyCount.clear();
      this.dailyResetDate = today;
    }

    const dailySent = this.dailyCount.get(phone) || 0;
    if (dailySent >= this.maxSendPerDay) {
      throw new BadRequestException('今日发送次数已达上限');
    }

    const existing = this.store.get(phone);
    if (existing && Date.now() - existing.sentAt < this.cooldownMs) {
      const remainingSec = Math.ceil((this.cooldownMs - (Date.now() - existing.sentAt)) / 1000);
      throw new BadRequestException(`请${remainingSec}秒后再试`);
    }

    const code = this.generateCode();

    if (this.provider === 'aliyun' && this.client) {
      await this.sendViaAliyun(phone, code);
    } else {
      console.log(`[SMS MOCK] Phone: ${phone}, Code: ${code}`);
    }

    // Store code
    this.store.set(phone, { code, sentAt: Date.now(), verified: false });
    this.dailyCount.set(phone, dailySent + 1);

    // Record log
    this.addLog({
      phone,
      code,
      sentAt: new Date().toISOString(),
      verified: false,
      expired: false,
      provider: this.provider === 'aliyun' && this.client ? 'aliyun' : 'mock',
    });

    if (this.provider === 'aliyun' && this.client) {
      return { success: true, message: '验证码已发送' };
    }
    return { success: true, message: '验证码已发送（Mock模式）', code };
  }

  async verifyCode(phone: string, code: string): Promise<boolean> {
    const record = this.store.get(phone);
    if (!record) return false;

    if (Date.now() - record.sentAt > this.codeTtlMs) {
      this.store.delete(phone);
      this.updateLogVerified(phone, false, true);
      return false;
    }

    if (record.code !== code) return false;

    // Don't delete yet — consumeCode() will delete after login succeeds
    return true;
  }

  /** 登录成功后消费验证码，防止重复使用 */
  consumeCode(phone: string) {
    const record = this.store.get(phone);
    if (record) {
      record.verified = true;
      this.updateLogVerified(phone, true, false);
      this.store.delete(phone);
    }
  }

  /** 查询验证码日志 */
  getLogs(phone?: string): SmsLogEntry[] {
    let result = [...this.logs].reverse(); // newest first
    if (phone) {
      result = result.filter(l => l.phone.includes(phone));
    }
    // Mark expired entries
    const now = Date.now();
    return result.map(l => ({
      ...l,
      expired: !l.verified && !l.expired && (now - new Date(l.sentAt).getTime()) > this.codeTtlMs,
    }));
  }

  private addLog(entry: SmsLogEntry) {
    this.logs.push(entry);
    if (this.logs.length > this.maxLogs) {
      this.logs = this.logs.slice(-this.maxLogs);
    }
  }

  private updateLogVerified(phone: string, verified: boolean, expired: boolean) {
    // Find the most recent log for this phone
    for (let i = this.logs.length - 1; i >= 0; i--) {
      if (this.logs[i].phone === phone) {
        this.logs[i].verified = verified;
        this.logs[i].expired = expired;
        break;
      }
    }
  }

  private generateCode(): string {
    const digits = '0123456789';
    let code = '';
    for (let i = 0; i < this.codeLength; i++) {
      code += digits[Math.floor(Math.random() * 10)];
    }
    return code;
  }

  private async sendViaAliyun(phone: string, code: string): Promise<void> {
    const request = new dysmsapi.SendSmsRequest({
      phoneNumbers: phone,
      signName: this.signName,
      templateCode: this.templateCode,
      templateParam: JSON.stringify({ code }),
    });

    const runtime = new Util.RuntimeOptions({});

    try {
      const response = await this.client!.sendSmsWithOptions(request, runtime);
      if (response.body?.code !== 'OK') {
        console.error('[SMS] Aliyun send failed:', response.body?.code, response.body?.message);
        throw new BadRequestException(`短信发送失败: ${response.body?.message || '未知错误'}`);
      }
      console.log(`[SMS] Code sent to ${phone} via Aliyun`);
    } catch (error) {
      if (error instanceof BadRequestException) throw error;
      console.error('[SMS] Aliyun send error:', error);
      throw new BadRequestException('短信发送失败，请稍后重试');
    }
  }
}
