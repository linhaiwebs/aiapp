import { IsString, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateProjectDocumentDto {
  @ApiProperty({ description: '文档标题' })
  @IsString()
  title: string;

  @ApiProperty({ description: '文档内容' })
  @IsString()
  content: string;

  @ApiPropertyOptional({ description: '原始文件名' })
  @IsOptional()
  @IsString()
  fileName?: string;
}

export class BatchCreateProjectDocumentDto {
  @ApiProperty({ description: '文档列表', type: [CreateProjectDocumentDto] })
  documents: CreateProjectDocumentDto[];
}
