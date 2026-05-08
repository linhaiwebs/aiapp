import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Project, Task } from '../../entities';
import { CreateProjectDto } from './dto';

@Injectable()
export class ProjectService {
  constructor(
    @InjectRepository(Project)
    private projectRepository: Repository<Project>,
    @InjectRepository(Task)
    private taskRepository: Repository<Task>,
  ) {}

  async create(dto: CreateProjectDto): Promise<Project> {
    const project = this.projectRepository.create(dto);
    return this.projectRepository.save(project);
  }

  async findAll(page = 1, pageSize = 20) {
    const [items, total] = await this.projectRepository.findAndCount({
      relations: ['tasks'],
      skip: (page - 1) * pageSize,
      take: pageSize,
      order: { createdAt: 'DESC' },
    });
    return { items, total, page, pageSize };
  }

  async findOne(id: string): Promise<Project> {
    const project = await this.projectRepository.findOne({
      where: { id },
      relations: ['tasks', 'owner', 'acceptor'],
    });
    if (!project) throw new NotFoundException('项目不存在');
    return project;
  }

  async update(id: string, dto: CreateProjectDto): Promise<Project> {
    const project = await this.findOne(id);
    Object.assign(project, dto);
    return this.projectRepository.save(project);
  }

  async remove(id: string): Promise<void> {
    const project = await this.findOne(id);
    await this.projectRepository.remove(project);
  }

  async findTasks(projectId: string, page = 1, pageSize = 10) {
    const [items, total] = await this.taskRepository.findAndCount({
      where: { projectId },
      skip: (+page - 1) * +pageSize,
      take: +pageSize,
      order: { createdAt: 'DESC' },
    });
    return { items, total, page: +page, pageSize: +pageSize };
  }

  async batchTasks(projectId: string, dto: { action: string; ids: string[]; status?: string }) {
    const tasks = await this.taskRepository.find({
      where: { id: In(dto.ids), projectId },
    });
    if (!tasks.length) throw new NotFoundException('未找到匹配的任务');

    if (dto.action === 'delete') {
      await this.taskRepository.remove(tasks);
      return { deleted: tasks.length };
    }

    if (dto.action === 'updateStatus' && dto.status) {
      await this.taskRepository.update(
        { id: In(dto.ids), projectId },
        { status: dto.status as any },
      );
      return { updated: tasks.length, status: dto.status };
    }

    throw new BadRequestException('无效的操作');
  }
}
