import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  Index,
} from 'typeorm';
import { User } from './user.entity';
import { TaskClaim } from './task-claim.entity';
import { Task } from './task.entity';

export enum SubmissionStatus {
  DRAFT = 'draft',
  SUBMITTED = 'submitted',
  QC_PROCESSING = 'qc_processing',
  QC_PASSED = 'qc_passed',
  QC_FAILED = 'qc_failed',
  PENDING_REVIEW = 'pending_review',
  APPROVED = 'approved',
  REJECTED = 'rejected',
}

@Entity('submissions')
export class Submission {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  user: User;

  @Column()
  userId: string;

  @ManyToOne(() => Task, { onDelete: 'CASCADE' })
  task: Task;

  @Column()
  taskId: string;

  @ManyToOne(() => TaskClaim, (claim) => claim.submissions, { onDelete: 'CASCADE' })
  claim: TaskClaim;

  @Column()
  claimId: string;

  @Column({
    type: 'simple-enum',
    enum: SubmissionStatus,
    default: SubmissionStatus.DRAFT,
  })
  status: SubmissionStatus;

  @Column({ type: 'simple-json', nullable: true })
  data: Record<string, any>;

  @Column({ type: 'simple-json', nullable: true })
  fileIds: string[];

  @Column({ type: 'simple-json', nullable: true })
  annotations: Record<string, any>;

  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  qcScore: number;

  @Column({ type: 'simple-json', nullable: true })
  qcReport: Record<string, any>;

  @Column({ length: 500, nullable: true })
  rejectReason: string;

  @Column({ nullable: true })
  reviewedAt: Date;

  @Column({ nullable: true })
  reviewerId: string;

  @Column({ type: 'int', default: 0 })
  retryCount: number;

  @Column({ nullable: true })
  submittedAt: Date;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
