import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { Project } from './project.entity';

@Entity('project_documents')
export class ProjectDocument {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column()
  projectId: string;

  @ManyToOne(() => Project, { nullable: true, createForeignKeyConstraints: false })
  @JoinColumn({ name: 'projectId' })
  project: Project;

  /** 文档名称（取文件名） */
  @Column({ length: 255 })
  title: string;

  /** 文档内容 */
  @Column({ type: 'text' })
  content: string;

  /** 原始文件名 */
  @Column({ length: 500, nullable: true })
  fileName: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
