import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
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

  async createFromFile(projectId: string, file: Express.Multer.File): Promise<ProjectDocument> {
    if (!file) throw new BadRequestException('请上传文件');

    const originalName = file.originalname;
    const ext = originalName.split('.').pop()?.toLowerCase();
    const title = originalName.replace(/\.[^.]+$/, '');

    let content: string;

    if (ext === 'txt') {
      // Plain text file - read as UTF-8
      content = file.buffer.toString('utf-8');
    } else if (ext === 'docx') {
      // Word document - try mammoth, fallback to raw text
      try {
        const mammoth = require('mammoth');
        const result = await mammoth.extractRawText({ buffer: file.buffer });
        content = result.value;
      } catch {
        // Fallback: strip binary and try to extract readable text
        content = file.buffer.toString('utf-8').replace(/[^\x20-\x7E一-鿿　-〿＀-￯\n\r]/g, '');
        if (!content.trim()) {
          throw new BadRequestException('无法解析 Word 文档内容，请上传 .txt 格式的文件');
        }
      }
    } else if (ext === 'doc') {
      // Older .doc format - try basic extraction
      content = file.buffer.toString('utf-8').replace(/[^\x20-\x7E一-鿿　-〿＀-￯\n\r]/g, '');
      if (!content.trim()) {
        throw new BadRequestException('不支持旧版 .doc 格式，请另存为 .docx 或 .txt 后重试');
      }
    } else {
      throw new BadRequestException(`不支持的文件格式: .${ext}，请上传 .txt 或 .docx 文件`);
    }

    const doc = this.docRepository.create({
      projectId,
      title,
      content,
      fileName: originalName,
    });
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
