import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TextCollectionController } from './text-collection.controller';
import { TextCollectionService } from './text-collection.service';
import { TextCollection, TextTemplate, Task, TaskClaim, User } from '../../entities';

@Module({
  imports: [TypeOrmModule.forFeature([TextCollection, TextTemplate, Task, TaskClaim, User])],
  controllers: [TextCollectionController],
  providers: [TextCollectionService],
  exports: [TextCollectionService],
})
export class TextCollectionModule {}
