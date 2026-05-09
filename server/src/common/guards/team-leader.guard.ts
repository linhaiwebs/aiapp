import { Injectable, CanActivate, ExecutionContext } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TeamMember, TeamMemberRole, UserRole } from '../../entities';

@Injectable()
export class TeamLeaderGuard implements CanActivate {
  constructor(
    @InjectRepository(TeamMember)
    private teamMemberRepository: Repository<TeamMember>,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const { user } = context.switchToHttp().getRequest();
    if (!user) return false;

    // System-level leaders and super admins always pass
    if (user.role === UserRole.LEADER || user.role === UserRole.SUPER_ADMIN) {
      return true;
    }

    // Check if user is a team leader (团长) in any team
    const count = await this.teamMemberRepository.count({
      where: { userId: user.id, role: TeamMemberRole.LEADER },
    });

    return count > 0;
  }
}
