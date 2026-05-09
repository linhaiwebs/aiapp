import {
  Injectable,
  BadRequestException,
  ConflictException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcryptjs';
import { User, UserProfile, UserStatus, UserRole } from '../../entities';
import {
  RegisterDto,
  LoginDto,
  RefreshTokenDto,
  RealNameVerifyDto,
} from './dto';
import { SmsService } from '../sms/sms.service';
import { RealNameService } from '../real-name/real-name.service';

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(UserProfile)
    private profileRepository: Repository<UserProfile>,
    private jwtService: JwtService,
    private configService: ConfigService,
    private smsService: SmsService,
    private realNameService: RealNameService,
  ) {}

  async register(dto: RegisterDto) {
    // Verify SMS code via SmsService
    const isValid = await this.smsService.verifyCode(dto.phone, dto.smsCode);
    if (!isValid) {
      throw new BadRequestException('验证码错误或已过期');
    }

    const existing = await this.userRepository.findOne({
      where: { phone: dto.phone },
    });
    if (existing) {
      throw new ConflictException('该手机号已注册');
    }

    try {
      const hashedPassword = await bcrypt.hash(dto.password, 10);

      const user = this.userRepository.create({
        phone: dto.phone,
        password: hashedPassword,
        nickname: dto.nickname || `用户${dto.phone.slice(-4)}`,
      });

      const profile = this.profileRepository.create({
        user,
        userId: user.id,
      });

      user.profile = profile;
      await this.userRepository.save(user);

      this.smsService.consumeCode(dto.phone);

      const tokens = await this.generateTokens(user);
      return {
        user: this.sanitizeUser(user),
        ...tokens,
      };
    } catch (error) {
      // Don't consume the code if registration fails
      throw error;
    }
  }

  async login(dto: LoginDto) {
    const user = await this.userRepository.findOne({
      where: { phone: dto.phone },
    });

    if (!user) {
      throw new UnauthorizedException('手机号或密码错误');
    }

    if (user.status === UserStatus.BLACKLISTED) {
      throw new UnauthorizedException('该账号已被封禁');
    }

    const isPasswordValid = await bcrypt.compare(dto.password, user.password);
    if (!isPasswordValid) {
      throw new UnauthorizedException('手机号或密码错误');
    }

    const tokens = await this.generateTokens(user);
    return {
      user: this.sanitizeUser(user),
      ...tokens,
    };
  }

  async smsLogin(dto: { phone: string; smsCode: string }) {
    const isValid = await this.smsService.verifyCode(dto.phone, dto.smsCode);
    if (!isValid) {
      throw new UnauthorizedException('验证码错误或已过期');
    }

    try {
      let user = await this.userRepository.findOne({
        where: { phone: dto.phone },
      });

      if (!user) {
        // Auto-register on first SMS login
        const hashedPassword = await bcrypt.hash(Math.random().toString(36).slice(2), 10);
        user = this.userRepository.create({
          phone: dto.phone,
          password: hashedPassword,
          nickname: `用户${dto.phone.slice(-4)}`,
        });
        // Save user first to get the generated UUID
        await this.userRepository.save(user);

        // Then create and save profile with the user ID
        const profile = this.profileRepository.create({
          userId: user.id,
        });
        await this.profileRepository.save(profile);
      } else if (user.status === UserStatus.BLACKLISTED) {
        throw new UnauthorizedException('该账号已被封禁');
      }

      this.smsService.consumeCode(dto.phone);

      const tokens = await this.generateTokens(user);
      return {
        user: this.sanitizeUser(user),
        ...tokens,
      };
    } catch (error) {
      if (error instanceof UnauthorizedException) throw error;
      // Log the real error for debugging
      console.error('[SMS Login] Error:', error);
      throw new UnauthorizedException('登录失败，请重试');
    }
  }

  async wechatLogin(code: string) {
    // In production: exchange code for access_token + openid via WeChat API
    // Simplified here
    const openid = `wx_${code}`;
    let user = await this.userRepository.findOne({
      where: { wechatOpenId: openid },
    });

    if (!user) {
      user = this.userRepository.create({
        phone: `wx_${Date.now()}`,
        wechatOpenId: openid,
        nickname: '微信用户',
      });
      const profile = this.profileRepository.create({
        user,
        userId: user.id,
      });
      user.profile = profile;
      await this.userRepository.save(user);
    }

    const tokens = await this.generateTokens(user);
    return { user: this.sanitizeUser(user), ...tokens };
  }

  async qqLogin(code: string) {
    const openid = `qq_${code}`;
    let user = await this.userRepository.findOne({
      where: { qqOpenId: openid },
    });

    if (!user) {
      user = this.userRepository.create({
        phone: `qq_${Date.now()}`,
        qqOpenId: openid,
        nickname: 'QQ用户',
      });
      const profile = this.profileRepository.create({
        user,
        userId: user.id,
      });
      user.profile = profile;
      await this.userRepository.save(user);
    }

    const tokens = await this.generateTokens(user);
    return { user: this.sanitizeUser(user), ...tokens };
  }

  async refreshToken(dto: RefreshTokenDto) {
    try {
      const payload = this.jwtService.verify(dto.refreshToken, {
        secret: this.configService.get<string>('jwt.secret'),
      });

      const user = await this.userRepository.findOne({
        where: { id: payload.sub },
      });

      if (!user) {
        throw new UnauthorizedException();
      }

      return this.generateTokens(user);
    } catch {
      throw new UnauthorizedException('刷新令牌无效或已过期');
    }
  }

  async verifyRealName(userId: string, dto: RealNameVerifyDto) {
    const profile = await this.profileRepository.findOne({
      where: { userId },
    });

    if (!profile) {
      throw new BadRequestException('用户资料不存在');
    }

    // Call MCP real-name verification API
    const verifyResult = await this.realNameService.verifyIdentity(
      dto.idCardNumber,
      dto.realName,
    );

    if (!verifyResult.match) {
      profile.verificationStatus = 'rejected' as any;
      await this.profileRepository.save(profile);
      throw new BadRequestException(verifyResult.message || '实名认证不通过');
    }

    profile.realName = dto.realName;
    profile.idCardNumber = dto.idCardNumber;
    profile.idCardFrontUrl = dto.idCardFrontUrl ?? '';
    profile.idCardBackUrl = dto.idCardBackUrl ?? '';
    profile.verificationStatus = 'verified' as any;
    profile.verifiedAt = new Date();

    await this.profileRepository.save(profile);

    await this.userRepository.update(userId, {
      isRealNameVerified: true,
    });

    return { verified: true };
  }

  async sendSmsCode(phone: string) {
    return this.smsService.sendCode(phone);
  }

  async getMe(userId: string) {
    const user = await this.userRepository.findOne({
      where: { id: userId },
    });
    if (!user) {
      throw new UnauthorizedException('用户不存在');
    }
    return this.sanitizeUser(user);
  }

  private async generateTokens(user: User) {
    const payload = { sub: user.id, phone: user.phone, role: user.role };

    const accessToken = this.jwtService.sign(payload, {
      secret: this.configService.get<string>('jwt.secret'),
      expiresIn: this.configService.get<string>('jwt.accessExpiresIn'),
    });

    const refreshToken = this.jwtService.sign(payload, {
      secret: this.configService.get<string>('jwt.secret'),
      expiresIn: this.configService.get<string>('jwt.refreshExpiresIn'),
    });

    return { accessToken, refreshToken };
  }

  private sanitizeUser(user: User) {
    const { password, ...result } = user;
    return result;
  }
}
