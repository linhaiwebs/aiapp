import { Injectable, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as https from 'https';

export interface OcrFrontResult {
  name: string;
  idNumber: string;
  birthDate: string;
  validFrom: string;
  validTo: string;
  raw?: any;
}

export interface OcrBackResult {
  validFrom: string;
  validTo: string;
  issuingAuthority: string;
  raw?: any;
}

export interface VerifyResult {
  match: boolean;
  message: string;
  raw?: any;
}

@Injectable()
export class RealNameService {
  private readonly appCode: string;
  private readonly verifyHost: string;
  private readonly verifyPath: string;
  private readonly ocrHost: string;
  private readonly ocrFrontPath: string;
  private readonly ocrBackPath: string;
  private readonly enabled: boolean;

  constructor(private configService: ConfigService) {
    this.appCode = this.configService.get<string>('realName.appCode', '');
    this.verifyHost = this.configService.get<string>('realName.verifyHost', 'zidv2.market.alicloudapi.com');
    this.verifyPath = this.configService.get<string>('realName.verifyPath', '/idcheck/Post');
    this.ocrHost = this.configService.get<string>('realName.ocrHost', 'zidv2.market.alicloudapi.com');
    this.ocrFrontPath = this.configService.get<string>('realName.ocrFrontPath', '/thirdnode/ImageAI/idcardfrontrecongnition');
    this.ocrBackPath = this.configService.get<string>('realName.ocrBackPath', '/thirdnode/ImageAI/idcardbackrecongnition');
    this.enabled = !!this.appCode;

    if (this.enabled) {
      console.log(`[RealName] API client initialized — host: ${this.verifyHost}`);
    } else {
      console.warn('[RealName] appCode not configured, will use mock mode.');
    }
  }

  async ocrFront(base64Str: string): Promise<OcrFrontResult> {
    if (!base64Str) throw new BadRequestException('请提供身份证正面照片');

    if (!this.enabled) {
      return this.mockOcrFront();
    }

    try {
      const body = JSON.stringify({ base64Str });
      const data = await this.httpPost(this.ocrHost, this.ocrFrontPath, body);
      const parsed = typeof data === 'string' ? JSON.parse(data) : data;
      console.log('[RealName] OCR front success');
      return {
        name: parsed.name || parsed.Name || '',
        idNumber: parsed.idNumber || parsed.IdNumber || parsed.num || parsed.cardNo || '',
        birthDate: parsed.birthDate || parsed.BirthDate || parsed.birth || '',
        validFrom: parsed.validFrom || parsed.ValidFrom || parsed.startDate || '',
        validTo: parsed.validTo || parsed.ValidTo || parsed.endDate || '',
        raw: parsed,
      };
    } catch (error) {
      if (error instanceof BadRequestException) throw error;
      console.error('[RealName] OCR front error:', error);
      throw new BadRequestException('身份证正面识别失败，请重试');
    }
  }

  async ocrBack(base64Str: string): Promise<OcrBackResult> {
    if (!base64Str) throw new BadRequestException('请提供身份证反面照片');

    if (!this.enabled) {
      return this.mockOcrBack();
    }

    try {
      const body = JSON.stringify({ base64Str });
      const data = await this.httpPost(this.ocrHost, this.ocrBackPath, body);
      const parsed = typeof data === 'string' ? JSON.parse(data) : data;
      console.log('[RealName] OCR back success');
      return {
        validFrom: parsed.validFrom || parsed.ValidFrom || parsed.startDate || '',
        validTo: parsed.validTo || parsed.ValidTo || parsed.endDate || '',
        issuingAuthority: parsed.issuingAuthority || parsed.IssuingAuthority || parsed.authority || '',
        raw: parsed,
      };
    } catch (error) {
      if (error instanceof BadRequestException) throw error;
      console.error('[RealName] OCR back error:', error);
      throw new BadRequestException('身份证反面识别失败，请重试');
    }
  }

  async verifyIdentity(cardNo: string, realName: string): Promise<VerifyResult> {
    if (!cardNo || !realName) throw new BadRequestException('请提供姓名和身份证号');

    if (!this.enabled) {
      return this.mockVerify(cardNo, realName);
    }

    try {
      const body = JSON.stringify({ cardNo, realName });
      const data = await this.httpPost(this.verifyHost, this.verifyPath, body);
      const parsed = typeof data === 'string' ? JSON.parse(data) : data;

      // Handle various response formats
      const code = parsed.code || parsed.status || parsed.returnCode || '';
      const msg = parsed.message || parsed.msg || parsed.desc || '';
      const match =
        code === '0' || code === '00' || code === '200' ||
        parsed.isMatch === true || parsed.match === true ||
        String(msg).includes('一致') || String(msg).includes('通过');

      console.log('[RealName] Verify result:', match ? 'MATCH' : 'NO MATCH', msg);
      return {
        match,
        message: msg || (match ? '认证通过' : '认证不通过'),
        raw: parsed,
      };
    } catch (error) {
      if (error instanceof BadRequestException) throw error;
      console.error('[RealName] Verify error:', error);
      throw new BadRequestException('实名认证请求失败，请重试');
    }
  }

  // ── HTTP helper ──

  private httpPost(hostname: string, path: string, body: string): Promise<any> {
    return new Promise((resolve, reject) => {
      const options = {
        hostname,
        path,
        method: 'POST',
        headers: {
          'Authorization': `APPCODE ${this.appCode}`,
          'Content-Type': 'application/json; charset=UTF-8',
          'Content-Length': Buffer.byteLength(body),
        },
      };

      const req = https.request(options, (res) => {
        let data = '';
        res.on('data', (chunk: Buffer) => data += chunk.toString());
        res.on('end', () => {
          console.log(`[RealName] API response: ${res.statusCode} — ${data.substring(0, 200)}`);
          if (res.statusCode === 200) {
            try {
              resolve(JSON.parse(data));
            } catch {
              resolve(data);
            }
          } else {
            reject(new Error(`API returned status ${res.statusCode}: ${data.substring(0, 200)}`));
          }
        });
      });

      req.on('error', (error) => {
        console.error('[RealName] API request failed:', error.message);
        reject(new Error(`API request failed: ${error.message}`));
      });

      req.setTimeout(15000, () => {
        req.destroy();
        reject(new Error('API request timed out'));
      });

      req.write(body);
      req.end();
    });
  }

  // ── Mock fallbacks ──

  private mockOcrFront(): OcrFrontResult {
    console.log('[RealName] MOCK OCR front');
    return {
      name: '张三',
      idNumber: '110101199001011234',
      birthDate: '1990-01-01',
      validFrom: '2020-01-01',
      validTo: '2040-01-01',
    };
  }

  private mockOcrBack(): OcrBackResult {
    console.log('[RealName] MOCK OCR back');
    return {
      validFrom: '2020-01-01',
      validTo: '2040-01-01',
      issuingAuthority: '北京市公安局朝阳分局',
    };
  }

  private mockVerify(cardNo: string, realName: string): VerifyResult {
    console.log(`[RealName] MOCK verify — cardNo=${cardNo}, name=${realName}`);
    return { match: true, message: '认证通过（Mock模式）' };
  }
}
