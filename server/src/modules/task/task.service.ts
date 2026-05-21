import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, FindOptionsWhere, Like, In } from 'typeorm';
import { Task, TaskClaim, TaskStatus, TaskReviewStatus, ClaimStatus, User, UserStatus, TeamMember, MemberStatus, TeamMemberRole, Project, TextCollection, TextStatus, TaskType } from '../../entities';
import { CreateTaskDto, UpdateTaskDto, TaskFilterDto } from './dto';

@Injectable()
export class TaskService {
  constructor(
    @InjectRepository(Task)
    private taskRepository: Repository<Task>,
    @InjectRepository(TaskClaim)
    private claimRepository: Repository<TaskClaim>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(TeamMember)
    private teamMemberRepository: Repository<TeamMember>,
    @InjectRepository(Project)
    private projectRepository: Repository<Project>,
    @InjectRepository(TextCollection)
    private textCollectionRepository: Repository<TextCollection>,
  ) {}

  async create(dto: CreateTaskDto, userId?: string, userRole?: string): Promise<Task> {
    const cleanDto = Object.fromEntries(
      Object.entries(dto).filter(([, v]) => v !== null && v !== undefined),
    );

    // Auto-inherit teamId and type from project when not explicitly set
    if (cleanDto.projectId) {
      const project = await this.projectRepository.findOne({ where: { id: cleanDto.projectId } });
      if (project) {
        if (!cleanDto.teamId && project.teamId) {
          cleanDto.teamId = project.teamId;
        }
        if (!cleanDto.type && project.type) {
          cleanDto.type = project.type;
        }
      }
    }

    // Remove audio-specific fields for non-audio types to avoid enum validation issues
    if (cleanDto.type !== 'audio') {
      delete cleanDto.audioFormat;
      delete cleanDto.audioChannel;
      delete cleanDto.sampleRate;
      delete cleanDto.noiseLimit;
      delete cleanDto.maxSpeechLength;
      delete cleanDto.silencePadding;
      delete cleanDto.assistRecognition;
      delete cleanDto.silenceDetection;
      delete cleanDto.voiceprintDetection;
      delete cleanDto.gainDetection;
      delete cleanDto.signalDetection;
    }

    // 团长创建的任务默认需要后台审核，超级管理员创建的直接通过
    if (userRole && userRole !== 'super_admin') {
      cleanDto.reviewStatus = TaskReviewStatus.PENDING_REVIEW;
      cleanDto.status = TaskStatus.DRAFT;
    }

    try {
      const task = this.taskRepository.create(cleanDto);
      const saved = await this.taskRepository.save(task);

      // Auto-create text collections from instructions (每行一条)
      await this.syncTextCollections(saved);

      return saved;
    } catch (error) {
      console.error('[Task Create] Error:', error);
      throw error;
    }
  }

  async findAll(filter: TaskFilterDto, userId?: string, userRole?: string) {
    const {
      type, status, difficulty, minPrice, maxPrice,
      region, language, categoryId, projectId, keyword,
      page = 1, pageSize = 20,
    } = filter;

    const queryBuilder = this.taskRepository
      .createQueryBuilder('task')
      .leftJoinAndSelect('task.category', 'category')
      .leftJoinAndSelect('task.project', 'project');

    // 团队隔离：普通用户只能看到自己所属团队的任务，超管看全部
    if (userId && userRole !== 'super_admin') {
      const memberships = await this.teamMemberRepository.find({
        where: { userId, status: MemberStatus.APPROVED },
        select: ['teamId'],
      });
      const teamIds = memberships.map((m) => m.teamId);
      if (teamIds.length === 0) {
        queryBuilder.andWhere('1 = 0');
      } else {
        queryBuilder.andWhere('task.teamId IN (:...teamIds)', { teamIds });
      }
    }

    if (type) queryBuilder.andWhere('task.type = :type', { type });
    if (status) {
      const statuses = status.split(',').map((s) => s.trim()).filter(Boolean);
      if (statuses.length === 1) {
        queryBuilder.andWhere('task.status = :status', { status: statuses[0] });
      } else if (statuses.length > 1) {
        queryBuilder.andWhere('task.status IN (:...statuses)', { statuses });
      }
    }
    if (difficulty) queryBuilder.andWhere('task.difficulty = :difficulty', { difficulty });
    if (minPrice) queryBuilder.andWhere('task.unitPrice >= :minPrice', { minPrice });
    if (maxPrice) queryBuilder.andWhere('task.unitPrice <= :maxPrice', { maxPrice });
    if (region) queryBuilder.andWhere('task.region = :region', { region });
    if (language) queryBuilder.andWhere('task.language = :language', { language });
    if (categoryId) queryBuilder.andWhere('task.categoryId = :categoryId', { categoryId });
    if (projectId) queryBuilder.andWhere('task.projectId = :projectId', { projectId });
    if (filter.teamId) queryBuilder.andWhere('task.teamId = :teamId', { teamId: filter.teamId });
    if (keyword) {
      queryBuilder.andWhere(
        '(task.title LIKE :keyword OR task.description LIKE :keyword)',
        { keyword: `%${keyword}%` },
      );
    }

    // 只显示已审核通过的任务
    queryBuilder.andWhere('task.reviewStatus = :reviewStatus', { reviewStatus: TaskReviewStatus.APPROVED });

    queryBuilder
      .orderBy('task.sortOrder', 'ASC')
      .addOrderBy('task.createdAt', 'DESC')
      .skip((page - 1) * pageSize)
      .take(pageSize);

    const [items, total] = await queryBuilder.getManyAndCount();
    return { items, total, page, pageSize };
  }

  async findOne(id: string): Promise<Task> {
    const task = await this.taskRepository.findOne({
      where: { id },
      relations: ['category', 'project', 'team', 'requirements', 'samples'],
    });
    if (!task) throw new NotFoundException('任务不存在');
    return task;
  }

  async update(id: string, dto: UpdateTaskDto): Promise<Task> {
    const task = await this.findOne(id);
    const cleanDto = Object.fromEntries(
      Object.entries(dto).filter(([, v]) => v !== null && v !== undefined),
    );
    Object.assign(task, cleanDto);
    const saved = await this.taskRepository.save(task);

    // Sync text collections from instructions（仅当 instructions 字段有更新时）
    if (cleanDto.instructions !== undefined) {
      await this.syncTextCollections(saved);
    }

    return saved;
  }

  /** 根据任务 instructions 自动创建/刷新 text_collections */
  private async syncTextCollections(task: Task): Promise<void> {
    const instructions = task.instructions;
    if (!instructions || !instructions.trim()) return;

    const lines = instructions.split('\n').map(l => l.trim()).filter(l => l);
    if (lines.length === 0) return;

    // Check if texts already exist for this task (avoid duplicates)
    const existingCount = await this.textCollectionRepository.count({
      where: { taskId: task.id },
    });
    if (existingCount > 0) return;

    // Use insert (true bulk) instead of save (row-by-row check) for performance
    const BATCH_SIZE = 1000;
    for (let i = 0; i < lines.length; i += BATCH_SIZE) {
      const batch = lines.slice(i, i + BATCH_SIZE).map((content, j) => ({
        taskId: task.id,
        content,
        format: 'plain',
        sortOrder: i + j,
        status: TextStatus.PENDING,
      }));
      await this.textCollectionRepository.insert(batch as any);
    }
    console.log(`[syncTextCollections] Created ${lines.length} texts for task ${task.id}`);
  }

  async remove(id: string): Promise<void> {
    // 级联清理：文本采集 → 认领记录 → 任务
    await this.textCollectionRepository.delete({ taskId: id });
    await this.claimRepository.delete({ taskId: id });
    await this.taskRepository.delete(id);
  }

  async batchRemove(ids: string[]): Promise<void> {
    if (!ids?.length) throw new BadRequestException('请提供要删除的ID列表');
    // 级联清理
    for (const taskId of ids) {
      await this.textCollectionRepository.delete({ taskId } as any);
      await this.claimRepository.delete({ taskId } as any);
    }
    await this.taskRepository.delete(ids);
  }

  async batchUpdateStatus(ids: string[], status: TaskStatus): Promise<void> {
    if (!ids?.length) throw new BadRequestException('请提供要操作的ID列表');
    if (!Object.values(TaskStatus).includes(status)) {
      throw new BadRequestException('无效的任务状态');
    }
    await this.taskRepository.update(ids, { status });
  }

  /** 采集员申请任务（需审核员审批） */
  async claim(userId: string, taskId: string, userRole?: string): Promise<TaskClaim> {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('用户不存在');
    if (user.status === UserStatus.BLACKLISTED) {
      throw new ForbiddenException('账号已被封禁，无法申请任务');
    }

    const task = await this.taskRepository.findOne({ where: { id: taskId } });
    if (!task) throw new NotFoundException('任务不存在');
    if (task.status !== TaskStatus.PUBLISHED && task.status !== TaskStatus.IN_PROGRESS) {
      throw new BadRequestException('任务当前不可申请');
    }
    if (task.deadline && new Date(task.deadline) < new Date()) {
      throw new BadRequestException('任务已过截止时间');
    }
    // Compare as numbers — PostgreSQL decimal columns return strings
    const minScore = Number(task.minQualityScore) || 0;
    const userScore = Number(user.qualityScore) || 0;
    if (minScore > userScore) {
      throw new ForbiddenException('质量分不足，无法申请此任务');
    }

    // Check team membership if task is team-scoped (super admin bypasses)
    if (task.teamId && userRole !== 'super_admin') {
      const membership = await this.teamMemberRepository.findOne({
        where: { teamId: task.teamId, userId, status: MemberStatus.APPROVED },
      });
      if (!membership) {
        throw new ForbiddenException('仅团队成员可领取此任务');
      }
    }

    const remaining = Number(task.totalQuantity) - Number(task.claimedQuantity);
    if (remaining <= 0) {
      throw new BadRequestException('任务已被领完');
    }

    // Check if already has a pending or active claim
    const existingClaim = await this.claimRepository.findOne({
      where: [
        { userId, taskId, status: ClaimStatus.PENDING_APPROVAL },
        { userId, taskId, status: ClaimStatus.CLAIMED },
        { userId, taskId, status: ClaimStatus.IN_PROGRESS },
      ],
    });
    if (existingClaim) {
      throw new BadRequestException('您已申请或领取了此任务');
    }

    // 已加入团队的会员领取本团队任务免审批，直接通过
    let claimStatus = ClaimStatus.PENDING_APPROVAL;
    if (task.teamId) {
      const isMember = await this.teamMemberRepository.findOne({
        where: { teamId: task.teamId, userId, status: MemberStatus.APPROVED },
      });
      if (isMember) {
        claimStatus = ClaimStatus.CLAIMED;
      }
    }

    const claim = this.claimRepository.create({
      userId,
      taskId,
      status: claimStatus,
      claimedAt: new Date(),
      deadline: task.deadline,
    });

    const saved = await this.claimRepository.save(claim);

    // 团长自领直接更新 claimedQuantity
    if (claimStatus === ClaimStatus.CLAIMED) {
      task.claimedQuantity = Number(task.claimedQuantity) + 1;
      if (task.status === TaskStatus.PUBLISHED) {
        task.status = TaskStatus.IN_PROGRESS;
      }
      await this.taskRepository.save(task);
    }

    // 自动分配文本：只要该任务有 text_collections，领取时即分配
    if (claimStatus === ClaimStatus.CLAIMED) {
      const hasTexts = await this.textCollectionRepository.count({
        where: { taskId: task.id },
      });
      if (hasTexts > 0) {
        await this.autoAssignTextsForClaim(task, saved);
      }
    }

    return saved;
  }

  /** 文本任务 — 按任务分配设置从 PENDING 池中取前 N 条分配给新领取者 */
  private async autoAssignTextsForClaim(task: Task, claim: TaskClaim): Promise<void> {
    // 计算每人分配条数
    let perUserCount = 0;
    if (task.textAssignMode === 'per_user' && (task.textPerUserCount ?? 0) > 0) {
      perUserCount = Number(task.textPerUserCount);
    } else if (task.textAssignMode === 'even' && (task.textAssignCount ?? 0) > 0) {
      const totalPending = await this.textCollectionRepository.count({
        where: { taskId: task.id, status: TextStatus.PENDING },
      });
      perUserCount = Math.ceil(totalPending / Number(task.textAssignCount));
    } else {
      // auto 模式：为当前用户复制全部文本（每人全量）
      if ((task.textAssignMode || 'auto') === 'auto') {
        const allTexts = await this.textCollectionRepository.find({
          where: { taskId: task.id, status: In([TextStatus.PENDING, TextStatus.ASSIGNED]) },
          order: { sortOrder: 'ASC' },
        });
        if (allTexts.length === 0) return;

        const copies = allTexts.map((text) =>
          this.textCollectionRepository.create({
            taskId: text.taskId,
            content: text.content,
            format: text.format,
            templateId: text.templateId,
            sortOrder: text.sortOrder,
            assignedUserId: claim.userId,
            assignedAt: new Date(),
            status: TextStatus.ASSIGNED,
          }),
        );
        for (let i = 0; i < copies.length; i += 500) {
          await this.textCollectionRepository.save(copies.slice(i, i + 500));
        }
        return;
      }

      // 其他模式：按 claimedQuantity 动态均分
      const totalPending = await this.textCollectionRepository.count({
        where: { taskId: task.id, status: TextStatus.PENDING },
      });
      if (totalPending === 0) return;
      const totalAssignees = Number(task.claimedQuantity) || 1;
      const totalTexts = totalPending + (await this.textCollectionRepository.count({
        where: { taskId: task.id, status: TextStatus.ASSIGNED },
      }));
      perUserCount = Math.ceil(totalTexts / totalAssignees);
    }

    if (perUserCount <= 0) return;

    const pendingTexts = await this.textCollectionRepository.find({
      where: { taskId: task.id, status: TextStatus.PENDING },
      order: { sortOrder: 'ASC' },
      take: perUserCount,
    });

    if (pendingTexts.length === 0) return;

    for (const text of pendingTexts) {
      text.assignedUserId = claim.userId;
      text.assignedAt = new Date();
      text.status = TextStatus.ASSIGNED;
    }
    await this.textCollectionRepository.save(pendingTexts);
  }

  /** 审核员审批任务申请 */
  async approveClaim(claimId: string, reviewerId: string): Promise<TaskClaim> {
    const claim = await this.claimRepository.findOne({
      where: { id: claimId },
      relations: ['task'],
    });
    if (!claim) throw new NotFoundException('申请记录不存在');
    if (claim.status !== ClaimStatus.PENDING_APPROVAL) {
      throw new BadRequestException('当前状态不可审批');
    }

    const task = claim.task;
    const remaining = Number(task.totalQuantity) - Number(task.claimedQuantity);
    if (remaining <= 0) {
      throw new BadRequestException('任务已被领完，无法审批');
    }

    claim.status = ClaimStatus.CLAIMED;
    claim.claimedAt = new Date();
    await this.claimRepository.save(claim);

    task.claimedQuantity = Number(task.claimedQuantity) + 1;
    if (task.status === TaskStatus.PUBLISHED) {
      task.status = TaskStatus.IN_PROGRESS;
    }
    await this.taskRepository.save(task);

    return claim;
  }

  /** 管理员删除认领记录 */
  async removeClaim(claimId: string): Promise<void> {
    const claim = await this.claimRepository.findOne({
      where: { id: claimId },
      relations: ['task'],
    });
    if (!claim) throw new NotFoundException('认领记录不存在');

    // 如果任务有 claimedQuantity 且状态为已领取/采集中，需要回退
    if (
      claim.task &&
      (claim.status === ClaimStatus.CLAIMED || claim.status === ClaimStatus.IN_PROGRESS)
    ) {
      await this.taskRepository.decrement(
        { id: claim.taskId },
        'claimedQuantity',
        1,
      );
    }

    // 清除该认领关联的文本分配
    if ((claim.task?.type as string) === 'text') {
      await this.textCollectionRepository.update(
        { taskId: claim.taskId, assignedUserId: claim.userId, status: TextStatus.ASSIGNED },
        { assignedUserId: null as any, assignedAt: null as any, status: TextStatus.PENDING },
      );
    }

    await this.claimRepository.remove(claim);
  }

  /** 审核员拒绝任务申请 */
  async rejectClaim(claimId: string, reviewerId: string, reason?: string): Promise<TaskClaim> {
    const claim = await this.claimRepository.findOne({
      where: { id: claimId },
    });
    if (!claim) throw new NotFoundException('申请记录不存在');
    if (claim.status !== ClaimStatus.PENDING_APPROVAL) {
      throw new BadRequestException('当前状态不可拒绝');
    }

    claim.status = ClaimStatus.REJECTED;
    claim.completedAt = new Date();
    await this.claimRepository.save(claim);

    return claim;
  }

  /** 获取待审批的任务申请列表 */
  async getPendingClaims(taskId?: string, page = 1, pageSize = 20) {
    const queryBuilder = this.claimRepository
      .createQueryBuilder('claim')
      .leftJoinAndSelect('claim.task', 'task')
      .leftJoinAndSelect('claim.user', 'user')
      .where('claim.status = :status', { status: ClaimStatus.PENDING_APPROVAL });

    if (taskId) queryBuilder.andWhere('claim.taskId = :taskId', { taskId });

    queryBuilder
      .orderBy('claim.createdAt', 'ASC')
      .skip((page - 1) * pageSize)
      .take(pageSize);

    const [items, total] = await queryBuilder.getManyAndCount();
    return { items, total, page, pageSize };
  }

  async abandon(userId: string, claimId: string): Promise<void> {
    const claim = await this.claimRepository.findOne({
      where: { id: claimId, userId },
    });
    if (!claim) throw new NotFoundException('领取记录不存在');
    if (claim.status !== ClaimStatus.CLAIMED && claim.status !== ClaimStatus.IN_PROGRESS) {
      throw new BadRequestException('当前状态不可放弃');
    }

    claim.status = ClaimStatus.ABANDONED;
    claim.completedAt = new Date();
    await this.claimRepository.save(claim);

    await this.taskRepository.decrement(
      { id: claim.taskId },
      'claimedQuantity',
      1,
    );
  }

  async getUserClaims(userId: string, status?: ClaimStatus) {
    // 先清理孤儿认领（关联任务已被删除的）
    await this.cleanOrphanClaims();

    const where: FindOptionsWhere<TaskClaim> = { userId };
    if (status) where.status = status;

    return this.claimRepository.find({
      where,
      relations: ['task'],
      order: { createdAt: 'DESC' },
    });
  }

  /** 清理关联任务已被删除的孤儿认领记录 */
  async cleanOrphanClaims(): Promise<number> {
    const orphanClaims = await this.claimRepository
      .createQueryBuilder('claim')
      .leftJoin('claim.task', 'task')
      .where('task.id IS NULL')
      .getMany();

    if (orphanClaims.length > 0) {
      await this.claimRepository.remove(orphanClaims);
    }
    return orphanClaims.length;
  }

  async search(keyword: string, page = 1, pageSize = 20, userId?: string, userRole?: string) {
    const queryBuilder = this.taskRepository
      .createQueryBuilder('task')
      .where(
        '(task.title LIKE :keyword OR task.id = :id) AND task.status = :status AND task.reviewStatus = :reviewStatus',
        { keyword: `%${keyword}%`, id: keyword, status: TaskStatus.PUBLISHED, reviewStatus: TaskReviewStatus.APPROVED },
      );

    if (userId && userRole !== 'super_admin') {
      const memberships = await this.teamMemberRepository.find({
        where: { userId, status: MemberStatus.APPROVED },
        select: ['teamId'],
      });
      const teamIds = memberships.map((m) => m.teamId);
      if (teamIds.length === 0) {
        queryBuilder.andWhere('1 = 0');
      } else {
        queryBuilder.andWhere('task.teamId IN (:...teamIds)', { teamIds });
      }
    }

    queryBuilder
      .skip((page - 1) * pageSize)
      .take(pageSize)
      .orderBy('task.createdAt', 'DESC');

    return queryBuilder.getManyAndCount();
  }

  /** 已批准的认领记录（广场 Feed） */
  async getApprovedClaims(page = 1, pageSize = 20, teamId?: string) {
    const queryBuilder = this.claimRepository
      .createQueryBuilder('claim')
      .leftJoinAndSelect('claim.task', 'task')
      .leftJoinAndSelect('claim.user', 'user')
      .leftJoinAndSelect('task.team', 'team')
      .where('claim.status IN (:...statuses)', {
        statuses: [ClaimStatus.CLAIMED, ClaimStatus.IN_PROGRESS, ClaimStatus.SUBMITTED, ClaimStatus.COMPLETED],
      });

    if (teamId) {
      queryBuilder.andWhere('task.teamId = :teamId', { teamId });
    }

    queryBuilder
      .orderBy('claim.claimedAt', 'DESC')
      .skip((page - 1) * pageSize)
      .take(pageSize);

    const [items, total] = await queryBuilder.getManyAndCount();
    return { items, total, page, pageSize };
  }

  /** 管理后台全量认领查询 */
  async getAllClaims(
    page = 1, pageSize = 20,
    filters?: { status?: string; teamId?: string; userId?: string; taskId?: string },
  ) {
    await this.cleanOrphanClaims();

    const queryBuilder = this.claimRepository
      .createQueryBuilder('claim')
      .leftJoinAndSelect('claim.task', 'task')
      .leftJoinAndSelect('claim.user', 'user')
      .leftJoinAndSelect('task.team', 'team');

    if (filters?.status) {
      queryBuilder.andWhere('claim.status = :status', { status: filters.status });
    }
    if (filters?.teamId) {
      queryBuilder.andWhere('task.teamId = :teamId', { teamId: filters.teamId });
    }
    if (filters?.userId) {
      queryBuilder.andWhere('claim.userId = :userId', { userId: filters.userId });
    }
    if (filters?.taskId) {
      queryBuilder.andWhere('claim.taskId = :taskId', { taskId: filters.taskId });
    }

    queryBuilder
      .orderBy('claim.createdAt', 'DESC')
      .skip((page - 1) * pageSize)
      .take(pageSize);

    const [items, total] = await queryBuilder.getManyAndCount();
    return { items, total, page, pageSize };
  }

  /** 获取待审核的任务（团长创建，后台管理员审核） */
  async findPendingReviewTasks(page = 1, pageSize = 20, teamId?: string) {
    const queryBuilder = this.taskRepository
      .createQueryBuilder('task')
      .leftJoinAndSelect('task.team', 'team')
      .leftJoinAndSelect('task.project', 'project')
      .where('task.reviewStatus = :reviewStatus', { reviewStatus: TaskReviewStatus.PENDING_REVIEW });

    if (teamId) {
      queryBuilder.andWhere('task.teamId = :teamId', { teamId });
    }

    queryBuilder
      .orderBy('task.createdAt', 'DESC')
      .skip((page - 1) * pageSize)
      .take(pageSize);

    const [items, total] = await queryBuilder.getManyAndCount();
    return { items, total, page, pageSize };
  }

  /** 管理员审核任务（通过/驳回） */
  async reviewTask(
    id: string,
    reviewerId: string,
    action: 'approve' | 'reject',
    opts?: { projectId?: string; reason?: string },
  ): Promise<Task> {
    const task = await this.taskRepository.findOne({ where: { id } });
    if (!task) throw new NotFoundException('任务不存在');
    if (task.reviewStatus !== TaskReviewStatus.PENDING_REVIEW) {
      throw new BadRequestException('当前状态不可审核');
    }

    if (action === 'approve') {
      task.reviewStatus = TaskReviewStatus.APPROVED;
      task.status = TaskStatus.PUBLISHED;
      if (opts?.projectId) {
        task.projectId = opts.projectId;
      }
    } else {
      task.reviewStatus = TaskReviewStatus.REJECTED;
    }

    return this.taskRepository.save(task);
  }

  /** 清除所有任务数据（包括claims和submissions） */
  async clearAllTaskData(): Promise<{ tasksDeleted: number; claimsDeleted: number }> {
    const claimsCount = await this.claimRepository.count();
    await this.claimRepository.delete({});
    const tasksCount = await this.taskRepository.count();
    await this.taskRepository.delete({});
    return { tasksDeleted: tasksCount, claimsDeleted: claimsCount };
  }
}
