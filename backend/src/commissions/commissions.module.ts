import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Commission } from './entities/commission.entity';
import { CommissionConfig } from './entities/commission-config.entity';
import { CommissionsService } from './commissions.service';
import { CommissionsController } from './commissions.controller';
import { AuditModule } from '../audit/audit.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [TypeOrmModule.forFeature([Commission, CommissionConfig]), AuditModule, NotificationsModule],
  providers: [CommissionsService],
  controllers: [CommissionsController],
  exports: [CommissionsService],
})
export class CommissionsModule {}
