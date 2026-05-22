import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  OneToMany,
  Index,
} from 'typeorm';
import { User } from './user.entity';
import { Task } from './task.entity';
import { Submission } from './submission.entity';

export enum ClaimStatus {
  PENDING_APPROVAL = 'pending_approval',
  /** 采样审核中 */
  SAMPLE_REVIEW = 'sample_review',
  /** 采样驳回 */
  SAMPLE_REJECTED = 'sample_rejected',
  CLAIMED = 'claimed',
  IN_PROGRESS = 'in_progress',
  SUBMITTED = 'submitted',
  COMPLETED = 'completed',
  ABANDONED = 'abandoned',
  EXPIRED = 'expired',
  REJECTED = 'rejected',
}

@Entity('task_claims')
export class TaskClaim {
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

  @Column({
    type: 'simple-enum',
    enum: ClaimStatus,
    default: ClaimStatus.CLAIMED,
  })
  status: ClaimStatus;

  @Column({ nullable: true })
  claimedAt: Date;

  @Column({ nullable: true })
  deadline: Date;

  @Column({ nullable: true })
  submittedAt: Date;

  @Column({ nullable: true })
  completedAt: Date;

  @Column({ type: 'int', default: 0 })
  submittedCount: number;

  @Column({ type: 'int', default: 0 })
  passedCount: number;

  @Column({ type: 'int', default: 0 })
  rejectedCount: number;

  /** 采样文件ID */
  @Column({ nullable: true })
  sampleFileId: string;

  /** 采样驳回原因 */
  @Column({ type: 'text', nullable: true })
  sampleRejectReason: string;

  /** 采样审核时间 */
  @Column({ nullable: true })
  sampleReviewedAt: Date;

  @OneToMany(() => Submission, (submission) => submission.claim)
  submissions: Submission[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
