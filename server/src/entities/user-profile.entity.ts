import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToOne,
  JoinColumn,
} from 'typeorm';
import { User } from './user.entity';

export enum VerificationStatus {
  PENDING = 'pending',
  VERIFIED = 'verified',
  REJECTED = 'rejected',
}

@Entity('user_profiles')
export class UserProfile {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @OneToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn()
  user: User;

  @Column()
  userId: string;

  @Column({ length: 50, nullable: true })
  realName: string;

  @Column({ length: 20, nullable: true })
  idCardNumber: string;

  @Column({
    type: 'simple-enum',
    enum: VerificationStatus,
    default: VerificationStatus.PENDING,
  })
  verificationStatus: VerificationStatus;

  @Column({ nullable: true })
  verifiedAt: Date;

  @Column({ nullable: true })
  idCardFrontUrl: string;

  @Column({ nullable: true })
  idCardBackUrl: string;

  @Column({ length: 20, nullable: true })
  province: string;

  @Column({ length: 20, nullable: true })
  city: string;

  @Column({ length: 20, nullable: true })
  district: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
