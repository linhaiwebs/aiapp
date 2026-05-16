import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  Index,
} from 'typeorm';
import { Task } from './task.entity';

export enum TextFormat {
  PLAIN = 'plain',
  SML = 'sml',
}

export enum TextStatus {
  PENDING = 'pending',
  ASSIGNED = 'assigned',
  COLLECTING = 'collecting',
  COMPLETED = 'completed',
  QC_FAILED = 'qc_failed',
}

@Entity('text_collections')
@Index(['taskId', 'status'])
export class TextCollection {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @ManyToOne(() => Task, { onDelete: 'CASCADE' })
  task: Task;

  @Column()
  taskId: string;

  /** 文本内容 */
  @Column({ type: 'text' })
  content: string;

  /** 文本格式 */
  @Column({
    type: 'simple-enum',
    enum: TextFormat,
    default: TextFormat.PLAIN,
  })
  format: TextFormat;

  /** 文本状态 */
  @Column({
    type: 'simple-enum',
    enum: TextStatus,
    default: TextStatus.PENDING,
  })
  status: TextStatus;

  /** 分配给的用户ID */
  @Column({ nullable: true })
  assignedUserId: string;

  /** 分配时间 */
  @Column({ nullable: true })
  assignedAt: Date;

  /** 来源模板ID */
  @Column({ nullable: true })
  templateId: string;

  /** 排序序号 */
  @Column({ type: 'int', default: 0 })
  sortOrder: number;

  /** 扩展元数据 */
  @Column({ type: 'simple-json', nullable: true })
  metadata: Record<string, any>;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
