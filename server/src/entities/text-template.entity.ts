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
import { Task } from './task.entity';
import { TextCollection } from './text-collection.entity';

@Entity('text_templates')
export class TextTemplate {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @ManyToOne(() => Task, { onDelete: 'CASCADE' })
  task: Task;

  @Column()
  taskId: string;

  /** 模板名称 */
  @Column({ length: 200 })
  name: string;

  /** 原始文件名 */
  @Column({ length: 200, nullable: true })
  originalName: string;

  /** 文件URL */
  @Column({ nullable: true })
  fileUrl: string;

  /** 文件大小 */
  @Column({ type: 'bigint', nullable: true })
  fileSize: number;

  /** 文本格式 */
  @Column({ default: 'plain' })
  format: string;

  /** 文本行数 */
  @Column({ type: 'int', default: 0 })
  lineCount: number;

  /** 是否已解析为文本条目 */
  @Column({ default: false })
  isParsed: boolean;

  /** 解析后生成的文本条目 */
  @OneToMany(() => TextCollection, (tc) => tc.templateId)
  texts: TextCollection[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
