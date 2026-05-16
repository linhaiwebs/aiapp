import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Team, TeamMember, TeamMemberRole, MemberStatus, User } from '../../entities';
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

  async create(dto: CreateTeamDto, userId?: string): Promise<Team> {
    const team = this.teamRepository.create(dto);
    const saved = await this.teamRepository.save(team);

    // 确定团长：优先 dto.leaderId（管理员替团长创建），否则 userId（团长自己创建）
    const leaderId = dto.leaderId || userId;

    if (leaderId) {
      const user = await this.userRepository.findOne({ where: { id: leaderId } });
      const member = this.memberRepository.create({
        teamId: saved.id,
        userId: leaderId,
        userName: user?.nickname || user?.phone || dto.leaderName || undefined,
        phone: user?.phone || undefined,
        role: TeamMemberRole.LEADER,
        status: MemberStatus.APPROVED,
      });
      await this.memberRepository.save(member);
    }

    return saved;
  }

  async findAll(page = 1, pageSize = 20, keyword?: string, userId?: string, userRole?: string) {
    const queryBuilder = this.teamRepository
      .createQueryBuilder('team')
      .leftJoinAndSelect('team.members', 'member');

    // 团队隔离（普通用户）：返回所属 + 待审批的团队。超级管理员看全部。
    if (userId && userRole !== 'super_admin') {
      const memberships = await this.memberRepository.find({
        where: [
          { userId, status: MemberStatus.APPROVED },
          { userId, status: MemberStatus.PENDING },
        ],
        select: ['teamId', 'status'],
      });
      const teamIds = [...new Set(memberships.map((m) => m.teamId))];
      if (teamIds.length === 0) {
        queryBuilder.andWhere('1 = 0');
      } else {
        queryBuilder.andWhere('team.id IN (:...teamIds)', { teamIds });
      }
    }

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

    // 非团长用户剔除 joinCode
    const masked = items.map((team) => this.maskJoinCode(team, userId, userRole));
    return { items: masked, total, page, pageSize };
  }

  async findOne(id: string, userId?: string, userRole?: string): Promise<Team> {
    const team = await this.teamRepository.findOne({
      where: { id },
      relations: ['members'],
    });
    if (!team) throw new NotFoundException('团队不存在');

    // 成员身份校验（超级管理员跳过，待审批成员也可查看）
    if (userId && userRole !== 'super_admin') {
      const isMember = team.members?.some(
        (m) => m.userId === userId && m.status !== MemberStatus.REJECTED,
      );
      if (!isMember) {
        throw new ForbiddenException('您不是该团队的成员');
      }
    }

    return this.maskJoinCode(team, userId, userRole);
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

  async getMembers(teamId: string, userId?: string, userRole?: string) {
    // 非成员不能查看成员列表（超级管理员跳过；已通过和待审批成员均可查看）
    if (userId && userRole !== 'super_admin') {
      const membership = await this.memberRepository.findOne({
        where: { teamId, userId },
      });
      if (!membership || membership.status === MemberStatus.REJECTED) {
        throw new ForbiddenException('您不是该团队的成员');
      }
    }
    return this.memberRepository.find({
      where: { teamId },
      order: { createdAt: 'ASC' },
    });
  }

  /** 通过口令加入团队（需团长审批） */
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
    if (existing) {
      if (existing.status === MemberStatus.PENDING) {
        throw new BadRequestException('已提交申请，等待审批中');
      }
      throw new BadRequestException('您已在该团队中');
    }

    const user = await this.userRepository.findOne({ where: { id: userId } });

    const member = this.memberRepository.create({
      teamId: team.id,
      userId,
      userName: user?.nickname || user?.phone || undefined,
      phone: user?.phone || undefined,
      role: TeamMemberRole.MEMBER,
      status: MemberStatus.PENDING,
    });
    return this.memberRepository.save(member);
  }

  /** 获取待审批成员列表（团长/超级管理员） */
  async getPendingMembers(teamId: string) {
    return this.memberRepository.find({
      where: { teamId, status: MemberStatus.PENDING },
      order: { createdAt: 'ASC' },
    });
  }

  /** 审批通过成员 */
  async approveMember(teamId: string, memberId: string, reviewerId: string) {
    const member = await this.memberRepository.findOne({
      where: { id: memberId, teamId },
    });
    if (!member) throw new NotFoundException('成员不存在');
    if (member.status !== MemberStatus.PENDING) {
      throw new BadRequestException('当前状态不可审批');
    }
    member.status = MemberStatus.APPROVED;
    return this.memberRepository.save(member);
  }

  /** 驳回成员申请 */
  async rejectMember(teamId: string, memberId: string, reviewerId: string, reason?: string) {
    const member = await this.memberRepository.findOne({
      where: { id: memberId, teamId },
    });
    if (!member) throw new NotFoundException('成员不存在');
    if (member.status !== MemberStatus.PENDING) {
      throw new BadRequestException('当前状态不可驳回');
    }
    member.status = MemberStatus.REJECTED;
    member.rejectReason = reason || null;
    return this.memberRepository.save(member);
  }

  /** 屏蔽非团长的 joinCode（超级管理员始终可见） */
  private maskJoinCode(team: Team, userId?: string, userRole?: string): any {
    if (!userId) return team;
    if (userRole === 'super_admin') return team;
    const isLeader = team.members?.some(
      (m) => m.userId === userId && m.role === TeamMemberRole.LEADER && m.status === MemberStatus.APPROVED,
    );
    if (!isLeader) {
      const { joinCode, ...rest } = team as any;
      return rest;
    }
    return team;
  }
}
