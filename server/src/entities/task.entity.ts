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
import { Project } from './project.entity';
import { Category } from './category.entity';
import { Team } from './team.entity';
import { TaskRequirement } from './task-requirement.entity';
import { TaskSample } from './task-sample.entity';
import { TaskClaim } from './task-claim.entity';

export enum TaskType {
  AUDIO = 'audio',
  IMAGE = 'image',
  VIDEO = 'video',
  TEXT = 'text',
}

export enum TaskStatus {
  DRAFT = 'draft',
  PUBLISHED = 'published',
  IN_PROGRESS = 'in_progress',
  COMPLETED = 'completed',
  CLOSED = 'closed',
  ARCHIVED = 'archived',
}

export enum TaskDifficulty {
  EASY = 'easy',
  MEDIUM = 'medium',
  HARD = 'hard',
}

export enum QcMethod {
  SPOT_CHECK = 'spot_check',
  MANUAL_SPOT_CHECK = 'manual_spot_check',
}

export enum AudioFormat {
  WAV = 'wav',
  PCM = 'pcm',
}

export enum AudioChannel {
  MONO = 'mono',
  STEREO = 'stereo',
}

export enum SampleRate {
  SR_16000 = 16000,
  SR_44100 = 44100,
  SR_48000 = 48000,
}

@Entity('tasks')
export class Task {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ length: 200 })
  title: string;

  @Column({ type: 'text', nullable: true })
  description: string;

  @Column({
    type: 'simple-enum',
    enum: TaskType,
  })
  type: TaskType;

  @Column({
    type: 'simple-enum',
    enum: TaskStatus,
    default: TaskStatus.DRAFT,
  })
  status: TaskStatus;

  @Column({
    type: 'simple-enum',
    enum: TaskDifficulty,
    default: TaskDifficulty.EASY,
  })
  difficulty: TaskDifficulty;

  @Column({ type: 'decimal', precision: 10, scale: 2 })
  unitPrice: number;

  @Column({ type: 'int' })
  totalQuantity: number;

  @Column({ type: 'int', default: 0 })
  claimedQuantity: number;

  @Column({ type: 'int', default: 0 })
  completedQuantity: number;

  @Column({ type: 'int', default: 1 })
  maxClaimsPerUser: number;

  @Column({ length: 20, nullable: true })
  region: string;

  @Column({ length: 20, nullable: true })
  language: string;

  @Column({ type: 'decimal', precision: 5, scale: 2, default: 60 })
  minQualityScore: number;

  @Column({ type: 'decimal', precision: 5, scale: 2, default: 0 })
  passRateRequirement: number;

  @Column({ nullable: true })
  deadline: Date;

  @Column({ nullable: true })
  startedAt: Date;

  @Column({ type: 'text', nullable: true })
  instructions: string;

  @Column({ type: 'simple-json', nullable: true })
  qcConfig: Record<string, any>;

  @Column({ type: 'simple-json', nullable: true })
  typeConfig: Record<string, any>;

  // ===== 质检方式 =====
  @Column({
    type: 'simple-enum',
    enum: QcMethod,
    default: QcMethod.SPOT_CHECK,
    nullable: true,
  })
  qcMethod: QcMethod;

  // ===== 音频配置 =====
  @Column({
    type: 'simple-enum',
    enum: AudioFormat,
    default: AudioFormat.WAV,
    nullable: true,
  })
  audioFormat: AudioFormat;

  @Column({
    type: 'simple-enum',
    enum: AudioChannel,
    default: AudioChannel.MONO,
    nullable: true,
  })
  audioChannel: AudioChannel;

  @Column({
    type: 'simple-enum',
    enum: SampleRate,
    default: SampleRate.SR_16000,
    nullable: true,
  })
  sampleRate: SampleRate;

  /** 噪音上限 (dB) */
  @Column({ type: 'int', nullable: true })
  noiseLimit: number;

  /** 最大语音长度（秒） */
  @Column({ type: 'int', nullable: true })
  maxSpeechLength: number;

  /** 静音区预留时间（毫秒） */
  @Column({ type: 'int', nullable: true })
  silencePadding: number;

  // ===== 机器辅助功能 =====
  /** 辅助识别 */
  @Column({ default: false })
  assistRecognition: boolean;

  /** 静音检测 */
  @Column({ default: false })
  silenceDetection: boolean;

  /** 声纹检测 */
  @Column({ default: false })
  voiceprintDetection: boolean;

  /** 增幅检测 */
  @Column({ default: false })
  gainDetection: boolean;

  /** 信号检测 */
  @Column({ default: false })
  signalDetection: boolean;

  // ===== 任务分配 =====
  /** 是否允许多次领取 */
  @Column({ default: false })
  allowMultipleClaims: boolean;

  /** 验收轮数 */
  @Column({ type: 'int', default: 1 })
  reviewRounds: number;

  /** 回收时间（小时） */
  @Column({ type: 'int', default: 48 })
  recycleHours: number;

  /** 文本分配人数（0表示自动计算） */
  @Column({ type: 'int', default: 0 })
  textAssignCount: number;

  /** 每人分配条数（0表示不启用此模式） */
  @Column({ type: 'int', default: 0 })
  textPerUserCount: number;

  /** 是否复制多份文本分配给多名采集人员 */
  @Column({ default: false })
  textCopyForAssign: boolean;

  // ===== 关联 =====
  @ManyToOne(() => Project, (project) => project.tasks, { nullable: true })
  project: Project;

  @Column({ nullable: true })
  projectId: string;

  @ManyToOne(() => Category, (category) => category.tasks, { nullable: true })
  category: Category;

  @Column({ nullable: true })
  categoryId: string;

  @ManyToOne(() => Team, { nullable: true })
  team: Team;

  @Column({ nullable: true })
  teamId: string;

  @OneToMany(() => TaskRequirement, (req) => req.task, { cascade: true })
  requirements: TaskRequirement[];

  @OneToMany(() => TaskSample, (sample) => sample.task, { cascade: true })
  samples: TaskSample[];

  @OneToMany(() => TaskClaim, (claim) => claim.task)
  claims: TaskClaim[];

  @Column({ default: 0 })
  sortOrder: number;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
