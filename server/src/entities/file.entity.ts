import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';

export enum FileStatus {
  UPLOADING = 'uploading',
  COMPLETED = 'completed',
  QC_PROCESSING = 'qc_processing',
  QC_PASSED = 'qc_passed',
  QC_FAILED = 'qc_failed',
}

@Entity('files')
export class FileEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  @Column({ nullable: true })
  taskId: string;

  @Column()
  originalName: string;

  @Column()
  storedName: string;

  @Column()
  fileUrl: string;

  @Column({ type: 'bigint' })
  fileSize: number;

  @Column({ length: 50 })
  mimeType: string;

  @Column({ length: 20, nullable: true })
  taskType: string;

  @Column({
    type: 'simple-enum',
    enum: FileStatus,
    default: FileStatus.UPLOADING,
  })
  status: FileStatus;

  @Column({ type: 'simple-json', nullable: true })
  metadata: Record<string, any>;

  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  qcScore: number;

  @Column({ type: 'simple-json', nullable: true })
  qcReport: Record<string, any>;

  @Column({ type: 'simple-json', nullable: true })
  uploadInfo: Record<string, any>;

  @CreateDateColumn()
  createdAt: Date;
}
