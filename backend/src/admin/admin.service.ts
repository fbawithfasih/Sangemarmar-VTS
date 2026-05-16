import { Injectable, UnauthorizedException } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { User } from '../users/entities/user.entity';

/// Tables wiped by reset-operational-data. Order doesn't strictly matter
/// because TRUNCATE ... CASCADE will follow FKs, but listing every operational
/// table explicitly is the documentation here: anything not on this list
/// (users, commission_configs, billing_products) is preserved.
const OPERATIONAL_TABLES = [
  'audit_logs',
  'logistics_events',
  'notifications',
  'shipments',
  'commissions',
  'payments',
  'sales',
  'hand_delivery_items',
  'hand_delivery_orders',
  'billing_items',
  'billing_orders',
  'vehicle_entries',
];

const KEPT_TABLES = ['users', 'commission_configs', 'billing_products'];

@Injectable()
export class AdminService {
  constructor(
    @InjectDataSource() private readonly ds: DataSource,
  ) {}

  /// Verifies the admin's password against the stored bcrypt hash, then
  /// TRUNCATEs every operational table (CASCADE handles FK ordering).
  /// Returns the row count of each table before and after, so the caller
  /// can confirm the wipe actually happened.
  async resetOperationalData(adminUser: User, password: string) {
    const stored = await this.ds.getRepository(User).findOne({
      where: { id: adminUser.id },
      select: ['id', 'password'],
    });
    if (!stored) throw new UnauthorizedException();
    const ok = await bcrypt.compare(password, stored.password);
    if (!ok) throw new UnauthorizedException('Password verification failed');

    const before: Record<string, number> = {};
    for (const t of OPERATIONAL_TABLES) {
      const r = await this.ds.query(`SELECT COUNT(*)::int AS c FROM ${t}`);
      before[t] = Number(r[0].c);
    }
    const keptBefore: Record<string, number> = {};
    for (const t of KEPT_TABLES) {
      const r = await this.ds.query(`SELECT COUNT(*)::int AS c FROM ${t}`);
      keptBefore[t] = Number(r[0].c);
    }

    // Single TRUNCATE so we get one transaction; CASCADE follows FKs even if
    // we missed listing an intermediate operational table.
    await this.ds.query(
      `TRUNCATE ${OPERATIONAL_TABLES.join(', ')} RESTART IDENTITY CASCADE`,
    );

    const after: Record<string, number> = {};
    for (const t of OPERATIONAL_TABLES) {
      const r = await this.ds.query(`SELECT COUNT(*)::int AS c FROM ${t}`);
      after[t] = Number(r[0].c);
    }
    const keptAfter: Record<string, number> = {};
    for (const t of KEPT_TABLES) {
      const r = await this.ds.query(`SELECT COUNT(*)::int AS c FROM ${t}`);
      keptAfter[t] = Number(r[0].c);
    }

    return { operational: { before, after }, kept: { before: keptBefore, after: keptAfter } };
  }
}
