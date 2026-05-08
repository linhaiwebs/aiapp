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
import { CategoryService } from './category.service';
import { CreateCategoryDto } from './dto';
import { Roles } from '../../common/decorators';
import { UserRole } from '../../entities';

@ApiTags('分类')
@Controller('categories')
export class CategoryController {
  constructor(private categoryService: CategoryService) {}

  @Get()
  @ApiOperation({ summary: '分类列表' })
  async findAll(
    @Query('type') type?: string,
    @Query('isActive') isActive?: string,
  ) {
    return this.categoryService.findAll(type, isActive);
  }

  @Get(':id')
  @ApiOperation({ summary: '分类详情' })
  async findOne(@Param('id') id: string) {
    return this.categoryService.findOne(id);
  }

  @Post()
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '创建分类' })
  async create(@Body() dto: CreateCategoryDto) {
    return this.categoryService.create(dto);
  }

  @Patch(':id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.LEADER, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '更新分类' })
  async update(@Param('id') id: string, @Body() dto: CreateCategoryDto) {
    return this.categoryService.update(id, dto);
  }

  @Delete(':id')
  @UseGuards(AuthGuard('jwt'))
  @ApiBearerAuth()
  @Roles(UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: '删除分类' })
  async remove(@Param('id') id: string) {
    await this.categoryService.remove(id);
    return { success: true };
  }
}
