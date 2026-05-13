import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Task } from './task.entity';
import type { TaskType } from './task.entity';
import { User } from './user.entity';
import { Team } from './team.entity';

@Entity('projects')
export class Project {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ length: 200 })
  name: string;

  @Column({ type: 'text', nullable: true })
  description: string;

  /** 项目默认任务类型 */
  @Column({
    type: 'simple-enum',
    enum: ['audio', 'image', 'video', 'text'],
    default: 'audio',
  })
  type: TaskType;

  @Column({ nullable: true })
  startDate: Date;

  @Column({ nullable: true })
  endDate: Date;

  @Column({ type: 'simple-json', nullable: true })
  qcRules: Record<string, any>;

  @Column({ type: 'simple-json', nullable: true })
  paymentTemplate: Record<string, any>;

  @Column({ default: true })
  isActive: boolean;

  /** 项目地区 */
  @Column({ length: 100, nullable: true })
  region: string;

  /** 部门识别方式 */
  @Column({ length: 100, nullable: true })
  department: string;

  /** 负责人ID */
  @Column({ nullable: true })
  ownerId: string;

  @ManyToOne(() => User, { nullable: true, createForeignKeyConstraints: false })
  @JoinColumn({ name: 'ownerId' })
  owner: User;

  /** 验收人ID */
  @Column({ nullable: true })
  acceptorId: string;

  @ManyToOne(() => User, { nullable: true, createForeignKeyConstraints: false })
  @JoinColumn({ name: 'acceptorId' })
  acceptor: User;

  /** 采集前是否需要授权签名 */
  @Column({ default: false })
  requireSignature: boolean;

  /** 回收时间（小时），超时未完成任务自动回收 */
  @Column({ type: 'int', default: 48 })
  recycleHours: number;

  /** 所属团队ID */
  @Column({ nullable: true })
  teamId: string;

  @ManyToOne(() => Team, { nullable: true, createForeignKeyConstraints: false })
  @JoinColumn({ name: 'teamId' })
  team: Team;

  @OneToMany(() => Task, (task) => task.project)
  tasks: Task[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
