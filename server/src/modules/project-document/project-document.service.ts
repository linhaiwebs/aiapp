import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ProjectDocument } from '../../entities/project-document.entity';
import { CreateProjectDocumentDto, BatchCreateProjectDocumentDto } from './dto';

@Injectable()
export class ProjectDocumentService {
  constructor(
    @InjectRepository(ProjectDocument)
    private docRepository: Repository<ProjectDocument>,
  ) {}

  async create(projectId: string, dto: CreateProjectDocumentDto): Promise<ProjectDocument> {
    const doc = this.docRepository.create({ ...dto, projectId });
    return this.docRepository.save(doc);
  }

  async batchCreate(projectId: string, dto: BatchCreateProjectDocumentDto): Promise<{ count: number }> {
    const docs = dto.documents.map((d) => this.docRepository.create({ ...d, projectId }));
    await this.docRepository.save(docs);
    return { count: docs.length };
  }

  async findByProject(projectId: string): Promise<ProjectDocument[]> {
    return this.docRepository.find({
      where: { projectId },
      select: ['id', 'title', 'fileName', 'createdAt', 'updatedAt'],
      order: { createdAt: 'DESC' },
    });
  }

  async findOne(projectId: string, docId: string): Promise<ProjectDocument> {
    const doc = await this.docRepository.findOne({ where: { id: docId, projectId } });
    if (!doc) throw new NotFoundException('文档不存在');
    return doc;
  }

  async remove(projectId: string, docId: string): Promise<void> {
    const doc = await this.findOne(projectId, docId);
    await this.docRepository.remove(doc);
  }
}
