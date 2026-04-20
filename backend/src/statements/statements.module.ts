import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { StatementsService } from './statements.service';
import { StatementsController } from './statements.controller';
import { VehicleEntry } from '../vehicles/entities/vehicle-entry.entity';
import { Sale } from '../sales/entities/sale.entity';
import { Payment } from '../payments/entities/payment.entity';
import { Commission } from '../commissions/entities/commission.entity';

@Module({
  imports: [TypeOrmModule.forFeature([VehicleEntry, Sale, Payment, Commission])],
  providers: [StatementsService],
  controllers: [StatementsController],
})
export class StatementsModule {}
