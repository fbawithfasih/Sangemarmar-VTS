import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, Repository } from 'typeorm';
import { Payment } from './entities/payment.entity';
import { Commission } from '../commissions/entities/commission.entity';
import { CreatePaymentDto } from './dto/create-payment.dto';
import { AuditService } from '../audit/audit.service';
import { SalesService } from '../sales/sales.service';
import { VehiclesService } from '../vehicles/vehicles.service';
import { AuditAction, UserRole, WorkflowStatus } from '../common/enums';
import { NotificationsService } from '../notifications/notifications.service';
import { NotificationType } from '../notifications/entities/notification.entity';
import { User } from '../users/entities/user.entity';

@Injectable()
export class PaymentsService {
  constructor(
    @InjectRepository(Payment)
    private readonly repo: Repository<Payment>,
    @InjectRepository(Commission)
    private readonly commissionRepo: Repository<Commission>,
    private readonly auditService: AuditService,
    private readonly salesService: SalesService,
    private readonly vehiclesService: VehiclesService,
    private readonly notificationsService: NotificationsService,
  ) {}

  async create(dto: CreatePaymentDto, user: User): Promise<Payment> {
    const sale = await this.salesService.findOne(dto.saleId);
    if (!sale) throw new NotFoundException('Sale not found');

    const payment = this.repo.create({ ...dto, createdById: user.id });
    const saved = await this.repo.save(payment);

    const commissions = await this.commissionRepo.find({ where: { saleId: dto.saleId } });
    const nextStatus = commissions.length > 0
      ? WorkflowStatus.COMPLETED
      : WorkflowStatus.PAYMENT_COMPLETE;

    await this.vehiclesService.updateStatus(sale.vehicleEntryId, nextStatus, user.id);

    await this.auditService.log({
      action: AuditAction.PAYMENT_CREATED,
      entityType: 'Payment',
      entityId: saved.id,
      userId: user.id,
      newValues: { saleId: dto.saleId, mode: dto.mode, amount: dto.amount },
    });

    if (user.role !== UserRole.ADMIN) {
      const vehicle = sale.vehicleEntry;
      await this.notificationsService.create({
        type: NotificationType.PAYMENT,
        message: `💳 Payment received\nAmount: ₹${Number(dto.amount).toLocaleString('en-IN')} via ${dto.mode}${vehicle ? ` | Vehicle: ${vehicle.vehicleNumber}` : ''}\nBy: ${user.name} (${user.role})`,
        entityId: saved.id,
        actorId: user.id,
        actorName: user.name,
      });
    }

    return saved;
  }

  async findBySale(saleId: string): Promise<{ payments: Payment[]; total: number }> {
    const payments = await this.repo.find({
      where: { saleId },
      order: { createdAt: 'ASC' },
      relations: ['createdBy'],
    });
    const total = payments.reduce((sum, p) => sum + Number(p.amount), 0);
    return { payments, total };
  }

  async findAll(filters?: {
    saleId?: string;
    mode?: string;
    dateFrom?: string;
    dateTo?: string;
  }) {
    const where: any = {};
    if (filters?.saleId) where.saleId = filters.saleId;
    if (filters?.mode) where.mode = filters.mode;
    if (filters?.dateFrom && filters?.dateTo) {
      where.paymentDate = Between(new Date(filters.dateFrom), new Date(filters.dateTo));
    }

    return this.repo.find({
      where,
      order: { createdAt: 'DESC' },
      relations: ['sale', 'createdBy'],
    });
  }
}
