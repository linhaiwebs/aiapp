import {
  Injectable,
  NotFoundException,
  BadRequestException,
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
    await this.textRepository.save(texts);
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

    await this.textRepository.save(texts);
    return { count: texts.length };
  }

  async findAll(filter: TextFilterDto) {
    const { taskId, status, assignedUserId, page = 1, pageSize = 20 } = filter;

    const queryBuilder = this.textRepository
      .createQueryBuilder('text')
      .leftJoinAndSelect('text.task', 'task');

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
      // Auto-assign: get all unassigned texts for the task
      const taskId = dto.textIds?.[0]
        ? (await this.textRepository.findOne({ where: { id: dto.textIds[0] } }))?.taskId
        : undefined;

      if (!taskId) throw new BadRequestException('请指定任务ID');

      const [unassignedTexts, task] = await Promise.all([
        this.textRepository.find({
          where: { taskId, status: TextStatus.PENDING },
        }),
        this.taskRepository.findOne({ where: { id: taskId } }),
      ]);

      if (unassignedTexts.length === 0) throw new BadRequestException('没有待分配的文本');

      // Get users who claimed the task
      const claims = await this.claimRepository.find({
        where: { taskId, status: In([ClaimStatus.CLAIMED, ClaimStatus.IN_PROGRESS]) },
      });

      if (claims.length === 0) throw new BadRequestException('没有可分配的用户');

      // Determine per-user count:
      // 1. dto.perUserCount (explicit in request) takes priority
      // 2. task.textPerUserCount (每人X条 from task config)
      // 3. dto.assignCount (分配人数, split among N people)
      // 4. Auto: split equally among all claimants
      const perUserCount = dto.perUserCount || task?.textPerUserCount || 0;
      const assignCount = dto.assignCount || task?.textAssignCount || 0;
      let perUser: number;

      if (perUserCount > 0) {
        // 每人X条模式：每人分配固定条数
        perUser = perUserCount;
      } else if (assignCount > 0) {
        // 分配人数模式：均分给N个人
        perUser = Math.ceil(unassignedTexts.length / assignCount);
      } else {
        // 自动模式：均分给所有已领取用户
        perUser = Math.ceil(unassignedTexts.length / claims.length);
      }

      let textIndex = 0;
      for (const claim of claims) {
        const textsForUser = unassignedTexts.slice(textIndex, textIndex + perUser);
        if (textsForUser.length === 0) break;
        for (const text of textsForUser) {
          text.assignedUserId = claim.userId;
          text.assignedAt = new Date();
          text.status = TextStatus.ASSIGNED;
        }
        textIndex += perUser;
        if (textIndex >= unassignedTexts.length) break;
      }

      await this.textRepository.save(unassignedTexts);
      return { assigned: Math.min(textIndex, unassignedTexts.length) };
    }

    // Manual assign
    if (!dto.textIds || dto.textIds.length === 0) throw new BadRequestException('请选择要分配的文本');
    if (!dto.assignedUserId) throw new BadRequestException('请指定分配的用户');

    const texts = await this.textRepository.find({
      where: { id: In(dto.textIds) },
    });

    if (dto.copyForAssign) {
      // Copy texts for multiple assignees
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
      await this.textRepository.save(copies);
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
    const total = await this.textRepository.count({ where: { taskId } });
    const pending = await this.textRepository.count({ where: { taskId, status: TextStatus.PENDING } });
    const assigned = await this.textRepository.count({ where: { taskId, status: TextStatus.ASSIGNED } });
    const collecting = await this.textRepository.count({ where: { taskId, status: TextStatus.COLLECTING } });
    const completed = await this.textRepository.count({ where: { taskId, status: TextStatus.COMPLETED } });
    const qcFailed = await this.textRepository.count({ where: { taskId, status: TextStatus.QC_FAILED } });

    return { total, pending, assigned, collecting, completed, qcFailed };
  }
}
