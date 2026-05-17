import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { In } from 'typeorm';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  Submission,
  SubmissionStatus,
  TaskClaim,
  ClaimStatus,
  Task,
  TaskStatus,
  FileEntity,
  FileStatus,
} from '../../entities';
import { CreateSubmissionDto, UpdateSubmissionDto } from './dto';

@Injectable()
export class SubmissionService {
  constructor(
    @InjectRepository(Submission)
    private submissionRepository: Repository<Submission>,
    @InjectRepository(TaskClaim)
    private claimRepository: Repository<TaskClaim>,
    @InjectRepository(Task)
    private taskRepository: Repository<Task>,
    @InjectRepository(FileEntity)
    private fileRepository: Repository<FileEntity>,
  ) {}

  async create(userId: string, dto: CreateSubmissionDto): Promise<Submission> {
    const claim = await this.claimRepository.findOne({
      where: { id: dto.claimId, userId },
      relations: ['task'],
    });
    if (!claim) throw new NotFoundException('领取记录不存在');
    if (claim.status !== ClaimStatus.CLAIMED && claim.status !== ClaimStatus.IN_PROGRESS) {
      throw new BadRequestException('当前状态不可提交');
    }

    // Verify files exist
    if (dto.fileIds?.length) {
      const files = await this.fileRepository.find({
        where: dto.fileIds.map(id => ({ id })),
      });
      if (files.length !== dto.fileIds.length) {
        throw new BadRequestException('部分文件不存在');
      }
    }

    const submission = this.submissionRepository.create({
      userId,
      taskId: claim.taskId,
      claimId: dto.claimId,
      fileIds: dto.fileIds,
      data: dto.data,
      annotations: dto.annotations,
      status: SubmissionStatus.SUBMITTED,
      submittedAt: new Date(),
    });

    await this.submissionRepository.save(submission);

    // Update claim status
    claim.status = ClaimStatus.SUBMITTED;
    claim.submittedCount += 1;
    claim.submittedAt = new Date();
    await this.claimRepository.save(claim);

    // Trigger QC asynchronously (will be implemented in Phase 2)
    // For now, set to pending review
    submission.status = SubmissionStatus.PENDING_REVIEW;
    await this.submissionRepository.save(submission);

    return submission;
  }

  async findByUser(
    userId: string,
    status?: SubmissionStatus,
    page = 1,
    pageSize = 20,
  ) {
    const queryBuilder = this.submissionRepository
      .createQueryBuilder('submission')
      .leftJoinAndSelect('submission.task', 'task')
      .where('submission.userId = :userId', { userId });

    if (status) {
      queryBuilder.andWhere('submission.status = :status', { status });
    }

    queryBuilder
      .orderBy('submission.createdAt', 'DESC')
      .skip((page - 1) * pageSize)
      .take(pageSize);

    const [items, total] = await queryBuilder.getManyAndCount();
    return { items, total, page, pageSize };
  }

  async findOne(id: string, userId?: string): Promise<Submission> {
    const submission = await this.submissionRepository.findOne({
      where: { id },
      relations: ['task', 'claim', 'user'],
    });
    if (!submission) throw new NotFoundException('提交记录不存在');
    // If userId provided, verify ownership (skip for admin)
    if (userId && submission.userId !== userId) {
      throw new ForbiddenException('无权查看此提交');
    }
    return submission;
  }

  async update(id: string, userId: string, dto: UpdateSubmissionDto): Promise<Submission> {
    const submission = await this.findOne(id, userId);
    if (submission.status !== SubmissionStatus.DRAFT && submission.status !== SubmissionStatus.REJECTED) {
      throw new BadRequestException('当前状态不可修改');
    }

    Object.assign(submission, dto);
    if (submission.status === SubmissionStatus.REJECTED) {
      submission.status = SubmissionStatus.SUBMITTED;
      submission.retryCount += 1;
      submission.submittedAt = new Date();
    }

    return this.submissionRepository.save(submission);
  }

  async remove(id: string, userId: string): Promise<void> {
    const submission = await this.findOne(id, userId);
    if (submission.status !== SubmissionStatus.DRAFT) {
      throw new BadRequestException('只能删除草稿状态的提交');
    }
    await this.submissionRepository.remove(submission);
  }

  async findPendingReview(page = 1, pageSize = 20, taskId?: string) {
    const queryBuilder = this.submissionRepository
      .createQueryBuilder('submission')
      .leftJoinAndSelect('submission.task', 'task')
      .leftJoinAndSelect('submission.user', 'user')
      .where('submission.status = :status', {
        status: SubmissionStatus.PENDING_REVIEW,
      });

    if (taskId) {
      queryBuilder.andWhere('submission.taskId = :taskId', { taskId });
    }

    queryBuilder
      .orderBy('submission.submittedAt', 'ASC')
      .skip((page - 1) * pageSize)
      .take(pageSize);

    const [items, total] = await queryBuilder.getManyAndCount();
    return { items, total, page, pageSize };
  }

  async findAll(params: {
    page?: number;
    pageSize?: number;
    status?: SubmissionStatus;
    taskId?: string;
    userId?: string;
    taskType?: string;
  }) {
    const { page = 1, pageSize = 20, status, taskId, userId, taskType } = params;

    const queryBuilder = this.submissionRepository
      .createQueryBuilder('submission')
      .leftJoinAndSelect('submission.task', 'task')
      .leftJoinAndSelect('submission.user', 'user');

    if (status) {
      queryBuilder.andWhere('submission.status = :status', { status });
    }
    if (taskId) {
      queryBuilder.andWhere('submission.taskId = :taskId', { taskId });
    }
    if (userId) {
      queryBuilder.andWhere('submission.userId = :userId', { userId });
    }
    if (taskType) {
      queryBuilder.andWhere('task.type = :taskType', { taskType });
    }

    queryBuilder
      .orderBy('submission.createdAt', 'DESC')
      .skip((page - 1) * pageSize)
      .take(pageSize);

    const [items, total] = await queryBuilder.getManyAndCount();
    return { items, total, page, pageSize };
  }

  async approve(id: string, reviewerId: string): Promise<Submission> {
    const submission = await this.findOne(id);
    if (submission.status !== SubmissionStatus.PENDING_REVIEW) {
      throw new BadRequestException('当前状态不可审核');
    }

    submission.status = SubmissionStatus.APPROVED;
    submission.reviewerId = reviewerId;
    submission.reviewedAt = new Date();

    await this.submissionRepository.save(submission);

    // Update claim: mark completed and increment passedCount
    const claim = await this.claimRepository.findOne({
      where: { id: submission.claimId },
    });
    if (claim) {
      claim.passedCount += 1;
      // Reset to IN_PROGRESS so user can continue submitting
      claim.status = ClaimStatus.IN_PROGRESS;
      await this.claimRepository.save(claim);

      // Update task: increment completedQuantity
      await this.taskRepository.increment(
        { id: claim.taskId },
        'completedQuantity',
        1,
      );

      // Check if task is fully completed (after increment, so just compare)
      const task = await this.taskRepository.findOne({ where: { id: claim.taskId } });
      if (task && Number(task.completedQuantity) >= Number(task.totalQuantity)) {
        task.status = TaskStatus.COMPLETED;
        await this.taskRepository.save(task);
      }
    }

    return submission;
  }

  async reject(id: string, reviewerId: string, reason: string): Promise<Submission> {
    const submission = await this.findOne(id);
    if (submission.status !== SubmissionStatus.PENDING_REVIEW) {
      throw new BadRequestException('当前状态不可审核');
    }

    submission.status = SubmissionStatus.REJECTED;
    submission.reviewerId = reviewerId;
    submission.reviewedAt = new Date();
    submission.rejectReason = reason;

    await this.submissionRepository.save(submission);

    // Update claim stats
    await this.claimRepository.increment(
      { id: submission.claimId },
      'rejectedCount',
      1,
    );

    // Reset claim status for re-submission
    const claim = await this.claimRepository.findOne({
      where: { id: submission.claimId },
    });
    if (claim) {
      claim.status = ClaimStatus.IN_PROGRESS;
      await this.claimRepository.save(claim);
    }

    return submission;
  }

  async adminUpdate(id: string, dto: UpdateSubmissionDto): Promise<Submission> {
    const submission = await this.submissionRepository.findOne({ where: { id } });
    if (!submission) throw new NotFoundException('提交记录不存在');
    Object.assign(submission, dto);
    return this.submissionRepository.save(submission);
  }

  async adminRemove(id: string): Promise<void> {
    const submission = await this.submissionRepository.findOne({ where: { id } });
    if (!submission) throw new NotFoundException('提交记录不存在');
    await this.submissionRepository.remove(submission);
  }

  async batchRemove(ids: string[]): Promise<void> {
    if (!ids?.length) throw new BadRequestException('请提供要删除的ID列表');
    await this.submissionRepository.delete(ids);
  }
}
