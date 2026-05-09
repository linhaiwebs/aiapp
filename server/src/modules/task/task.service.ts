import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, FindOptionsWhere, Like, In } from 'typeorm';
import { Task, TaskClaim, TaskStatus, ClaimStatus, User, UserStatus, TeamMember, Project } from '../../entities';
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
  ) {}

  async create(dto: CreateTaskDto): Promise<Task> {
    const cleanDto = Object.fromEntries(
      Object.entries(dto).filter(([, v]) => v !== null && v !== undefined),
    );

    // Auto-inherit teamId from project when not explicitly set
    if (cleanDto.projectId && !cleanDto.teamId) {
      const project = await this.projectRepository.findOne({ where: { id: cleanDto.projectId } });
      if (project?.teamId) {
        cleanDto.teamId = project.teamId;
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
    try {
      const task = this.taskRepository.create(cleanDto);
      return await this.taskRepository.save(task);
    } catch (error) {
      console.error('[Task Create] Error:', error);
      throw error;
    }
  }

  async findAll(filter: TaskFilterDto) {
    const {
      type, status, difficulty, minPrice, maxPrice,
      region, language, categoryId, projectId, keyword,
      page = 1, pageSize = 20,
    } = filter;

    const queryBuilder = this.taskRepository
      .createQueryBuilder('task')
      .leftJoinAndSelect('task.category', 'category')
      .leftJoinAndSelect('task.project', 'project');

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
    return this.taskRepository.save(task);
  }

  async remove(id: string): Promise<void> {
    const task = await this.findOne(id);
    await this.taskRepository.remove(task);
  }

  async batchRemove(ids: string[]): Promise<void> {
    if (!ids?.length) throw new BadRequestException('请提供要删除的ID列表');
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
  async claim(userId: string, taskId: string): Promise<TaskClaim> {
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

    // Check team membership if task is team-scoped
    if (task.teamId) {
      const membership = await this.teamMemberRepository.findOne({
        where: { teamId: task.teamId, userId },
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

    const claim = this.claimRepository.create({
      userId,
      taskId,
      status: ClaimStatus.PENDING_APPROVAL,
      claimedAt: new Date(),
      deadline: task.deadline,
    });

    return this.claimRepository.save(claim);
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
    const where: FindOptionsWhere<TaskClaim> = { userId };
    if (status) where.status = status;

    return this.claimRepository.find({
      where,
      relations: ['task'],
      order: { createdAt: 'DESC' },
    });
  }

  async search(keyword: string, page = 1, pageSize = 20) {
    return this.taskRepository.findAndCount({
      where: [
        { title: Like(`%${keyword}%`), status: TaskStatus.PUBLISHED },
        { id: keyword, status: TaskStatus.PUBLISHED },
      ],
      skip: (page - 1) * pageSize,
      take: pageSize,
      order: { createdAt: 'DESC' },
    });
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
