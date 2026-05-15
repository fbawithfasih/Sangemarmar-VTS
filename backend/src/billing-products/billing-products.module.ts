import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BillingProduct } from './entities/billing-product.entity';
import { BillingProductsService } from './billing-products.service';
import { BillingProductsController } from './billing-products.controller';

@Module({
  imports: [TypeOrmModule.forFeature([BillingProduct])],
  providers: [BillingProductsService],
  controllers: [BillingProductsController],
})
export class BillingProductsModule {}
