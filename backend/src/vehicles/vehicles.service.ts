import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, ILike, Repository } from 'typeorm';
import { VehicleEntry } from './entities/vehicle-entry.entity';
import { CreateVehicleEntryDto } from './dto/create-vehicle-entry.dto';
import { UpdateVehicleEntryDto } from './dto/update-vehicle-entry.dto';
import { AuditService } from '../audit/audit.service';
import { LogisticsService } from '../logistics/logistics.service';
import { NotificationsService } from '../notifications/notifications.service';
import { NotificationType } from '../notifications/entities/notification.entity';
import { AuditAction, UserRole, WorkflowStatus } from '../common/enums';
import { User } from '../users/entities/user.entity';

@Injectable()
export class VehiclesService {
  constructor(
    @InjectRepository(VehicleEntry)
    private readonly repo: Repository<VehicleEntry>,
    private readonly auditService: AuditService,
    private readonly logisticsService: LogisticsService,
    private readonly notificationsService: NotificationsService,
  ) {}

  async create(dto: CreateVehicleEntryDto, user: User): Promise<VehicleEntry> {
    const entry = this.repo.create({ ...dto, createdById: user.id });
    const saved = await this.repo.save(entry);

    await this.auditService.log({
      action: AuditAction.VEHICLE_ENTRY_CREATED,
      entityType: 'VehicleEntry',
      entityId: saved.id,
      userId: user.id,
      newValues: dto as any,
    });

    await this.logisticsService.addEvent({
      vehicleEntryId: saved.id,
      status: WorkflowStatus.ENTERED,
      notes: 'Vehicle entered at gate',
    }, user.id);

    if (user.role !== UserRole.ADMIN) {
      await this.notificationsService.create({
        type: NotificationType.VEHICLE_ENTRY,
        message: `🚗 New vehicle entry: *${saved.vehicleNumber}*\nDriver: ${saved.driverName} | Company: ${saved.companyName}\nBy: ${user.name} (${user.role})`,
        entityId: saved.id,
        actorId: user.id,
        actorName: user.name,
      });
    }

    return saved;
  }

  async findAll(filters?: {
    vehicleNumber?: string;
    companyName?: string;
    status?: WorkflowStatus;
    dateFrom?: string;
    dateTo?: string;
  }) {
    const where: any = {};
    if (filters?.vehicleNumber) where.vehicleNumber = ILike(`%${filters.vehicleNumber}%`);
    if (filters?.companyName) where.companyName = ILike(`%${filters.companyName}%`);
    if (filters?.status) where.status = filters.status;
    if (filters?.dateFrom && filters?.dateTo) {
      where.entryDate = Between(new Date(filters.dateFrom), new Date(filters.dateTo));
    }

    return this.repo.find({
      where,
      order: { createdAt: 'DESC' },
      relations: ['createdBy'],
    });
  }

  async findOne(id: string): Promise<VehicleEntry> {
    const entry = await this.repo.findOne({
      where: { id },
      relations: ['createdBy'],
    });
    if (!entry) throw new NotFoundException('Vehicle entry not found');
    return entry;
  }

  async update(id: string, dto: UpdateVehicleEntryDto, user: User): Promise<VehicleEntry> {
    if (user.role !== UserRole.ADMIN) throw new ForbiddenException('Only admins can edit vehicle entries');
    const entry = await this.findOne(id);
    const oldValues = { ...entry };
    await this.repo.update(id, dto as any);
    await this.auditService.log({
      action: AuditAction.STATUS_CHANGED,
      entityType: 'VehicleEntry',
      entityId: id,
      userId: user.id,
      oldValues: oldValues as any,
      newValues: dto as any,
    });
    return this.findOne(id);
  }

  async delete(id: string, user: User): Promise<void> {
    if (user.role !== UserRole.ADMIN) throw new ForbiddenException('Only admins can delete vehicle entries');
    await this.findOne(id);
    await this.repo.delete(id);
    await this.auditService.log({
      action: AuditAction.STATUS_CHANGED,
      entityType: 'VehicleEntry',
      entityId: id,
      userId: user.id,
      newValues: { deleted: true },
    });
  }

  async updateStatus(id: string, status: WorkflowStatus, userId: string): Promise<VehicleEntry> {
    const entry = await this.findOne(id);
    const old = entry.status;
    await this.repo.update(id, { status });

    await this.auditService.log({
      action: AuditAction.STATUS_CHANGED,
      entityType: 'VehicleEntry',
      entityId: id,
      userId,
      oldValues: { status: old },
      newValues: { status },
    });

    await this.logisticsService.addEvent({ vehicleEntryId: id, status }, userId);
    return this.findOne(id);
  }
}
