import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { v4 as uuidv4 } from 'uuid';
import * as fs from 'fs';
import * as path from 'path';
import { FileEntity, FileStatus } from '../../entities';
import { InitUploadDto, CompleteUploadDto } from './dto';

@Injectable()
export class FileService {
  private storageType: string;
  private localPath: string;
  private minioClient: any;
  private bucket: string;

  constructor(
    @InjectRepository(FileEntity)
    private fileRepository: Repository<FileEntity>,
    private configService: ConfigService,
  ) {
    this.storageType = this.configService.get<string>('storage.type') ?? 'local';
    this.localPath = this.configService.get<string>('storage.localPath') ?? 'data/uploads';

    if (this.storageType === 'minio') {
      this.initMinio();
    } else {
      this.ensureLocalDir();
    }
  }

  private ensureLocalDir() {
    if (!fs.existsSync(this.localPath)) {
      fs.mkdirSync(this.localPath, { recursive: true });
    }
  }

  private async initMinio() {
    try {
      const Minio = await import('minio');
      this.minioClient = new Minio.Client({
        endPoint: this.configService.get<string>('storage.endPoint') ?? 'localhost',
        port: this.configService.get<number>('storage.port') ?? 9000,
        accessKey: this.configService.get<string>('storage.accessKey') ?? 'minioadmin',
        secretKey: this.configService.get<string>('storage.secretKey') ?? 'minioadmin',
        useSSL: this.configService.get<boolean>('storage.useSSL') ?? false,
      });
      this.bucket = this.configService.get<string>('storage.bucket') ?? 'xcai';
      this.ensureMinioBucket();
    } catch (err) {
      console.error('MinIO init failed, falling back to local storage:', err.message);
      this.storageType = 'local';
      this.ensureLocalDir();
    }
  }

  private async ensureMinioBucket() {
    try {
      const exists = await this.minioClient.bucketExists(this.bucket);
      if (!exists) {
        await this.minioClient.makeBucket(this.bucket);
      }
    } catch (err) {
      console.error('MinIO bucket initialization failed:', err.message);
    }
  }

  async initUpload(userId: string, dto: InitUploadDto): Promise<FileEntity> {
    const storedName = `${uuidv4()}_${dto.originalName}`;
    const file = this.fileRepository.create({
      userId,
      taskId: dto.taskId,
      originalName: dto.originalName,
      storedName,
      fileUrl: this.storageType === 'minio'
        ? `${this.bucket}/${storedName}`
        : `${this.localPath}/${storedName}`,
      fileSize: dto.fileSize,
      mimeType: dto.mimeType,
      taskType: dto.taskType,
      status: FileStatus.UPLOADING,
      uploadInfo: {
        totalChunks: dto.totalChunks,
        uploadedChunks: [],
      },
    });

    return this.fileRepository.save(file);
  }

  async uploadChunk(
    fileId: string,
    chunkIndex: number,
    chunkBuffer: Buffer,
  ): Promise<FileEntity> {
    const file = await this.fileRepository.findOne({ where: { id: fileId } });
    if (!file) throw new NotFoundException('文件不存在');
    if (file.status !== FileStatus.UPLOADING) {
      throw new BadRequestException('文件不在上传状态');
    }

    if (this.storageType === 'minio') {
      const chunkName = `${file.storedName}.part.${chunkIndex}`;
      await this.minioClient.putObject(this.bucket, chunkName, chunkBuffer);
    } else {
      // Local: write chunk to temp file
      const chunksDir = path.join(this.localPath, '.chunks', fileId);
      if (!fs.existsSync(chunksDir)) {
        fs.mkdirSync(chunksDir, { recursive: true });
      }
      fs.writeFileSync(path.join(chunksDir, `${chunkIndex}`), chunkBuffer);
    }

    // Track uploaded chunks
    const uploadInfo = file.uploadInfo || {};
    const uploadedChunks = uploadInfo.uploadedChunks || [];
    if (!uploadedChunks.includes(chunkIndex)) {
      uploadedChunks.push(chunkIndex);
    }
    uploadInfo.uploadedChunks = uploadedChunks;
    file.uploadInfo = uploadInfo;

    return this.fileRepository.save(file);
  }

  async completeUpload(dto: CompleteUploadDto): Promise<FileEntity> {
    const file = await this.fileRepository.findOne({ where: { id: dto.fileId } });
    if (!file) throw new NotFoundException('文件不存在');

    const uploadInfo = file.uploadInfo || {};
    const totalChunks = uploadInfo.totalChunks || 0;
    const uploadedChunks: number[] = uploadInfo.uploadedChunks || [];

    if (uploadedChunks.length !== totalChunks) {
      throw new BadRequestException(
        `分片未全部上传，期望${totalChunks}片，已上传${uploadedChunks.length}片`,
      );
    }

    if (this.storageType === 'local' && totalChunks > 0) {
      // Concatenate chunks into final file
      const chunksDir = path.join(this.localPath, '.chunks', dto.fileId);
      const finalPath = path.join(this.localPath, file.storedName);
      const writeStream = fs.createWriteStream(finalPath);

      for (let i = 0; i < totalChunks; i++) {
        const chunkPath = path.join(chunksDir, `${i}`);
        if (fs.existsSync(chunkPath)) {
          const data = fs.readFileSync(chunkPath);
          writeStream.write(data);
        }
      }
      writeStream.end();

      // Clean up chunks
      try {
        fs.rmSync(chunksDir, { recursive: true, force: true });
      } catch {
        // ignore cleanup errors
      }
    }

    file.status = FileStatus.COMPLETED;
    file.uploadInfo = { ...uploadInfo, completedAt: new Date().toISOString() };

    return this.fileRepository.save(file);
  }

  async findOne(id: string): Promise<FileEntity> {
    const file = await this.fileRepository.findOne({ where: { id } });
    if (!file) throw new NotFoundException('文件不存在');
    return file;
  }

  async getDownloadUrl(id: string): Promise<string> {
    const file = await this.findOne(id);

    if (this.storageType === 'minio') {
      try {
        return await this.minioClient.presignedGetObject(
          this.bucket,
          file.storedName,
          60 * 60,
        );
      } catch {
        return file.fileUrl;
      }
    }

    // Local: return relative path for serving via static middleware
    return `/storage/${file.storedName}`;
  }

  /** 获取文件流（支持 Range 请求） */
  async getFileStream(
    id: string,
    range?: { start: number; end: number },
  ): Promise<{
    stream: fs.ReadStream;
    mimeType: string;
    fileSize: number;
    fileName: string;
  }> {
    const file = await this.findOne(id);

    if (this.storageType === 'minio') {
      try {
        const buffer = await this.minioClient.getObject(this.bucket, file.storedName);
        // Write to temp file for streaming
        const tmpDir = path.join(this.localPath, '.tmp');
        if (!fs.existsSync(tmpDir)) {
          fs.mkdirSync(tmpDir, { recursive: true });
        }
        const tmpPath = path.join(tmpDir, file.storedName);
        fs.writeFileSync(tmpPath, buffer);
        return {
          stream: fs.createReadStream(tmpPath, range ? { start: range.start, end: range.end } : undefined),
          mimeType: file.mimeType || 'application/octet-stream',
          fileSize: buffer.length,
          fileName: file.originalName,
        };
      } catch {
        throw new NotFoundException('文件获取失败');
      }
    }

    const filePath = path.join(this.localPath, file.storedName);
    if (!fs.existsSync(filePath)) {
      throw new NotFoundException('文件不存在');
    }

    const stat = fs.statSync(filePath);
    return {
      stream: fs.createReadStream(filePath, range ? { start: range.start, end: range.end } : undefined),
      mimeType: file.mimeType || 'application/octet-stream',
      fileSize: stat.size,
      fileName: file.originalName,
    };
  }

  async remove(id: string, userId: string): Promise<void> {
    const file = await this.findOne(id);
    if (file.userId !== userId) {
      throw new BadRequestException('无权删除此文件');
    }

    if (this.storageType === 'minio') {
      try {
        await this.minioClient.removeObject(this.bucket, file.storedName);
      } catch {
        // Ignore removal errors
      }
    } else {
      const filePath = path.join(this.localPath, file.storedName);
      try {
        if (fs.existsSync(filePath)) {
          fs.unlinkSync(filePath);
        }
      } catch {
        // Ignore removal errors
      }
    }

    await this.fileRepository.remove(file);
  }
}
