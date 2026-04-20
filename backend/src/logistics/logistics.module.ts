import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LogisticsEvent } from './entities/logistics-event.entity';
import { LogisticsService } from './logistics.service';
import { LogisticsController } from './logistics.controller';

@Module({
  imports: [TypeOrmModule.forFeature([LogisticsEvent])],
  providers: [LogisticsService],
  controllers: [LogisticsController],
  exports: [LogisticsService],
})
export class LogisticsModule {}
