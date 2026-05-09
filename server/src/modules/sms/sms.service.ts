import { Injectable, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as https from 'https';
import * as querystring from 'querystring';

interface SmsRecord {
  code: string;
  sentAt: number;
  verified: boolean;
}

export interface SmsLogEntry {
  phone: string;
  code: string;
  sentAt: string;
  verified: boolean;
  expired: boolean;
  provider: string;
}

@Injectable()
export class SmsService {
  private store = new Map<string, SmsRecord>();
  private dailyCount = new Map<string, number>();
  private dailyResetDate = new Date().toDateString();
  private logs: SmsLogEntry[] = [];
  private readonly maxLogs = 500;

  private readonly provider: string;
  private readonly codeLength: number;
  private readonly codeTtlMs: number;
  private readonly cooldownMs: number;
  private readonly maxSendPerDay: number;

  // Market SMS config
  private readonly marketHost: string;
  private readonly marketPath: string;
  private readonly appCode: string;
  private readonly templateId: string;

  constructor(private configService: ConfigService) {
    this.provider = this.configService.get<string>('sms.provider', 'mock');
    this.codeLength = this.configService.get<number>('sms.codeLength', 6);
    this.codeTtlMs = this.configService.get<number>('sms.codeTtlSeconds', 300) * 1000;
    this.cooldownMs = this.configService.get<number>('sms.codeCooldownSeconds', 60) * 1000;
    this.maxSendPerDay = this.configService.get<number>('sms.maxSendPerDay', 10);

    this.marketHost = this.configService.get<string>('sms.marketHost', 'send.market.alicloudapi.com');
    this.marketPath = this.configService.get<string>('sms.marketPath', '/sms/send');
    this.appCode = this.configService.get<string>('sms.appCode', '');
    this.templateId = this.configService.get<string>('sms.templateId', 'lxym_20111_sdgsfhwqgvyh');

    if (this.provider === 'market') {
      if (!this.appCode) {
        console.warn('[SMS] Market SMS configured but appCode is empty. Falling back to mock mode.');
      } else {
        console.log(`[SMS] Market SMS client initialized — host: ${this.marketHost}${this.marketPath}`);
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

    let activeProvider: string;

    if (this.provider === 'market' && this.appCode) {
      try {
        await this.sendViaMarket(phone, code);
        activeProvider = 'market';
      } catch (marketError: any) {
        console.warn(`[SMS] Market send failed, falling back to mock. Error: ${marketError.message}`);
        console.log(`[SMS MOCK] Phone: ${phone}, Code: ${code}`);
        activeProvider = 'mock';
      }
    } else {
      console.log(`[SMS MOCK] Phone: ${phone}, Code: ${code}`);
      activeProvider = 'mock';
    }

    this.store.set(phone, { code, sentAt: Date.now(), verified: false });
    this.dailyCount.set(phone, dailySent + 1);
    this.addLog({
      phone,
      code,
      sentAt: new Date().toISOString(),
      verified: false,
      expired: false,
      provider: activeProvider,
    });

    if (activeProvider !== 'mock') {
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

    return true;
  }

  consumeCode(phone: string) {
    const record = this.store.get(phone);
    if (record) {
      record.verified = true;
      this.updateLogVerified(phone, true, false);
      this.store.delete(phone);
    }
  }

  getLogs(phone?: string): SmsLogEntry[] {
    let result = [...this.logs].reverse();
    if (phone) {
      result = result.filter(l => l.phone.includes(phone));
    }
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

  // ── Market SMS via Alibaba Cloud API Gateway (APPCODE auth) ──

  private sendViaMarket(phone: string, code: string): Promise<void> {
    const body = querystring.stringify({
      mobile: phone,
      templateid: this.templateId,
      content: `code:${code}`,
    });

    const options = {
      hostname: this.marketHost,
      path: this.marketPath,
      method: 'POST',
      headers: {
        'Authorization': `APPCODE ${this.appCode}`,
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Content-Length': Buffer.byteLength(body),
      },
    };

    return new Promise((resolve, reject) => {
      const req = https.request(options, (res) => {
        let data = '';
        res.on('data', (chunk: Buffer) => data += chunk.toString());
        res.on('end', () => {
          console.log(`[SMS] Market API response: ${res.statusCode} — ${data.substring(0, 200)}`);
          try {
            const result = JSON.parse(data);
            // Common success codes: 0, 200, "OK", { code: 0, returnCode: 0 }
            const successCode = result.code === 0 || result.code === '0'
              || result.returnCode === 0 || result.returnCode === '0'
              || result.success === true
              || res.statusCode === 200;

            if (successCode || res.statusCode === 200) {
              console.log(`[SMS] Code sent to ${phone} via Market API`);
              resolve();
            } else {
              const errMsg = result.message || result.msg || result.returnMsg || JSON.stringify(result);
              reject(new Error(`Market API returned error: ${errMsg}`));
            }
          } catch {
            // If response is not JSON but status is 200, treat as success
            if (res.statusCode === 200) {
              console.log(`[SMS] Code sent to ${phone} via Market API`);
              resolve();
            } else {
              reject(new Error(`Market API returned status ${res.statusCode}: ${data.substring(0, 200)}`));
            }
          }
        });
      });

      req.on('error', (error) => {
        console.error('[SMS] Market API request failed:', error.message);
        reject(new Error(`Market API request failed: ${error.message}`));
      });

      req.setTimeout(10000, () => {
        req.destroy();
        reject(new Error('Market API request timed out'));
      });

      req.write(body);
      req.end();
    });
  }
}
