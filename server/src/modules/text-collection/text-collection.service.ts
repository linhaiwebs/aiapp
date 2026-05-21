import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import {
  TextCollection,
  TextStatus,
  TextFormat,
  TextTemplate,
  Task,
  TaskClaim,
  ClaimStatus,
  User,
} from '../../entities';
import { UploadTextDto, BatchUploadTextDto, AssignTextDto, TextFilterDto } from './dto';

@Injectable()
export class TextCollectionService {
  constructor(
    @InjectRepository(TextCollection)
    private textRepository: Repository<TextCollection>,
    @InjectRepository(TextTemplate)
    private templateRepository: Repository<TextTemplate>,
    @InjectRepository(Task)
    private taskRepository: Repository<Task>,
    @InjectRepository(TaskClaim)
    private claimRepository: Repository<TaskClaim>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
  ) {}

  async upload(dto: UploadTextDto): Promise<TextCollection> {
    const task = await this.taskRepository.findOne({ where: { id: dto.taskId } });
    if (!task) throw new NotFoundException('任务不存在');

    const text = this.textRepository.create({
      taskId: dto.taskId,
      content: dto.content,
      format: dto.format || TextFormat.PLAIN,
      sortOrder: dto.sortOrder || 0,
      status: TextStatus.PENDING,
    });
    return this.textRepository.save(text);
  }

  async batchUpload(dto: BatchUploadTextDto): Promise<{ count: number }> {
    const task = await this.taskRepository.findOne({ where: { id: dto.taskId } });
    if (!task) throw new NotFoundException('任务不存在');

    const texts = (dto.texts || []).map((content, index) =>
      this.textRepository.create({
        taskId: dto.taskId,
        content,
        format: dto.format || TextFormat.PLAIN,
        sortOrder: index,
        status: TextStatus.PENDING,
      }),
    );

    if (texts.length === 0) throw new BadRequestException('文本列表不能为空');

    // Use insert (bulk) instead of save (row-by-row) for performance
    for (let i = 0; i < texts.length; i += 1000) {
      await this.textRepository.insert(texts.slice(i, i + 1000));
    }
    return { count: texts.length };
  }

  async uploadFromTemplate(taskId: string, fileContent: string, format: string, originalName: string): Promise<{ count: number }> {
    const task = await this.taskRepository.findOne({ where: { id: taskId } });
    if (!task) throw new NotFoundException('任务不存在');

    // Create template record
    const template = this.templateRepository.create({
      taskId,
      name: originalName || '上传模板',
      originalName,
      format,
      lineCount: 0,
      isParsed: true,
    });

    // Parse text content - split by newlines
    let lines: string[];
    if (format === 'sml') {
      // SML format - split by SML markers
      lines = fileContent.split(/\n+/).filter(l => l.trim());
    } else {
      // Plain text - split by newlines
      lines = fileContent.split(/\n/).filter(l => l.trim());
    }

    template.lineCount = lines.length;
    await this.templateRepository.save(template);

    // Create text collection entries
    const texts = lines.map((content, index) =>
      this.textRepository.create({
        taskId,
        content: content.trim(),
        format: format === 'sml' ? TextFormat.SML : TextFormat.PLAIN,
        templateId: template.id,
        sortOrder: index,
        status: TextStatus.PENDING,
      }),
    );

    // Use insert (bulk) instead of save (row-by-row)
    for (let i = 0; i < texts.length; i += 1000) {
      await this.textRepository.insert(texts.slice(i, i + 1000));
    }
    return { count: texts.length };
  }

  async findAll(filter: TextFilterDto) {
    const { taskId, status, assignedUserId, page = 1, pageSize = 20 } = filter;

    const queryBuilder = this.textRepository
      .createQueryBuilder('text');

    if (taskId) queryBuilder.andWhere('text.taskId = :taskId', { taskId });
    if (status) queryBuilder.andWhere('text.status = :status', { status });
    if (assignedUserId) queryBuilder.andWhere('text.assignedUserId = :assignedUserId', { assignedUserId });

    queryBuilder
      .orderBy('text.sortOrder', 'ASC')
      .addOrderBy('text.createdAt', 'ASC')
      .skip((page - 1) * pageSize)
      .take(pageSize);

    const [items, total] = await queryBuilder.getManyAndCount();

    // Enrich with user names
    const userIds = [...new Set(items.map(t => t.assignedUserId).filter(Boolean))];
    const userMap = new Map<string, string>();
    if (userIds.length > 0) {
      const users = await this.userRepository.find({
        where: userIds.map(id => ({ id })),
      });
      for (const u of users) {
        userMap.set(u.id, u.nickname || u.phone || u.id.substring(0, 8));
      }
    }
    const enriched = items.map(t => ({
      ...t,
      assignedUserName: t.assignedUserId ? (userMap.get(t.assignedUserId) || t.assignedUserId.substring(0, 8)) : null,
    }));

    return { items: enriched, total, page, pageSize };
  }

  async findOne(id: string): Promise<TextCollection> {
    const text = await this.textRepository.findOne({
      where: { id },
      relations: ['task'],
    });
    if (!text) throw new NotFoundException('文本不存在');
    return text;
  }

  async update(id: string, dto: Partial<TextCollection>): Promise<TextCollection> {
    const text = await this.findOne(id);
    Object.assign(text, dto);
    return this.textRepository.save(text);
  }

  async remove(id: string): Promise<void> {
    const text = await this.findOne(id);
    await this.textRepository.remove(text);
  }

  async assignTexts(dto: AssignTextDto): Promise<{ assigned: number }> {
    if (dto.autoAssign) {
      const taskId = dto.textIds?.[0]
        ? (await this.textRepository.findOne({ where: { id: dto.textIds[0] } }))?.taskId
        : undefined;

      if (!taskId) throw new BadRequestException('请指定任务ID');

      const [unassignedTexts, task] = await Promise.all([
        this.textRepository.find({
          where: { taskId, status: TextStatus.PENDING },
          order: { sortOrder: 'ASC' },
        }),
        this.taskRepository.findOne({ where: { id: taskId } }),
      ]);

      if (unassignedTexts.length === 0) throw new BadRequestException('没有待分配的文本');

      const claims = await this.claimRepository.find({
        where: { taskId, status: In([ClaimStatus.CLAIMED, ClaimStatus.IN_PROGRESS]) },
        order: { createdAt: 'ASC' },
      });

      if (claims.length === 0) throw new BadRequestException('没有可分配的用户');

      const mode = task?.textAssignMode || 'auto';
      const total = unassignedTexts.length;

      if (mode === 'even') {
        // 平均分配：按领取顺序，第一人取前 N 条，第二人取后续 N 条...
        const assignPeople = task?.textAssignCount || claims.length;
        const perUser = Math.ceil(total / assignPeople);
        let textIndex = 0;
        for (const claim of claims) {
          const slice = unassignedTexts.slice(textIndex, textIndex + perUser);
          if (slice.length === 0) break;
          for (const text of slice) {
            text.assignedUserId = claim.userId;
            text.assignedAt = new Date();
            text.status = TextStatus.ASSIGNED;
          }
          textIndex += perUser;
          if (textIndex >= total) break;
        }
        await this.textRepository.save(unassignedTexts);
        return { assigned: Math.min(textIndex, total) };
      }

      if (mode === 'per_user') {
        // 每人固定条数
        const perUser = task?.textPerUserCount || dto.perUserCount || 0;
        if (perUser <= 0) throw new BadRequestException('请配置每人条数');
        let textIndex = 0;
        for (const claim of claims) {
          const slice = unassignedTexts.slice(textIndex, textIndex + perUser);
          if (slice.length === 0) break;
          for (const text of slice) {
            text.assignedUserId = claim.userId;
            text.assignedAt = new Date();
            text.status = TextStatus.ASSIGNED;
          }
          textIndex += perUser;
          if (textIndex >= total) break;
        }
        await this.textRepository.save(unassignedTexts);
        return { assigned: Math.min(textIndex, total) };
      }

      // auto 模式：每人获取全部文本（复制分配）
      for (const claim of claims) {
        // Skip users who already have texts assigned for this task
        const existingCount = await this.textRepository.count({
          where: { taskId, assignedUserId: claim.userId },
        });
        if (existingCount > 0) continue;

        const copies = unassignedTexts.map((text) =>
          this.textRepository.create({
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
        // Batch save copies
        for (let i = 0; i < copies.length; i += 500) {
          await this.textRepository.save(copies.slice(i, i + 500));
        }
      }
      return { assigned: unassignedTexts.length * claims.length };
    }

    // Manual assign
    if (!dto.textIds || dto.textIds.length === 0) throw new BadRequestException('请选择要分配的文本');
    if (!dto.assignedUserId) throw new BadRequestException('请指定分配的用户');

    const texts = await this.textRepository.find({
      where: { id: In(dto.textIds) },
    });

    if (dto.copyForAssign) {
      const copies: TextCollection[] = [];
      for (const text of texts) {
        const copy = this.textRepository.create({
          ...text,
          id: undefined,
          assignedUserId: dto.assignedUserId,
          assignedAt: new Date(),
          status: TextStatus.ASSIGNED,
        });
        copies.push(copy);
      }
      for (let i = 0; i < copies.length; i += 500) {
        await this.textRepository.save(copies.slice(i, i + 500));
      }
      return { assigned: copies.length };
    }

    for (const text of texts) {
      text.assignedUserId = dto.assignedUserId;
      text.assignedAt = new Date();
      text.status = TextStatus.ASSIGNED;
    }
    await this.textRepository.save(texts);
    return { assigned: texts.length };
  }

  async recycleExpiredTexts(): Promise<{ recycled: number }> {
    // Find all assigned texts with their tasks to respect per-task recycleHours
    const assignedTexts = await this.textRepository
      .createQueryBuilder('text')
      .leftJoinAndSelect('text.task', 'task')
      .where('text.status = :status', { status: TextStatus.ASSIGNED })
      .getMany();

    const now = Date.now();
    const expiredTexts = assignedTexts.filter(text => {
      if (!text.assignedAt) return false;
      const recycleHours = text.task?.recycleHours || 48;
      const cutoff = now - recycleHours * 60 * 60 * 1000;
      return new Date(text.assignedAt).getTime() < cutoff;
    });

    for (const text of expiredTexts) {
      text.status = TextStatus.PENDING;
      text.assignedUserId = null as any;
      text.assignedAt = null as any;
    }

    await this.textRepository.save(expiredTexts);
    return { recycled: expiredTexts.length };
  }

  async getTextStats(taskId: string) {
    const result = await this.textRepository
      .createQueryBuilder('text')
      .select('text.status', 'status')
      .addSelect('COUNT(*)', 'count')
      .where('text.taskId = :taskId', { taskId })
      .groupBy('text.status')
      .getRawMany<{ status: string; count: string }>();

    const map: Record<string, number> = {};
    let total = 0;
    for (const row of result) {
      const count = parseInt(row.count, 10);
      map[row.status] = count;
      total += count;
    }

    return {
      total,
      pending: map[TextStatus.PENDING] || 0,
      assigned: map[TextStatus.ASSIGNED] || 0,
      collecting: map[TextStatus.COLLECTING] || 0,
      completed: map[TextStatus.COMPLETED] || 0,
      qcFailed: map[TextStatus.QC_FAILED] || 0,
    };
  }

  /** 获取分配给当前用户的文本列表（通过 claimId 找到 taskId + userId） */
  async getMyTexts(claimId: string, userId: string): Promise<TextCollection[]> {
    const claim = await this.claimRepository.findOne({
      where: { id: claimId, userId },
    });
    if (!claim) throw new NotFoundException('领取记录不存在或不属于你');

    // 检查是否已有分配的文本
    const existing = await this.textRepository.find({
      where: { taskId: claim.taskId, assignedUserId: userId },
      order: { sortOrder: 'ASC' },
    });

    if (existing.length > 0) return existing;

    // 首次访问：按任务模式自动分配文本
    await this.autoAssignForClaim(claim.taskId, userId);
    // 跳过所属检测，getNextAvailableText 已做了

    return this.textRepository.find({
      where: { taskId: claim.taskId, assignedUserId: userId },
      order: { sortOrder: 'ASC' },
    });
  }

  /** 按 claim 首次访问时自动分配文本 */
  private async autoAssignForClaim(taskId: string, userId: string): Promise<void> {
    const task = await this.taskRepository.findOne({ where: { id: taskId } });
    if (!task) return;

    const mode = task.textAssignMode || 'auto';

    // 获取所有文本（用 queryBuilder 避免 In() 在 sql.js 中的兼容问题）
    const allTexts = await this.textRepository
      .createQueryBuilder('text')
      .where('text.taskId = :taskId', { taskId })
      .andWhere('text.status IN (:...statuses)', { statuses: [TextStatus.PENDING, TextStatus.ASSIGNED] })
      .orderBy('text.sortOrder', 'ASC')
      .getMany();

    if (allTexts.length === 0) return;

    if (mode === 'auto') {
      // 为当前用户复制全量文本
      const copies = allTexts.map((text) =>
        this.textRepository.create({
          taskId: text.taskId,
          content: text.content,
          format: text.format,
          templateId: text.templateId,
          sortOrder: text.sortOrder,
          assignedUserId: userId,
          assignedAt: new Date(),
          status: TextStatus.ASSIGNED,
        }),
      );
      for (let i = 0; i < copies.length; i += 500) {
        await this.textRepository.save(copies.slice(i, i + 500));
      }
      return;
    }

    if (mode === 'even') {
      // 按领取顺序分段分配
      const claims = await this.claimRepository
        .createQueryBuilder('claim')
        .where('claim.taskId = :taskId', { taskId })
        .andWhere('claim.status IN (:...statuses)', { statuses: [ClaimStatus.CLAIMED, ClaimStatus.IN_PROGRESS] })
        .orderBy('claim.createdAt', 'ASC')
        .getMany();

      const userIndex = claims.findIndex(c => c.userId === userId);
      if (userIndex < 0) return;

      const pendingTexts = await this.textRepository
        .createQueryBuilder('text')
        .where('text.taskId = :taskId', { taskId })
        .andWhere('text.status = :status', { status: TextStatus.PENDING })
        .orderBy('text.sortOrder', 'ASC')
        .getMany();

      const total = allTexts.length;
      const assignPeople = task.textAssignCount || claims.length;
      const perUser = Math.ceil(total / assignPeople);

      const startIdx = userIndex * perUser;
      const endIdx = Math.min(startIdx + perUser, total);

      const mySlice = pendingTexts.filter(
        t => t.sortOrder >= startIdx && t.sortOrder < endIdx,
      );

      if (mySlice.length > 0) {
        for (const text of mySlice) {
          text.assignedUserId = userId;
          text.assignedAt = new Date();
          text.status = TextStatus.ASSIGNED;
        }
        await this.textRepository.save(mySlice);
      }
      return;
    }

    if (mode === 'per_user') {
      const perUser = task.textPerUserCount || 0;
      if (perUser <= 0) return;

      const pendingTexts = await this.textRepository
        .createQueryBuilder('text')
        .where('text.taskId = :taskId', { taskId })
        .andWhere('text.status = :status', { status: TextStatus.PENDING })
        .orderBy('text.sortOrder', 'ASC')
        .take(perUser)
        .getMany();

      if (pendingTexts.length > 0) {
        for (const text of pendingTexts) {
          text.assignedUserId = userId;
          text.assignedAt = new Date();
          text.status = TextStatus.ASSIGNED;
        }
        await this.textRepository.save(pendingTexts);
      }
    }
  }

  /** 更新单条文本的采集状态 */
  async updateTextStatus(
    id: string,
    status: TextStatus,
    userId: string,
    fileId?: string,
  ): Promise<TextCollection> {
    const text = await this.textRepository.findOne({ where: { id } });
    if (!text) throw new NotFoundException('文本不存在');
    if (text.assignedUserId !== userId) throw new ForbiddenException('无权操作此文本');

    text.status = status;
    if (fileId) {
      text.metadata = { ...(text.metadata || {}), fileId };
    }
    return this.textRepository.save(text);
  }
}
