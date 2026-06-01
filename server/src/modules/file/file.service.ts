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
  private ossClient: any;
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
    } else if (this.storageType === 'oss') {
      this.initOss();
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

  private async initOss() {
    try {
      const OSS = await import('ali-oss');
      // ali-oss v6 exports as CommonJS module.exports = Client
      // Dynamic import can produce either OSS.default or OSS depending on Node.js version
      const OSSClient = (OSS as any).default || OSS;
      this.bucket = this.configService.get<string>('storage.ossBucket') ?? 'xcai';
      this.ossClient = new OSSClient({
        region: this.configService.get<string>('storage.ossRegion') ?? 'oss-cn-hangzhou',
        accessKeyId: this.configService.get<string>('storage.ossAccessKeyId') ?? '',
        accessKeySecret: this.configService.get<string>('storage.ossAccessKeySecret') ?? '',
        bucket: this.bucket,
        endpoint: this.configService.get<string>('storage.ossEndpoint') || undefined,
        secure: this.configService.get<boolean>('storage.ossSecure') ?? true,
      });
      console.log(`[OSS] Connected to bucket ${this.bucket}`);
    } catch (err) {
      console.error('OSS init failed, falling back to local storage:', err.message);
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

  async initUpload(userId: string, dto: InitUploadDto): Promise<FileEntity & { presignedUrl?: string }> {
    const storedName = `${uuidv4()}_${dto.originalName}`;
    let fileUrl: string;
    let presignedUrl: string | undefined;

    if (this.storageType === 'oss') {
      fileUrl = `${this.bucket}/${storedName}`;
      // 生成 OSS 预签名上传 URL（PUT 方法，5分钟有效）
      presignedUrl = await this.getPresignedPutUrl(storedName, dto.mimeType);
    } else if (this.storageType === 'minio') {
      fileUrl = `${this.bucket}/${storedName}`;
    } else {
      fileUrl = `${this.localPath}/${storedName}`;
    }

    const file = this.fileRepository.create({
      userId,
      taskId: dto.taskId,
      originalName: dto.originalName,
      storedName,
      fileUrl,
      fileSize: dto.fileSize,
      mimeType: dto.mimeType,
      taskType: dto.taskType,
      status: FileStatus.UPLOADING,
      uploadInfo: {
        totalChunks: dto.totalChunks,
        uploadedChunks: [],
        presignedUrl,
      },
    });

    const saved = await this.fileRepository.save(file);
    return { ...saved, presignedUrl };
  }

  /** 生成 OSS 预签名 PUT URL（APP 直传用） */
  async getPresignedPutUrl(objectKey: string, mimeType?: string): Promise<string> {
    if (this.storageType !== 'oss' || !this.ossClient) {
      throw new BadRequestException('当前存储模式不支持直传');
    }
    const url = this.ossClient.signatureUrl(objectKey, {
      method: 'PUT',
      'Content-Type': mimeType || 'application/octet-stream',
      expires: 300, // 5分钟
    });
    return url;
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

    const totalChunks = file.uploadInfo?.totalChunks ?? 0;

    if (this.storageType === 'oss') {
      // 文件由服务端中转上传到 OSS
      if (totalChunks > 1) {
        throw new BadRequestException('OSS 模式暂不支持多分片，请使用单分片上传');
      }
      await this.ossClient.put(file.storedName, chunkBuffer);
    } else if (this.storageType === 'minio') {
      const objectName = totalChunks <= 1
        ? file.storedName
        : `${file.storedName}.part.${chunkIndex}`;
      await this.minioClient.putObject(this.bucket, objectName, chunkBuffer);
    } else {
      const chunksDir = path.join(this.localPath, '.chunks', fileId);
      if (!fs.existsSync(chunksDir)) {
        fs.mkdirSync(chunksDir, { recursive: true });
      }
      fs.writeFileSync(path.join(chunksDir, `${chunkIndex}`), chunkBuffer);
    }

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

    if (totalChunks > 0) {
      if (this.storageType === 'oss') {
        // OSS: 验证文件是否已通过直传到达
        try {
          await this.ossClient.head(file.storedName);
        } catch {
          throw new BadRequestException('OSS 文件未找到，请确认上传已完成');
        }
      } else if (this.storageType === 'minio') {
        if (totalChunks > 1) {
          const sources = [];
          for (let i = 0; i < totalChunks; i++) {
            sources.push({ Bucket: this.bucket, Object: `${file.storedName}.part.${i}` });
          }
          try {
            await this.minioClient.composeObject(
              { Bucket: this.bucket, Object: file.storedName },
              sources,
            );
          } catch (err: any) {
            console.error(`MinIO compose failed for ${file.storedName}:`, err.message);
            throw new BadRequestException(`MinIO 文件合并失败: ${err.message}`);
          }
          for (let i = 0; i < totalChunks; i++) {
            try {
              await this.minioClient.removeObject(this.bucket, `${file.storedName}.part.${i}`);
            } catch { /* ignore */ }
          }
        }
      } else {
        // Local: concatenate chunks
        const chunksDir = path.join(this.localPath, '.chunks', dto.fileId);
        const finalPath = path.join(this.localPath, file.storedName);
        const finalDir = path.dirname(finalPath);
        if (!fs.existsSync(finalDir)) {
          fs.mkdirSync(finalDir, { recursive: true });
        }
        await new Promise<void>((resolve, reject) => {
          const writeStream = fs.createWriteStream(finalPath);
          writeStream.on('error', reject);
          writeStream.on('finish', resolve);
          for (let i = 0; i < totalChunks; i++) {
            const chunkPath = path.join(chunksDir, `${i}`);
            if (fs.existsSync(chunkPath)) {
              writeStream.write(fs.readFileSync(chunkPath));
            }
          }
          writeStream.end();
        }).catch((err) => {
          try { fs.unlinkSync(finalPath); } catch {}
          throw new BadRequestException(`文件写入失败: ${err.message}`);
        });
        fs.rmSync(chunksDir, { recursive: true, force: true });
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

    if (this.storageType === 'oss') {
      return this.ossPresignedGetUrl(file.storedName);
    }

    if (this.storageType === 'minio') {
      try {
        return await this.minioClient.presignedGetObject(this.bucket, file.storedName, 60 * 60);
      } catch {
        return file.fileUrl;
      }
    }

    return `/storage/${file.storedName}`;
  }

  /** OSS 预签名 GET URL（播放/下载用，1小时有效） */
  private ossPresignedGetUrl(objectKey: string): string {
    const cdnDomain = this.configService.get<string>('storage.ossCdnDomain') || '';
    if (cdnDomain) {
      return `https://${cdnDomain}/${objectKey}`;
    }
    return this.ossClient.signatureUrl(objectKey, {
      expires: 3600,
    });
  }

  /** 获取文件流（支持 Range），OSS 改为代理下载避免 CORS */
  async getFileStream(
    id: string,
    range?: { start: number; end: number },
  ): Promise<{
    stream?: fs.ReadStream;
    mimeType: string;
    fileSize: number;
    fileName: string;
  }> {
    const file = await this.findOne(id);

    if (this.storageType === 'oss') {
      try {
        const result = await this.ossClient.get(file.storedName);
        const buffer = Buffer.from(result.content as ArrayBuffer);
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
        throw new NotFoundException('OSS 文件获取失败');
      }
    }

    if (this.storageType === 'minio') {
      try {
        const buffer = await this.minioClient.getObject(this.bucket, file.storedName);
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

    if (this.storageType === 'oss') {
      try {
        await this.ossClient.delete(file.storedName);
      } catch { /* ignore */ }
    } else if (this.storageType === 'minio') {
      try {
        await this.minioClient.removeObject(this.bucket, file.storedName);
      } catch { /* ignore */ }
    } else {
      const filePath = path.join(this.localPath, file.storedName);
      try {
        if (fs.existsSync(filePath)) {
          fs.unlinkSync(filePath);
        }
      } catch { /* ignore */ }
    }

    await this.fileRepository.remove(file);
  }
}
