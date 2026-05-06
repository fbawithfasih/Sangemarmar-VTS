import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HandDeliveryOrder } from './entities/hand-delivery-order.entity';
import { HandDeliveryItem } from './entities/hand-delivery-item.entity';
import { HandDeliveryService } from './hand-delivery.service';
import { HandDeliveryController } from './hand-delivery.controller';
import { AuditModule } from '../audit/audit.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([HandDeliveryOrder, HandDeliveryItem]),
    AuditModule,
  ],
  providers: [HandDeliveryService],
  controllers: [HandDeliveryController],
})
export class HandDeliveryModule {}
