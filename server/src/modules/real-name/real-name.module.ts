import { Module } from '@nestjs/common';
import { RealNameService } from './real-name.service';
import { RealNameController } from './real-name.controller';

@Module({
  controllers: [RealNameController],
  providers: [RealNameService],
  exports: [RealNameService],
})
export class RealNameModule {}
