import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { TeamService } from './team.service';
import { CreateTeamDto, AddTeamMemberDto, InviteMemberDto } from './dto';
import { Roles, CurrentUser } from '../../common/decorators';
import { UserRole } from '../../entities';

@ApiTags('团队')
@Controller('teams')
export class TeamController {
  constructor(private teamService: TeamService) {}

  @Get()
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '我的团队列表' })
  async findAll(
    @CurrentUser('userId') userId: string,
    @Query('page') page = 1,
    @Query('pageSize') pageSize = 20,
    @Query('keyword') keyword?: string,
  ) {
    return this.teamService.findAll(page, pageSize, keyword, userId);
  }

  @Get(':id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '团队详情' })
  async findOne(
    @Param('id') id: string,
    @CurrentUser('userId') userId: string,
  ) {
    return this.teamService.findOne(id, userId);
  }

  @Get(':id/members')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '团队成员列表' })
  async getMembers(
    @Param('id') id: string,
    @CurrentUser('userId') userId: string,
  ) {
    return this.teamService.getMembers(id, userId);
  }

  @Post()
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '创建团队' })
  async create(@Body() dto: CreateTeamDto) {
    return this.teamService.create(dto);
  }

  @Patch(':id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '更新团队' })
  async update(@Param('id') id: string, @Body() dto: CreateTeamDto) {
    return this.teamService.update(id, dto);
  }

  @Delete(':id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '删除团队' })
  async remove(@Param('id') id: string) {
    await this.teamService.remove(id);
    return { success: true };
  }

  @Post(':id/members')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '添加团队成员' })
  async addMember(@Param('id') id: string, @Body() dto: AddTeamMemberDto) {
    return this.teamService.addMember(id, dto);
  }

  @Delete(':id/members/:memberId')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '移除团队成员' })
  async removeMember(@Param('id') id: string, @Param('memberId') memberId: string) {
    await this.teamService.removeMember(id, memberId);
    return { success: true };
  }

  @Post(':id/invite')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '邀请新成员' })
  async inviteMember(@Param('id') id: string, @Body() dto: InviteMemberDto) {
    return this.teamService.inviteMember(id, dto);
  }

  @Post('join')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '通过口令加入团队（需团长审批）' })
  async joinTeam(
    @CurrentUser('userId') userId: string,
    @Body('joinCode') joinCode: string,
  ) {
    return this.teamService.joinByCode(userId, joinCode);
  }

  @Get(':id/members/pending')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '待审批成员列表（团长/超级管理员）' })
  async getPendingMembers(@Param('id') id: string) {
    return this.teamService.getPendingMembers(id);
  }

  @Post(':id/members/:memberId/approve')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '审批通过成员' })
  async approveMember(
    @Param('id') id: string,
    @Param('memberId') memberId: string,
    @CurrentUser('userId') reviewerId: string,
  ) {
    return this.teamService.approveMember(id, memberId, reviewerId);
  }

  @Post(':id/members/:memberId/reject')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @ApiOperation({ summary: '驳回成员申请' })
  async rejectMember(
    @Param('id') id: string,
    @Param('memberId') memberId: string,
    @CurrentUser('userId') reviewerId: string,
    @Body('reason') reason?: string,
  ) {
    return this.teamService.rejectMember(id, memberId, reviewerId, reason);
  }
}
