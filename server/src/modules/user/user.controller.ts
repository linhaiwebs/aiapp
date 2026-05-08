import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Body,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { UserService } from './user.service';
import { Roles } from '../../common/decorators';
import { UserRole } from '../../entities';

@ApiTags('用户管理')
@Controller('users')
@UseGuards(AuthGuard('jwt'))
@ApiBearerAuth()
@Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
export class UserController {
  constructor(private userService: UserService) {}

  @Get()
  @ApiOperation({ summary: '用户列表' })
  async findAll(
    @Query('page') page = 1,
    @Query('pageSize') pageSize = 20,
    @Query('role') role?: string,
    @Query('status') status?: string,
    @Query('keyword') keyword?: string,
  ) {
    return this.userService.findAll({ page, pageSize, role, status, keyword });
  }

  @Get(':id')
  @ApiOperation({ summary: '用户详情' })
  async findOne(@Param('id') id: string) {
    return this.userService.findOne(id);
  }

  @Post()
  @ApiOperation({ summary: '添加账号' })
  async create(@Body() dto: any) {
    return this.userService.create(dto);
  }

  @Post('invite')
  @ApiOperation({ summary: '邀请新成员' })
  async invite(@Body() dto: { phone: string; role?: string; nickname?: string }) {
    return this.userService.invite(dto);
  }

  @Patch(':id')
  @ApiOperation({ summary: '更新用户' })
  async update(@Param('id') id: string, @Body() dto: any) {
    return this.userService.update(id, dto);
  }

  @Patch(':id/status')
  @ApiOperation({ summary: '更新用户状态' })
  async updateStatus(@Param('id') id: string, @Body('status') status: string) {
    return this.userService.updateStatus(id, status);
  }
}
