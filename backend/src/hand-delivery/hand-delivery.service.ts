import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, LessThanOrEqual, MoreThanOrEqual, Repository } from 'typeorm';
import { HandDeliveryOrder } from './entities/hand-delivery-order.entity';
import { HandDeliveryItem } from './entities/hand-delivery-item.entity';
import {
  CreateHandDeliveryDto, UpdateHandDeliveryDto, HandDeliveryFilterDto,
} from './dto/create-hand-delivery.dto';
import { AuditService } from '../audit/audit.service';
import { AuditAction, BillingOrderStatus } from '../common/enums';
import { User } from '../users/entities/user.entity';

function istDayStart(dateStr: string): Date {
  return new Date(`${dateStr}T00:00:00+05:30`);
}
function istDayEnd(dateStr: string): Date {
  return new Date(`${dateStr}T23:59:59.999+05:30`);
}

// Reverse-calculate taxable value and GST amount from an inclusive line total.
// Given amount (inclusive) and rate %, returns { taxable, gst, unitPrice }
// where taxable + gst == amount (to 2dp) and unitPrice = taxable / quantity.
function reverseCalc(amount: number, rate: number, quantity: number) {
  const a = Number(amount) || 0;
  const r = Number(rate) || 0;
  const taxable = +(a / (1 + r / 100)).toFixed(2);
  const gst = +(a - taxable).toFixed(2);
  const qty = quantity > 0 ? quantity : 1;
  const unitPrice = +(taxable / qty).toFixed(2);
  return { taxable, gst, unitPrice };
}

@Injectable()
export class HandDeliveryService {
  constructor(
    @InjectRepository(HandDeliveryOrder) private readonly orderRepo: Repository<HandDeliveryOrder>,
    @InjectRepository(HandDeliveryItem) private readonly itemRepo: Repository<HandDeliveryItem>,
    private readonly auditService: AuditService,
  ) {}

  private async generateInvoiceNumber(): Promise<string> {
    const now = new Date();
    const fyStart = now.getMonth() >= 3 ? now.getFullYear() : now.getFullYear() - 1;
    const fyEnd = fyStart + 1;
    const fyLabel = `${String(fyStart).slice(2)}-${String(fyEnd).slice(2)}`;
    const startOfFy = new Date(fyStart, 3, 1);
    const count = await this.orderRepo.count({ where: { createdAt: MoreThanOrEqual(startOfFy) } });
    return `SKC-HD/${String(count + 1).padStart(3, '0')}/${fyLabel}`;
  }

  async create(dto: CreateHandDeliveryDto, user: User): Promise<HandDeliveryOrder> {
    const invoiceNumber = await this.generateInvoiceNumber();
    const { items, ...orderData } = dto;

    const order = this.orderRepo.create({
      ...orderData,
      invoiceNumber,
      createdById: user.id,
    });
    const saved = await this.orderRepo.save(order);

    const orderItems = items.map((i) => {
      const rate = i.gstRate ?? 5;
      const calc = reverseCalc(i.amountInr, rate, i.quantity);
      return this.itemRepo.create({
        handDeliveryOrderId: saved.id,
        particulars: i.particulars,
        hsnCode: i.hsnCode,
        size: i.size,
        quantity: i.quantity,
        amountInr: i.amountInr,
        gstRate: rate,
        taxableValue: calc.taxable,
        gstAmount: calc.gst,
        priceInr: calc.unitPrice,
      });
    });
    await this.itemRepo.save(orderItems);

    await this.auditService.log({
      action: AuditAction.HAND_DELIVERY_CREATED,
      entityType: 'HandDeliveryOrder',
      entityId: saved.id,
      userId: user.id,
      newValues: { invoiceNumber, buyerName: dto.buyerName } as any,
    });

    return this.findOne(saved.id);
  }

  async findAll(filter: HandDeliveryFilterDto): Promise<HandDeliveryOrder[]> {
    const where: any = {};
    if (filter.dateFrom && filter.dateTo) {
      where.orderDate = Between(istDayStart(filter.dateFrom), istDayEnd(filter.dateTo));
    } else if (filter.dateFrom) {
      where.orderDate = MoreThanOrEqual(istDayStart(filter.dateFrom));
    } else if (filter.dateTo) {
      where.orderDate = LessThanOrEqual(istDayEnd(filter.dateTo));
    }
    return this.orderRepo.find({
      where,
      relations: ['items', 'createdBy'],
      order: { orderDate: 'DESC' },
    });
  }

  async findOne(id: string): Promise<HandDeliveryOrder> {
    const order = await this.orderRepo.findOne({
      where: { id },
      relations: ['items', 'createdBy'],
    });
    if (!order) throw new NotFoundException('Hand delivery order not found');
    return order;
  }

  async update(id: string, dto: UpdateHandDeliveryDto, user: User): Promise<HandDeliveryOrder> {
    const order = await this.findOne(id);
    if (order.status === BillingOrderStatus.CONFIRMED) {
      throw new BadRequestException('Cannot edit a confirmed order');
    }

    const { items, ...orderData } = dto;
    Object.assign(order, orderData);
    await this.orderRepo.save(order);

    if (items && items.length > 0) {
      await this.itemRepo.delete({ handDeliveryOrderId: id });
      const newItems = items.map((i) => {
        const rate = i.gstRate ?? 5;
        const calc = reverseCalc(i.amountInr, rate, i.quantity);
        return this.itemRepo.create({
          handDeliveryOrderId: id,
          particulars: i.particulars,
          hsnCode: i.hsnCode,
          size: i.size,
          quantity: i.quantity,
          amountInr: i.amountInr,
          gstRate: rate,
          taxableValue: calc.taxable,
          gstAmount: calc.gst,
          priceInr: calc.unitPrice,
        });
      });
      await this.itemRepo.save(newItems);
    }

    await this.auditService.log({
      action: AuditAction.HAND_DELIVERY_UPDATED,
      entityType: 'HandDeliveryOrder',
      entityId: id,
      userId: user.id,
      newValues: dto as any,
    });

    return this.findOne(id);
  }

  async delete(id: string, user: User): Promise<void> {
    await this.findOne(id);
    await this.orderRepo.delete(id);
    await this.auditService.log({
      action: AuditAction.HAND_DELIVERY_DELETED,
      entityType: 'HandDeliveryOrder',
      entityId: id,
      userId: user.id,
      newValues: {} as any,
    });
  }
}
