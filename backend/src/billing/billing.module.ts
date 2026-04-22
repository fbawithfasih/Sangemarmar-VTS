import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BillingOrder } from './entities/billing-order.entity';
import { BillingItem } from './entities/billing-item.entity';
import { BillingService } from './billing.service';
import { BillingController } from './billing.controller';
import { AuditModule } from '../audit/audit.module';
import { VehiclesModule } from '../vehicles/vehicles.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([BillingOrder, BillingItem]),
    AuditModule,
    VehiclesModule,
  ],
  providers: [BillingService],
  controllers: [BillingController],
})
export class BillingModule {}
