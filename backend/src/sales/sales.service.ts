import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, Repository } from 'typeorm';
import { Sale } from './entities/sale.entity';
import { CreateSaleDto } from './dto/create-sale.dto';
import { AuditService } from '../audit/audit.service';
import { VehiclesService } from '../vehicles/vehicles.service';
import { LogisticsService } from '../logistics/logistics.service';
import { CommissionsService } from '../commissions/commissions.service';
import { AuditAction, UserRole, WorkflowStatus } from '../common/enums';
import { NotificationsService } from '../notifications/notifications.service';
import { NotificationType } from '../notifications/entities/notification.entity';
import { User } from '../users/entities/user.entity';

@Injectable()
export class SalesService {
  constructor(
    @InjectRepository(Sale)
    private readonly repo: Repository<Sale>,
    private readonly auditService: AuditService,
    private readonly vehiclesService: VehiclesService,
    private readonly logisticsService: LogisticsService,
    private readonly commissionsService: CommissionsService,
    private readonly notificationsService: NotificationsService,
  ) {}

  async create(dto: CreateSaleDto, user: User): Promise<Sale> {
    const entry = await this.vehiclesService.findOne(dto.vehicleEntryId);
    if (!entry) throw new NotFoundException('Vehicle entry not found');

    const sale = this.repo.create({ ...dto, createdById: user.id });
    const saved = await this.repo.save(sale);

    await this.vehiclesService.updateStatus(
      dto.vehicleEntryId,
      WorkflowStatus.SALES_COMPLETE,
      user.id,
    );

    await this.auditService.log({
      action: AuditAction.SALE_CREATED,
      entityType: 'Sale',
      entityId: saved.id,
      userId: user.id,
      newValues: dto as any,
    });

    await this.commissionsService.calculateForSale(saved, entry);

    if (user.role !== UserRole.ADMIN) {
      await this.notificationsService.create({
        type: NotificationType.SALE,
        message: `💰 New sale created\nVehicle: *${entry.vehicleNumber}* | Net: ₹${Number(saved.netSale).toLocaleString('en-IN')}\nSalesperson: ${saved.salesperson}\nBy: ${user.name} (${user.role})`,
        entityId: saved.id,
        actorId: user.id,
        actorName: user.name,
      });
    }

    return saved;
  }

  async findAll(filters?: {
    vehicleEntryId?: string;
    salesperson?: string;
    dateFrom?: string;
    dateTo?: string;
  }) {
    const where: any = {};
    if (filters?.vehicleEntryId) where.vehicleEntryId = filters.vehicleEntryId;
    if (filters?.salesperson) where.salesperson = filters.salesperson;
    if (filters?.dateFrom && filters?.dateTo) {
      where.saleDate = Between(new Date(filters.dateFrom), new Date(filters.dateTo));
    }

    return this.repo.find({
      where,
      order: { createdAt: 'DESC' },
      relations: ['vehicleEntry', 'createdBy'],
    });
  }

  async findOne(id: string): Promise<Sale> {
    const sale = await this.repo.findOne({
      where: { id },
      relations: ['vehicleEntry', 'createdBy'],
    });
    if (!sale) throw new NotFoundException('Sale not found');
    return sale;
  }

  async update(id: string, updates: Partial<CreateSaleDto>, userId: string): Promise<Sale> {
    const sale = await this.findOne(id);
    const old = { grossSale: sale.grossSale, netSale: sale.netSale };

    await this.repo.update(id, updates as any);

    await this.auditService.log({
      action: AuditAction.SALE_UPDATED,
      entityType: 'Sale',
      entityId: id,
      userId,
      oldValues: old,
      newValues: updates as any,
    });

    return this.findOne(id);
  }
}
