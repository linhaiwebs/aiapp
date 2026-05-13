import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ProjectDocument } from '../../entities/project-document.entity';
import { ProjectDocumentService } from './project-document.service';
import { ProjectDocumentController } from './project-document.controller';

@Module({
  imports: [TypeOrmModule.forFeature([ProjectDocument])],
  controllers: [ProjectDocumentController],
  providers: [ProjectDocumentService],
  exports: [ProjectDocumentService],
})
export class ProjectDocumentModule {}
