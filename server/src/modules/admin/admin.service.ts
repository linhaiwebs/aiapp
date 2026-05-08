import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  User,
  Task,
  TaskClaim,
  Submission,
  Project,
  FileEntity,
  TaskStatus,
  SubmissionStatus,
  ClaimStatus,
  Team,
  TextCollection,
} from '../../entities';

@Injectable()
export class AdminService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(Task)
    private taskRepository: Repository<Task>,
    @InjectRepository(TaskClaim)
    private claimRepository: Repository<TaskClaim>,
    @InjectRepository(Submission)
    private submissionRepository: Repository<Submission>,
    @InjectRepository(Project)
    private projectRepository: Repository<Project>,
    @InjectRepository(FileEntity)
    private fileRepository: Repository<FileEntity>,
    @InjectRepository(Team)
    private teamRepository: Repository<Team>,
    @InjectRepository(TextCollection)
    private textRepository: Repository<TextCollection>,
  ) {}

  async getStats() {
    const [
      totalUsers,
      totalTasks,
      totalSubmissions,
      totalProjects,
      activeTasks,
      pendingReview,
      totalClaims,
      approvedSubmissions,
      rejectedSubmissions,
      totalTeams,
      totalTexts,
    ] = await Promise.all([
      this.userRepository.count(),
      this.taskRepository.count(),
      this.submissionRepository.count(),
      this.projectRepository.count(),
      this.taskRepository.count({
        where: [
          { status: TaskStatus.PUBLISHED },
          { status: TaskStatus.IN_PROGRESS },
        ],
      }),
      this.submissionRepository.count({
        where: { status: SubmissionStatus.PENDING_REVIEW },
      }),
      this.claimRepository.count(),
      this.submissionRepository.count({
        where: { status: SubmissionStatus.APPROVED },
      }),
      this.submissionRepository.count({
        where: { status: SubmissionStatus.REJECTED },
      }),
      this.teamRepository.count(),
      this.textRepository.count(),
    ]);

    const userRoles = await this.userRepository
      .createQueryBuilder('user')
      .select('user.role', 'role')
      .addSelect('COUNT(*)', 'count')
      .groupBy('user.role')
      .getRawMany();

    const taskTypes = await this.taskRepository
      .createQueryBuilder('task')
      .select('task.type', 'type')
      .addSelect('COUNT(*)', 'count')
      .groupBy('task.type')
      .getRawMany();

    const taskStatuses = await this.taskRepository
      .createQueryBuilder('task')
      .select('task.status', 'status')
      .addSelect('COUNT(*)', 'count')
      .groupBy('task.status')
      .getRawMany();

    const totalEarnings = await this.submissionRepository
      .createQueryBuilder('s')
      .leftJoin('s.task', 't')
      .where('s.status = :status', { status: SubmissionStatus.APPROVED })
      .select('COALESCE(SUM(t.unitPrice), 0)', 'total')
      .getRawOne();

    return {
      totalUsers,
      totalTasks,
      totalSubmissions,
      totalProjects,
      activeTasks,
      pendingReview,
      totalClaims,
      approvedSubmissions,
      rejectedSubmissions,
      totalTeams,
      totalTexts,
      totalEarnings: parseFloat(totalEarnings?.total || '0'),
      userRoleDistribution: userRoles.reduce(
        (acc, r) => ({ ...acc, [r.role]: parseInt(r.count) }),
        {},
      ),
      taskTypeDistribution: taskTypes.reduce(
        (acc, r) => ({ ...acc, [r.type]: parseInt(r.count) }),
        {},
      ),
      taskStatusDistribution: taskStatuses.reduce(
        (acc, r) => ({ ...acc, [r.status]: parseInt(r.count) }),
        {},
      ),
    };
  }

  async getTrends() {
    const now = new Date();
    const last30Days = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

    const newUsers = await this.userRepository
      .createQueryBuilder('user')
      .select("strftime('%Y-%m-%d', user.createdAt)", 'date')
      .addSelect('COUNT(*)', 'count')
      .where('user.createdAt >= :start', { start: last30Days })
      .groupBy("strftime('%Y-%m-%d', user.createdAt)")
      .orderBy('date', 'ASC')
      .getRawMany();

    const newSubmissions = await this.submissionRepository
      .createQueryBuilder('s')
      .select("strftime('%Y-%m-%d', s.createdAt)", 'date')
      .addSelect('COUNT(*)', 'count')
      .where('s.createdAt >= :start', { start: last30Days })
      .groupBy("strftime('%Y-%m-%d', s.createdAt)")
      .orderBy('date', 'ASC')
      .getRawMany();

    return { newUsers, newSubmissions };
  }

  async exportTasks(projectId?: string): Promise<any[]> {
    const queryBuilder = this.taskRepository
      .createQueryBuilder('task')
      .leftJoinAndSelect('task.project', 'project')
      .leftJoinAndSelect('task.category', 'category');

    if (projectId) {
      queryBuilder.andWhere('task.projectId = :projectId', { projectId });
    }

    return queryBuilder.getMany();
  }

  async exportSubmissions(taskId?: string): Promise<any[]> {
    const queryBuilder = this.submissionRepository
      .createQueryBuilder('s')
      .leftJoinAndSelect('s.task', 'task')
      .leftJoinAndSelect('s.user', 'user');

    if (taskId) {
      queryBuilder.andWhere('s.taskId = :taskId', { taskId });
    }

    return queryBuilder.getMany();
  }

  async exportAudioLinks(taskId?: string): Promise<any[]> {
    const queryBuilder = this.fileRepository
      .createQueryBuilder('file')
      .where('file.taskType = :taskType', { taskType: 'audio' });

    if (taskId) {
      queryBuilder.andWhere('file.taskId = :taskId', { taskId });
    }

    const files = await queryBuilder.getMany();
    return files.map(f => ({
      id: f.id,
      fileName: f.originalName,
      fileUrl: f.fileUrl,
      taskId: f.taskId,
      userId: f.userId,
      mimeType: f.mimeType,
      fileSize: f.fileSize,
      status: f.status,
      createdAt: f.createdAt,
    }));
  }

  toCSV(data: any[], columns: string[]): string {
    if (data.length === 0) return '';
    const header = columns.join(',');
    const rows = data.map(row =>
      columns.map(col => {
        const val = row[col];
        if (val === null || val === undefined) return '';
        const str = String(val);
        return str.includes(',') || str.includes('"') || str.includes('\n')
          ? `"${str.replace(/"/g, '""')}"`
          : str;
      }).join(','),
    );
    return [header, ...rows].join('\n');
  }
}
