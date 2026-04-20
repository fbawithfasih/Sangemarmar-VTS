import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
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

// Entities
import { User } from './users/entities/user.entity';
import { VehicleEntry } from './vehicles/entities/vehicle-entry.entity';
import { Sale } from './sales/entities/sale.entity';
import { Payment } from './payments/entities/payment.entity';
import { Commission } from './commissions/entities/commission.entity';
import { CommissionConfig } from './commissions/entities/commission-config.entity';
import { LogisticsEvent } from './logistics/entities/logistics-event.entity';
import { AuditLog } from './audit/entities/audit-log.entity';
import { Notification } from './notifications/entities/notification.entity';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => {
        const databaseUrl = config.get('DATABASE_URL');
        return {
          type: 'postgres',
          ...(databaseUrl
            ? { url: databaseUrl, ssl: { rejectUnauthorized: false } }
            : {
                host: config.get('DB_HOST', 'localhost'),
                port: config.get<number>('DB_PORT', 5432),
                username: config.get('DB_USERNAME', 'postgres'),
                password: config.get('DB_PASSWORD', 'postgres'),
                database: config.get('DB_NAME', 'sangemarmar_vts'),
              }),
          entities: [User, VehicleEntry, Sale, Payment, Commission, CommissionConfig, LogisticsEvent, AuditLog, Notification],
          synchronize: true,
          logging: config.get('NODE_ENV') === 'development',
        };
      },
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
  ],
})
export class AppModule {}
