import { Injectable, ForbiddenException, NotFoundException, BadRequestException, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Commission } from './entities/commission.entity';
import { CommissionConfig } from './entities/commission-config.entity';
import { OverrideCommissionDto } from './dto/override-commission.dto';
import { UpdateCommissionConfigDto } from './dto/update-commission-config.dto';
import { AuditService } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { NotificationType } from '../notifications/entities/notification.entity';
import { AuditAction, CommissionRecipientType, UserRole } from '../common/enums';
import { Sale } from '../sales/entities/sale.entity';
import { VehicleEntry } from '../vehicles/entities/vehicle-entry.entity';
import { User } from '../users/entities/user.entity';

const DEFAULT_RATES: Record<CommissionRecipientType, number> = {
  [CommissionRecipientType.DRIVER]: 2,
  [CommissionRecipientType.GUIDE]: 1.5,
  [CommissionRecipientType.LOCAL_AGENT]: 1,
  [CommissionRecipientType.COMPANY]: 3,
};

@Injectable()
export class CommissionsService implements OnModuleInit {
  constructor(
    @InjectRepository(Commission)
    private readonly repo: Repository<Commission>,
    @InjectRepository(CommissionConfig)
    private readonly configRepo: Repository<CommissionConfig>,
    private readonly auditService: AuditService,
    private readonly notificationsService: NotificationsService,
  ) {}

  async onModuleInit() {
    // Seed default rates if none exist yet
    for (const [type, rate] of Object.entries(DEFAULT_RATES)) {
      const existing = await this.configRepo.findOne({
        where: { recipientType: type as CommissionRecipientType },
      });
      if (!existing) {
        await this.configRepo.save(
          this.configRepo.create({ recipientType: type as CommissionRecipientType, rate }),
        );
      }
    }
  }

  async getConfigs(): Promise<CommissionConfig[]> {
    return this.configRepo.find({ relations: ['updatedBy'] });
  }

  async updateConfigs(dto: UpdateCommissionConfigDto, user: User): Promise<CommissionConfig[]> {
    if (![UserRole.ADMIN, UserRole.MANAGER].includes(user.role)) {
      throw new ForbiddenException('Only managers and admins can update commission rates');
    }

    const oldConfigs = await this.getConfigs();
    const oldValues = Object.fromEntries(oldConfigs.map(c => [c.recipientType, c.rate]));

    for (const item of dto.rates) {
      await this.configRepo.upsert(
        { recipientType: item.recipientType, rate: item.rate, updatedById: user.id },
        { conflictPaths: ['recipientType'] },
      );
    }

    await this.auditService.log({
      action: AuditAction.STATUS_CHANGED,
      entityType: 'CommissionConfig',
      userId: user.id,
      oldValues,
      newValues: Object.fromEntries(dto.rates.map(r => [r.recipientType, r.rate])),
    });

    return this.getConfigs();
  }

  private async getRateFromDb(type: CommissionRecipientType): Promise<number> {
    const config = await this.configRepo.findOne({ where: { recipientType: type } });
    return config ? Number(config.rate) : DEFAULT_RATES[type];
  }

  async calculateForSale(sale: Sale, entry: VehicleEntry): Promise<Commission[]> {
    const existing = await this.repo.find({ where: { saleId: sale.id } });
    if (existing.length > 0) return existing;

    const recipients = [
      { type: CommissionRecipientType.DRIVER, name: entry.driverName },
      { type: CommissionRecipientType.GUIDE, name: entry.guideName },
      { type: CommissionRecipientType.LOCAL_AGENT, name: entry.localAgent },
      { type: CommissionRecipientType.COMPANY, name: entry.companyName },
    ];

    const commissions = recipients.map(({ type, name }) =>
      this.repo.create({
        saleId: sale.id,
        recipientType: type,
        recipientName: name,
        rate: 0,
        calculatedAmount: 0,
        finalAmount: 0,
        isOverridden: false,
      }),
    );

    const saved = await this.repo.save(commissions);

    await this.auditService.log({
      action: AuditAction.COMMISSION_CALCULATED,
      entityType: 'Commission',
      entityId: sale.id,
      newValues: { saleId: sale.id, netSale: sale.netSale },
    });

    return saved;
  }

  async findBySale(saleId: string): Promise<Commission[]> {
    return this.repo.find({ where: { saleId }, relations: ['overriddenBy'] });
  }

  async override(id: string, dto: OverrideCommissionDto, user: User): Promise<Commission> {
    if (![UserRole.ADMIN, UserRole.MANAGER].includes(user.role)) {
      throw new ForbiddenException('Only managers and admins can override commissions');
    }

    const commission = await this.repo.findOne({ where: { id } });
    if (!commission) throw new NotFoundException('Commission not found');

    const old = { finalAmount: commission.finalAmount, isOverridden: commission.isOverridden };

    await this.repo.update(id, {
      ...(dto.rate !== undefined && { rate: dto.rate }),
      finalAmount: dto.finalAmount,
      isOverridden: true,
      overrideReason: dto.overrideReason,
      overriddenById: user.id,
      overriddenAt: new Date(),
    });

    await this.auditService.log({
      action: AuditAction.COMMISSION_OVERRIDDEN,
      entityType: 'Commission',
      entityId: id,
      userId: user.id,
      oldValues: old,
      newValues: { finalAmount: dto.finalAmount, overrideReason: dto.overrideReason ?? null },
    });

    if (user.role !== UserRole.ADMIN) {
      await this.notificationsService.create({
        type: NotificationType.COMMISSION,
        message: `✏️ Commission adjusted\n${commission.recipientType}: ${commission.recipientName} → ${dto.rate ?? commission.rate}% (₹${dto.finalAmount.toLocaleString('en-IN')})\nBy: ${user.name} (${user.role})`,
        entityId: id,
        actorId: user.id,
        actorName: user.name,
      });
    }

    return this.repo.findOne({ where: { id }, relations: ['overriddenBy'] });
  }

  async findAll(filters?: { saleId?: string; recipientType?: CommissionRecipientType }) {
    const where: any = {};
    if (filters?.saleId) where.saleId = filters.saleId;
    if (filters?.recipientType) where.recipientType = filters.recipientType;
    return this.repo.find({ where, order: { createdAt: 'DESC' }, relations: ['sale', 'overriddenBy'] });
  }

  async recordPayment(id: string, dto: { paidAmount: number; paidAt: string }): Promise<Commission> {
    const commission = await this.repo.findOne({ where: { id } });
    if (!commission) throw new NotFoundException('Commission not found');

    const cap = Number(commission.finalAmount);
    if (dto.paidAmount > cap) {
      throw new BadRequestException(
        `Paid amount (₹${dto.paidAmount}) exceeds commission amount (₹${cap.toFixed(2)})`,
      );
    }

    await this.repo.update(id, {
      paidAmount: dto.paidAmount,
      paidAt: new Date(dto.paidAt),
    });

    return this.repo.findOne({ where: { id } });
  }
}
