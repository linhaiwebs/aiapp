import { Injectable, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcryptjs';
import { User, UserProfile, UserRole, UserStatus } from '../../entities';

@Injectable()
export class SeedService implements OnModuleInit {
  constructor(
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(UserProfile)
    private readonly profileRepo: Repository<UserProfile>,
  ) {}

  async onModuleInit() {
    await this.seedSuperAdmin();
  }

  private async seedSuperAdmin() {
    const existing = await this.userRepo.findOne({
      where: { role: UserRole.SUPER_ADMIN },
    });

    if (existing) {
      return; // Already seeded
    }

    const admin = this.userRepo.create({
      phone: '13800000000',
      password: await bcrypt.hash('admin123', 10),
      nickname: '超级管理员',
      role: UserRole.SUPER_ADMIN,
      status: UserStatus.ACTIVE,
      qualityScore: 100,
      isRealNameVerified: true,
    });

    const profile = this.profileRepo.create({
      user: admin,
      userId: admin.id,
      realName: '系统管理员',
      verificationStatus: 'verified' as any,
      verifiedAt: new Date(),
    });

    admin.profile = profile;
    await this.userRepo.save(admin);

    console.log('');
    console.log('🎉 ============================================');
    console.log('   默认管理员账号已自动创建');
    console.log('   手机号: 13800000000');
    console.log('   密码:   admin123');
    console.log('   ⚠️  请登录后立即修改密码！');
    console.log('============================================');
    console.log('');

    // Create leader
    const leaderPhone = '13800000001';
    const existingLeader = await this.userRepo.findOne({ where: { phone: leaderPhone } });
    if (!existingLeader) {
      const leader = this.userRepo.create({
        phone: leaderPhone,
        password: await bcrypt.hash('leader123', 10),
        nickname: '团长',
        role: UserRole.LEADER,
        status: UserStatus.ACTIVE,
        qualityScore: 100,
        isRealNameVerified: true,
        companyName: '示例科技有限公司',
      });
      const leaderProfile = this.profileRepo.create({
        user: leader,
        userId: leader.id,
        realName: '团长',
        verificationStatus: 'verified' as any,
        verifiedAt: new Date(),
      });
      leader.profile = leaderProfile;
      await this.userRepo.save(leader);
      console.log('   团长: 13800000001 / leader123');
      console.log('');
    }
  }
}
