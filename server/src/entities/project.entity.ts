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
import { User } from './user.entity';

@Entity('projects')
export class Project {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ length: 200 })
  name: string;

  @Column({ type: 'text', nullable: true })
  description: string;

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

  @OneToMany(() => Task, (task) => task.project)
  tasks: Task[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
