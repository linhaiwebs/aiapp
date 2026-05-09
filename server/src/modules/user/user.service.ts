import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcryptjs';
import { User, UserStatus, UserRole, UserProfile } from '../../entities';

@Injectable()
export class UserService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(UserProfile)
    private profileRepository: Repository<UserProfile>,
  ) {}

  async findAll(params: {
    page?: number;
    pageSize?: number;
    role?: string;
    status?: string;
    keyword?: string;
  }) {
    const { page = 1, pageSize = 20, role, status, keyword } = params;

    const queryBuilder = this.userRepository
      .createQueryBuilder('user')
      .leftJoinAndSelect('user.profile', 'profile');

    if (role) queryBuilder.andWhere('user.role = :role', { role });
    if (status) queryBuilder.andWhere('user.status = :status', { status });
    if (keyword) {
      queryBuilder.andWhere(
        '(user.phone LIKE :kw OR user.nickname LIKE :kw OR user.companyName LIKE :kw)',
        { kw: `%${keyword}%` },
      );
    }

    queryBuilder
      .orderBy('user.createdAt', 'DESC')
      .skip((page - 1) * pageSize)
      .take(pageSize);

    const [items, total] = await queryBuilder.getManyAndCount();
    return { items, total, page, pageSize };
  }

  async findOne(id: string): Promise<User> {
    const user = await this.userRepository.findOne({
      where: { id },
      relations: ['profile'],
    });
    if (!user) throw new NotFoundException('用户不存在');
    return user;
  }

  async create(dto: { phone: string; password?: string; nickname?: string; role?: string }): Promise<User> {
    const existing = await this.userRepository.findOne({
      where: { phone: dto.phone },
    });
    if (existing) throw new ConflictException('手机号已注册');

    const hashedPassword = await bcrypt.hash(dto.password || '123456', 10);
    const user = this.userRepository.create({
      phone: dto.phone,
      password: hashedPassword,
      nickname: dto.nickname || `用户${dto.phone.slice(-4)}`,
      role: (dto.role as UserRole) || UserRole.MEMBER,
    });

    const profile = this.profileRepository.create({
      user,
      userId: user.id,
    });
    user.profile = profile;
    return this.userRepository.save(user);
  }

  async invite(dto: { phone: string; role?: string; nickname?: string }): Promise<User> {
    return this.create({
      phone: dto.phone,
      nickname: dto.nickname,
      role: dto.role,
    });
  }

  async update(id: string, dto: Partial<User>): Promise<User> {
    const user = await this.findOne(id);
    if (dto.nickname !== undefined) user.nickname = dto.nickname;
    if (dto.role !== undefined) user.role = dto.role;
    if (dto.qualityScore !== undefined) user.qualityScore = dto.qualityScore;
    if (dto.balance !== undefined) user.balance = dto.balance;
    if (dto.companyName !== undefined) user.companyName = dto.companyName;
    return this.userRepository.save(user);
  }

  async updateStatus(id: string, status: string): Promise<User> {
    const user = await this.findOne(id);
    if (!Object.values(UserStatus).includes(status as UserStatus)) {
      throw new BadRequestException('无效的状态');
    }
    user.status = status as UserStatus;
    return this.userRepository.save(user);
  }

  async countByRole(): Promise<Record<string, number>> {
    const counts = await this.userRepository
      .createQueryBuilder('user')
      .select('user.role', 'role')
      .addSelect('COUNT(*)', 'count')
      .groupBy('user.role')
      .getRawMany();
    const result: Record<string, number> = {};
    for (const c of counts) {
      result[c.role] = parseInt(c.count);
    }
    return result;
  }

  async count(): Promise<number> {
    return this.userRepository.count();
  }
}
