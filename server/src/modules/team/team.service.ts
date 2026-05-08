import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Team, TeamMember, TeamMemberRole, User } from '../../entities';
import { CreateTeamDto, AddTeamMemberDto, InviteMemberDto } from './dto';

@Injectable()
export class TeamService {
  constructor(
    @InjectRepository(Team)
    private teamRepository: Repository<Team>,
    @InjectRepository(TeamMember)
    private memberRepository: Repository<TeamMember>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
  ) {}

  async create(dto: CreateTeamDto): Promise<Team> {
    const team = this.teamRepository.create(dto);
    return this.teamRepository.save(team);
  }

  async findAll(page = 1, pageSize = 20, keyword?: string) {
    const queryBuilder = this.teamRepository
      .createQueryBuilder('team')
      .leftJoinAndSelect('team.members', 'member');

    if (keyword) {
      queryBuilder.andWhere(
        '(team.name LIKE :keyword OR team.leaderName LIKE :keyword)',
        { keyword: `%${keyword}%` },
      );
    }

    queryBuilder
      .orderBy('team.createdAt', 'DESC')
      .skip((page - 1) * pageSize)
      .take(pageSize);

    const [items, total] = await queryBuilder.getManyAndCount();
    return { items, total, page, pageSize };
  }

  async findOne(id: string): Promise<Team> {
    const team = await this.teamRepository.findOne({
      where: { id },
      relations: ['members'],
    });
    if (!team) throw new NotFoundException('团队不存在');
    return team;
  }

  async update(id: string, dto: CreateTeamDto): Promise<Team> {
    const team = await this.findOne(id);
    Object.assign(team, dto);
    return this.teamRepository.save(team);
  }

  async remove(id: string): Promise<void> {
    const team = await this.findOne(id);
    await this.teamRepository.remove(team);
  }

  async addMember(teamId: string, dto: AddTeamMemberDto): Promise<TeamMember> {
    await this.findOne(teamId);

    const existing = await this.memberRepository.findOne({
      where: { teamId, userId: dto.userId },
    });
    if (existing) throw new BadRequestException('该用户已在团队中');

    const member = this.memberRepository.create({
      teamId,
      userId: dto.userId,
      userName: dto.userName,
      phone: dto.phone,
      email: dto.email,
      role: dto.role === 'leader' ? TeamMemberRole.LEADER : TeamMemberRole.MEMBER,
    });
    return this.memberRepository.save(member);
  }

  async removeMember(teamId: string, memberId: string): Promise<void> {
    const member = await this.memberRepository.findOne({
      where: { id: memberId, teamId },
    });
    if (!member) throw new NotFoundException('成员不存在');
    await this.memberRepository.remove(member);
  }

  async inviteMember(teamId: string, dto: InviteMemberDto): Promise<TeamMember> {
    await this.findOne(teamId);

    const isEmail = dto.contact.includes('@');
    const member = this.memberRepository.create({
      teamId,
      userId: `invited_${Date.now()}`,
      userName: dto.userName || dto.contact,
      phone: isEmail ? undefined : dto.contact,
      email: isEmail ? dto.contact : undefined,
      role: TeamMemberRole.MEMBER,
    });
    return this.memberRepository.save(member);
  }

  async getMembers(teamId: string) {
    await this.findOne(teamId);
    return this.memberRepository.find({
      where: { teamId },
      order: { createdAt: 'ASC' },
    });
  }

  /** 通过口令加入团队 */
  async joinByCode(userId: string, joinCode: string): Promise<TeamMember> {
    if (!joinCode || joinCode.trim().length === 0) {
      throw new BadRequestException('请输入口令');
    }

    const team = await this.teamRepository.findOne({
      where: { joinCode: joinCode.trim() },
    });
    if (!team) throw new NotFoundException('口令无效，未找到对应团队');
    if (!team.isActive) throw new BadRequestException('该团队已停用');

    const existing = await this.memberRepository.findOne({
      where: { teamId: team.id, userId },
    });
    if (existing) throw new BadRequestException('您已在该团队中');

    const user = await this.userRepository.findOne({ where: { id: userId } });

    const member = this.memberRepository.create({
      teamId: team.id,
      userId,
      userName: user?.nickname || user?.phone || undefined,
      phone: user?.phone || undefined,
      role: TeamMemberRole.MEMBER,
    });
    return this.memberRepository.save(member);
  }
}
