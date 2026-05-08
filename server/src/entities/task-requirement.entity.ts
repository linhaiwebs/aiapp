import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
} from 'typeorm';
import { Task } from './task.entity';

@Entity('task_requirements')
export class TaskRequirement {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Task, (task) => task.requirements, { onDelete: 'CASCADE' })
  task: Task;

  @Column()
  taskId: string;

  @Column({ length: 200 })
  content: string;

  @Column({ default: false })
  isProhibited: boolean;

  @Column({ type: 'int', default: 0 })
  sortOrder: number;

  @CreateDateColumn()
  createdAt: Date;
}
