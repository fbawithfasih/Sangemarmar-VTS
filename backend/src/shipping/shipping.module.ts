import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Shipment } from './entities/shipment.entity';
import { ShippingService } from './shipping.service';
import { ShippingController } from './shipping.controller';
import { FedexAdapter } from './adapters/fedex.adapter';
import { DhlAdapter } from './adapters/dhl.adapter';
import { UpsAdapter } from './adapters/ups.adapter';
import { BillingOrder } from '../billing/entities/billing-order.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Shipment, BillingOrder])],
  providers: [ShippingService, FedexAdapter, DhlAdapter, UpsAdapter],
  controllers: [ShippingController],
  exports: [ShippingService],
})
export class ShippingModule {}
