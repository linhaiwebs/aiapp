import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { getRepositoryToken } from '@nestjs/typeorm';
import { User, UserProfile, UserRole, UserStatus } from './entities';
import * as bcrypt from 'bcryptjs';

/**
 * Seed script: creates default admin user
 * Usage: npx ts-node src/seed.ts
 */
async function seed() {
  const app = await NestFactory.createApplicationContext(AppModule);

  const userRepo = app.get(getRepositoryToken(User));
  const profileRepo = app.get(getRepositoryToken(UserProfile));

  // Check if admin already exists
  const existingAdmin = await userRepo.findOne({
    where: { role: UserRole.SUPER_ADMIN },
  });

  if (existingAdmin) {
    console.log('✅ 超级管理员已存在:', existingAdmin.phone);
    console.log('   角色:', existingAdmin.role);
    await app.close();
    return;
  }

  // Create super admin
  const adminPhone = '13800000000';
  const adminPassword = 'admin123';

  const hashedPassword = await bcrypt.hash(adminPassword, 10);

  const admin = userRepo.create({
    phone: adminPhone,
    password: hashedPassword,
    nickname: '超级管理员',
    role: UserRole.SUPER_ADMIN,
    status: UserStatus.ACTIVE,
    qualityScore: 100,
    isRealNameVerified: true,
  });

  const profile = profileRepo.create({
    user: admin,
    userId: admin.id,
    realName: '系统管理员',
    verificationStatus: 'verified' as any,
    verifiedAt: new Date(),
  });

  admin.profile = profile;
  await userRepo.save(admin);

  console.log('🎉 超级管理员创建成功！');
  console.log('   手机号: 13800000000');
  console.log('   密码: admin123');
  console.log('   角色: super_admin');

  // Also create a leader
  const leaderPhone = '13800000001';
  const existingLeader = await userRepo.findOne({ where: { phone: leaderPhone } });
  if (!existingLeader) {
    const leader = userRepo.create({
      phone: leaderPhone,
      password: await bcrypt.hash('leader123', 10),
      nickname: '团长',
      role: UserRole.LEADER,
      status: UserStatus.ACTIVE,
      qualityScore: 100,
      isRealNameVerified: true,
      companyName: '示例科技有限公司',
    });
    const leaderProfile = profileRepo.create({
      user: leader,
      userId: leader.id,
      realName: '团长',
      verificationStatus: 'verified' as any,
      verifiedAt: new Date(),
    });
    leader.profile = leaderProfile;
    await userRepo.save(leader);
    console.log('\n🎉 团长创建成功！');
    console.log('   手机号: 13800000001');
    console.log('   密码: leader123');
    console.log('   角色: leader');
  }

  // Create a demo member
  const memberPhone = '13800138000';
  const existingMember = await userRepo.findOne({ where: { phone: memberPhone } });
  if (!existingMember) {
    const member = userRepo.create({
      phone: memberPhone,
      password: await bcrypt.hash('123456', 10),
      nickname: '会员小明',
      role: UserRole.MEMBER,
      status: UserStatus.ACTIVE,
      qualityScore: 95,
      isRealNameVerified: true,
    });
    const memberProfile = profileRepo.create({
      user: member,
      userId: member.id,
      realName: '张三',
      verificationStatus: 'verified' as any,
      verifiedAt: new Date(),
    });
    member.profile = memberProfile;
    await userRepo.save(member);
    console.log('\n🎉 会员创建成功！');
    console.log('   手机号: 13800138000');
    console.log('   密码: 123456');
    console.log('   角色: member');
  }

  await app.close();
}

seed().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
