import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
  BeforeInsert,
} from 'typeorm';
import { TeamMember } from './team-member.entity';
import * as crypto from 'crypto';

@Entity('teams')
export class Team {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ length: 100 })
  name: string;

  @Column({ type: 'text', nullable: true })
  description: string;

  @Column({ nullable: true })
  leaderId: string;

  @Column({ length: 100, nullable: true })
  leaderName: string;

  @Column({ default: true })
  isActive: boolean;

  @Column({ length: 8, default: '00000000' })
  joinCode: string;

  @OneToMany(() => TeamMember, (member) => member.team, { cascade: true })
  members: TeamMember[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @BeforeInsert()
  generateJoinCode() {
    if (!this.joinCode) {
      this.joinCode = crypto.randomInt(10000000, 99999999).toString();
    }
  }
}
