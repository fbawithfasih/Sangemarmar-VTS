import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Sale } from './entities/sale.entity';
import { SalesService } from './sales.service';
import { SalesController } from './sales.controller';
import { AuditModule } from '../audit/audit.module';
import { VehiclesModule } from '../vehicles/vehicles.module';
import { LogisticsModule } from '../logistics/logistics.module';
import { CommissionsModule } from '../commissions/commissions.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Sale]),
    AuditModule,
    VehiclesModule,
    LogisticsModule,
    CommissionsModule,
    NotificationsModule,
  ],
  providers: [SalesService],
  controllers: [SalesController],
  exports: [SalesService],
})
export class SalesModule {}
