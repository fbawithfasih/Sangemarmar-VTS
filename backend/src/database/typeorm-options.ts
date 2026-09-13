import { join } from 'path';
import { DataSourceOptions } from 'typeorm';
import { User } from '../users/entities/user.entity';
import { VehicleEntry } from '../vehicles/entities/vehicle-entry.entity';
import { Sale } from '../sales/entities/sale.entity';
import { Payment } from '../payments/entities/payment.entity';
import { Commission } from '../commissions/entities/commission.entity';
import { CommissionConfig } from '../commissions/entities/commission-config.entity';
import { LogisticsEvent } from '../logistics/entities/logistics-event.entity';
import { AuditLog } from '../audit/entities/audit-log.entity';
import { Notification } from '../notifications/entities/notification.entity';
import { BillingOrder } from '../billing/entities/billing-order.entity';
import { BillingItem } from '../billing/entities/billing-item.entity';
import { HandDeliveryOrder } from '../hand-delivery/entities/hand-delivery-order.entity';
import { HandDeliveryItem } from '../hand-delivery/entities/hand-delivery-item.entity';
import { BillingProduct } from '../billing-products/entities/billing-product.entity';
import { Shipment } from '../shipping/entities/shipment.entity';

export const ENTITIES = [
  User, VehicleEntry, Sale, Payment, Commission, CommissionConfig, LogisticsEvent, AuditLog,
  Notification, BillingOrder, BillingItem, HandDeliveryOrder, HandDeliveryItem, BillingProduct, Shipment,
];

// Compiled builds load dist/migrations/*.js; the CLI under ts-node loads
// src/migrations/*.ts. Matching only one extension avoids picking up .d.ts files.
const MIGRATIONS_GLOB = join(__dirname, '..', 'migrations', __filename.endsWith('.ts') ? '*.ts' : '*.js');

// Shared by the Nest app (app.module.ts) and the TypeORM CLI (data-source.ts).
// Schema changes are applied only through migrations: never enable synchronize,
// it drops and recreates columns on the live database when entities change.
export function buildTypeOrmOptions(get: (key: string) => string | undefined): DataSourceOptions {
  const base = {
    type: 'postgres' as const,
    entities: ENTITIES,
    migrations: [MIGRATIONS_GLOB],
    synchronize: false,
    migrationsRun: true,
    logging: get('NODE_ENV') === 'development',
  };

  const databaseUrl = get('DATABASE_URL');
  if (databaseUrl) {
    return { ...base, url: databaseUrl, ssl: { rejectUnauthorized: false } };
  }
  return {
    ...base,
    host: get('DB_HOST') ?? 'localhost',
    port: parseInt(get('DB_PORT') ?? '5432', 10),
    username: get('DB_USERNAME') ?? 'postgres',
    password: get('DB_PASSWORD') ?? 'postgres',
    database: get('DB_NAME') ?? 'sangemarmar_vts',
  };
}
