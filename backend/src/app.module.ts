import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule, TypeOrmModuleOptions } from '@nestjs/typeorm';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { VehiclesModule } from './vehicles/vehicles.module';
import { SalesModule } from './sales/sales.module';
import { PaymentsModule } from './payments/payments.module';
import { CommissionsModule } from './commissions/commissions.module';
import { ReportsModule } from './reports/reports.module';
import { LogisticsModule } from './logistics/logistics.module';
import { AuditModule } from './audit/audit.module';
import { StatementsModule } from './statements/statements.module';
import { NotificationsModule } from './notifications/notifications.module';
import { BillingModule } from './billing/billing.module';
import { HandDeliveryModule } from './hand-delivery/hand-delivery.module';
import { BillingProductsModule } from './billing-products/billing-products.module';
import { ShippingModule } from './shipping/shipping.module';

import { buildTypeOrmOptions } from './database/typeorm-options';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService): TypeOrmModuleOptions =>
        buildTypeOrmOptions((key) => config.get<string>(key) || undefined),
    }),
    AuthModule,
    UsersModule,
    VehiclesModule,
    SalesModule,
    PaymentsModule,
    CommissionsModule,
    ReportsModule,
    LogisticsModule,
    AuditModule,
    StatementsModule,
    NotificationsModule,
    BillingModule,
    HandDeliveryModule,
    BillingProductsModule,
    ShippingModule,
  ],
})
export class AppModule {}
