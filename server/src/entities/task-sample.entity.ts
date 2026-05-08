import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
} from 'typeorm';
import { Task } from './task.entity';

@Entity('task_samples')
export class TaskSample {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Task, (task) => task.samples, { onDelete: 'CASCADE' })
  task: Task;

  @Column()
  taskId: string;

  @Column()
  fileUrl: string;

  @Column({ length: 50, nullable: true })
  fileType: string;

  @Column({ length: 200, nullable: true })
  description: string;

  @Column({ type: 'int', default: 0 })
  sortOrder: number;

  @CreateDateColumn()
  createdAt: Date;
}
