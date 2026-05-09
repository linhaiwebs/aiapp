import { Injectable, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

// Inline type declarations to avoid compile-time dependency on @modelcontextprotocol/sdk
interface MCPClient {
  connect(transport: any): Promise<void>;
  callTool(params: { name: string; arguments: Record<string, string> }): Promise<{
    isError?: boolean;
    content: Array<{ type: string; text: string }>;
  }>;
}
interface MCPTransport {
  new(url: URL): any;
}

// Load MCP SDK via direct filesystem path
const path = require('path');
const mcpCjsDir = path.join(__dirname, '..', '..', '..', 'node_modules', '@modelcontextprotocol', 'sdk', 'dist', 'cjs');
const { Client: MCPClient } = require(path.join(mcpCjsDir, 'client', 'index.js'));
const { SSEClientTransport } = require(path.join(mcpCjsDir, 'client', 'sse.js'));

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
  private mcpClient: MCPClient | null = null;
  private mcpTransport: MCPTransport | null = null;
  private mcpConnected = false;
  private readonly mcpUrl: string;

  constructor(private configService: ConfigService) {
    this.mcpUrl = this.configService.get<string>('realName.mcpUrl', '');
    if (!this.mcpUrl) {
      console.warn('[RealName] MCP URL is empty, real-name verification will use mock mode.');
    }
  }

  private async ensureConnected(): Promise<void> {
    if (this.mcpConnected) return;

    if (!this.mcpUrl) {
      throw new BadRequestException('实名认证服务未配置');
    }

    try {
      this.mcpTransport = new SSEClientTransport(new URL(this.mcpUrl));
      this.mcpClient = new MCPClient(
        { name: 'xcai-realname', version: '1.0.0' },
        { capabilities: {} },
      );
      await this.mcpClient!.connect(this.mcpTransport);
      this.mcpConnected = true;
      console.log('[RealName] MCP client connected');
    } catch (error) {
      console.error('[RealName] MCP connection failed:', error);
      throw new BadRequestException('实名认证服务连接失败');
    }
  }

  /** OCR recognize front side of ID card */
  async ocrFront(base64Str: string): Promise<OcrFrontResult> {
    if (!base64Str) throw new BadRequestException('请提供身份证正面照片');

    if (!this.mcpUrl) {
      return this.mockOcrFront();
    }

    await this.ensureConnected();

    try {
      const result = await this.mcpClient!.callTool({
        name: '身份证OCR正面识别',
        arguments: { base64Str },
      });

      if (result.isError) {
        const errText = result.content
          .filter((c: any) => c.type === 'text')
          .map((c: any) => c.text)
          .join('; ');
        console.error('[RealName] OCR front failed:', errText);
        throw new BadRequestException(`身份证正面识别失败: ${errText || '未知错误'}`);
      }

      const textContent = result.content
        .filter((c: any) => c.type === 'text')
        .map((c: any) => c.text)
        .join('\n');

      const parsed = this.parseOcrFrontResult(textContent);
      console.log('[RealName] OCR front success');
      return parsed;
    } catch (error) {
      if (error instanceof BadRequestException) throw error;
      this.mcpConnected = false;
      console.error('[RealName] OCR front error:', error);
      throw new BadRequestException('身份证正面识别失败，请重试');
    }
  }

  /** OCR recognize back side of ID card */
  async ocrBack(base64Str: string): Promise<OcrBackResult> {
    if (!base64Str) throw new BadRequestException('请提供身份证反面照片');

    if (!this.mcpUrl) {
      return this.mockOcrBack();
    }

    await this.ensureConnected();

    try {
      const result = await this.mcpClient!.callTool({
        name: '身份证OCR反面识别',
        arguments: { base64Str },
      });

      if (result.isError) {
        const errText = result.content
          .filter((c: any) => c.type === 'text')
          .map((c: any) => c.text)
          .join('; ');
        console.error('[RealName] OCR back failed:', errText);
        throw new BadRequestException(`身份证反面识别失败: ${errText || '未知错误'}`);
      }

      const textContent = result.content
        .filter((c: any) => c.type === 'text')
        .map((c: any) => c.text)
        .join('\n');

      const parsed = this.parseOcrBackResult(textContent);
      console.log('[RealName] OCR back success');
      return parsed;
    } catch (error) {
      if (error instanceof BadRequestException) throw error;
      this.mcpConnected = false;
      console.error('[RealName] OCR back error:', error);
      throw new BadRequestException('身份证反面识别失败，请重试');
    }
  }

  /** Verify identity by name + ID number against official database */
  async verifyIdentity(cardNo: string, realName: string): Promise<VerifyResult> {
    if (!cardNo || !realName) throw new BadRequestException('请提供姓名和身份证号');

    if (!this.mcpUrl) {
      return this.mockVerify(cardNo, realName);
    }

    await this.ensureConnected();

    try {
      const result = await this.mcpClient!.callTool({
        name: '身份证实名认证接口',
        arguments: { cardNo, realName },
      });

      if (result.isError) {
        const errText = result.content
          .filter((c: any) => c.type === 'text')
          .map((c: any) => c.text)
          .join('; ');
        console.error('[RealName] Verify failed:', errText);
        throw new BadRequestException(`实名认证失败: ${errText || '未知错误'}`);
      }

      const textContent = result.content
        .filter((c: any) => c.type === 'text')
        .map((c: any) => c.text)
        .join('\n');

      const parsed = this.parseVerifyResult(textContent);
      console.log('[RealName] Verify success, match:', parsed.match);
      return parsed;
    } catch (error) {
      if (error instanceof BadRequestException) throw error;
      this.mcpConnected = false;
      console.error('[RealName] Verify error:', error);
      throw new BadRequestException('实名认证请求失败，请重试');
    }
  }

  private parseOcrFrontResult(text: string): OcrFrontResult {
    try {
      const data = JSON.parse(text);
      return {
        name: data.name || data.Name || '',
        idNumber: data.idNumber || data.IdNumber || data.num || '',
        birthDate: data.birthDate || data.BirthDate || data.birth || '',
        validFrom: data.validFrom || data.ValidFrom || data.startDate || '',
        validTo: data.validTo || data.ValidTo || data.endDate || '',
        raw: data,
      };
    } catch {
      return { name: '', idNumber: '', birthDate: '', validFrom: '', validTo: '', raw: { text } };
    }
  }

  private parseOcrBackResult(text: string): OcrBackResult {
    try {
      const data = JSON.parse(text);
      return {
        validFrom: data.validFrom || data.ValidFrom || data.startDate || '',
        validTo: data.validTo || data.ValidTo || data.endDate || '',
        issuingAuthority: data.issuingAuthority || data.IssuingAuthority || data.authority || '',
        raw: data,
      };
    } catch {
      return { validFrom: '', validTo: '', issuingAuthority: '', raw: { text } };
    }
  }

  private parseVerifyResult(text: string): VerifyResult {
    try {
      const data = JSON.parse(text);
      const match = data.match === true || data.isMatch === true || data.code === '0' || data.result === '1';
      return {
        match,
        message: data.message || data.msg || (match ? '认证通过' : '认证不通过'),
        raw: data,
      };
    } catch {
      const lower = text.toLowerCase();
      const match = lower.includes('一致') || lower.includes('通过') || lower.includes('true') || lower.includes('success');
      return { match, message: text.substring(0, 200), raw: { text } };
    }
  }

  // Mock implementations for development without MCP URL

  private mockOcrFront(): OcrFrontResult {
    console.log('[RealName] MOCK OCR front — returning dummy data');
    return {
      name: '张三',
      idNumber: '110101199001011234',
      birthDate: '1990-01-01',
      validFrom: '2020-01-01',
      validTo: '2040-01-01',
    };
  }

  private mockOcrBack(): OcrBackResult {
    console.log('[RealName] MOCK OCR back — returning dummy data');
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
