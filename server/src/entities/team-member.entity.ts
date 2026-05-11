import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  Index,
} from 'typeorm';
import { Team } from './team.entity';

export enum TeamMemberRole {
  LEADER = 'leader',
  MEMBER = 'member',
}

export enum MemberStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  REJECTED = 'rejected',
}

@Entity('team_members')
export class TeamMember {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @ManyToOne(() => Team, (team) => team.members, { onDelete: 'CASCADE' })
  team: Team;

  @Column()
  teamId: string;

  @Column()
  userId: string;

  @Column({ length: 50, nullable: true })
  userName: string;

  @Column({ length: 20, nullable: true })
  phone: string;

  @Column({ length: 100, nullable: true })
  email: string;

  @Column({
    type: 'simple-enum',
    enum: TeamMemberRole,
    default: TeamMemberRole.MEMBER,
  })
  role: TeamMemberRole;

  @Column({
    type: 'simple-enum',
    enum: MemberStatus,
    default: MemberStatus.APPROVED,
  })
  status: MemberStatus;

  @Column({ type: 'varchar', length: 500, nullable: true })
  rejectReason: string | null;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
