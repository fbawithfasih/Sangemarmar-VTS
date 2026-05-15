import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, LessThanOrEqual, MoreThanOrEqual, Repository } from 'typeorm';
import * as ExcelJS from 'exceljs';
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

  // ── Report export ─────────────────────────────────────────────────────
  // Flat Excel: one row per item, with the columns:
  // Invoice Number | Date | Customer Name | Country | Item Name | Item Size |
  // Item Quantity | Item Price | Item GST | Amount
  //
  // The first column is hidden "Row Key" (orderId|itemId) used by Bulk Edit
  // Upload to safely match rows back to records on round-trip.
  async exportReport(filter: HandDeliveryFilterDto): Promise<Buffer> {
    const orders = await this.findAll(filter);

    const wb = new ExcelJS.Workbook();
    wb.creator = 'Sangemarmar VTS';
    wb.created = new Date();
    const ws = wb.addWorksheet('Hand Delivery Report');

    ws.columns = [
      { header: 'Row Key', key: 'rowKey', width: 78, hidden: true },
      { header: 'Invoice Number', key: 'invoiceNumber', width: 20 },
      { header: 'Date', key: 'date', width: 14 },
      { header: 'Customer Name', key: 'customer', width: 24 },
      { header: 'Country', key: 'country', width: 16 },
      { header: 'Item Name', key: 'itemName', width: 30 },
      { header: 'Item Size', key: 'itemSize', width: 12 },
      { header: 'Item Quantity', key: 'itemQty', width: 12 },
      { header: 'Item Price', key: 'itemPrice', width: 14 },
      { header: 'Item GST', key: 'itemGst', width: 14 },
      { header: 'Amount', key: 'amount', width: 14 },
    ];
    ws.getRow(1).font = { bold: true };

    for (const o of orders) {
      const date = new Date(o.orderDate).toLocaleDateString('en-GB');
      for (const item of o.items ?? []) {
        ws.addRow({
          rowKey: `${o.id}|${item.id}`,
          invoiceNumber: o.invoiceNumber,
          date,
          customer: o.buyerName,
          country: o.buyerCountry ?? '',
          itemName: item.particulars,
          itemSize: item.size ?? '',
          itemQty: item.quantity,
          itemPrice: +Number(item.priceInr).toFixed(2),
          itemGst: +Number(item.gstAmount).toFixed(2),
          amount: +Number(item.amountInr).toFixed(2),
        });
      }
    }

    return wb.xlsx.writeBuffer() as unknown as Promise<Buffer>;
  }

  // ── Bulk Edit Upload ───────────────────────────────────────────────────
  // Round-trip: user downloads the report, edits cells, re-uploads. We match
  // rows back to records by the hidden Row Key column ("orderId|itemId").
  // Editable fields per item row: Item Name, Item Size, Item Quantity, Amount.
  // Amount is the source of truth — taxable, GST, and per-unit price are
  // reverse-calculated from it (using the row's existing gstRate).
  async bulkUpdate(
    file: { buffer: Buffer; originalname?: string },
    user: User,
  ): Promise<{ updated: number; skipped: number; errors: string[] }> {
    if (!file || !file.buffer) {
      throw new BadRequestException('No file uploaded');
    }

    const wb = new ExcelJS.Workbook();
    await wb.xlsx.load(file.buffer as any);
    const ws = wb.worksheets[0];
    if (!ws) throw new BadRequestException('No worksheet found in upload');

    // Map header cells → column index. Header row is row 1.
    const headerRow = ws.getRow(1);
    const colIndex: Record<string, number> = {};
    headerRow.eachCell((cell, col) => {
      const v = String(cell.value ?? '').trim().toLowerCase();
      colIndex[v] = col;
    });

    const col = (name: string) => colIndex[name.toLowerCase()];
    const required = ['row key', 'item quantity', 'amount'];
    for (const h of required) {
      if (!col(h)) {
        throw new BadRequestException(`Required column missing in upload: "${h}"`);
      }
    }

    const errors: string[] = [];
    // Group parsed rows by orderId → list of { itemId, changes }
    type ItemChange = {
      itemId: string;
      particulars?: string;
      size?: string;
      quantity?: number;
      amountInr?: number;
    };
    const byOrder = new Map<string, ItemChange[]>();

    for (let r = 2; r <= ws.rowCount; r++) {
      const row = ws.getRow(r);
      const rawKey = row.getCell(col('row key')).value;
      const key = String(rawKey ?? '').trim();
      if (!key) continue;
      const [orderId, itemId] = key.split('|');
      if (!orderId || !itemId) {
        errors.push(`Row ${r}: invalid Row Key "${key}"`);
        continue;
      }

      const cellNum = (name: string): number | undefined => {
        const c = col(name);
        if (!c) return undefined;
        const v = row.getCell(c).value;
        if (v == null || v === '') return undefined;
        const n = Number(v);
        return Number.isFinite(n) ? n : undefined;
      };
      const cellStr = (name: string): string | undefined => {
        const c = col(name);
        if (!c) return undefined;
        const v = row.getCell(c).value;
        if (v == null) return undefined;
        return String(v).trim();
      };

      const change: ItemChange = { itemId };
      const particulars = cellStr('item name');
      if (particulars) change.particulars = particulars;
      const size = cellStr('item size');
      if (size !== undefined) change.size = size; // allow blanking
      const qty = cellNum('item quantity');
      if (qty !== undefined && qty > 0) change.quantity = Math.floor(qty);
      const amount = cellNum('amount');
      if (amount !== undefined && amount >= 0) change.amountInr = amount;

      const list = byOrder.get(orderId) ?? [];
      list.push(change);
      byOrder.set(orderId, list);
    }

    let updated = 0;
    let skipped = 0;

    for (const [orderId, changes] of byOrder) {
      const order = await this.orderRepo.findOne({
        where: { id: orderId },
        relations: ['items'],
      });
      if (!order) {
        skipped += changes.length;
        errors.push(`Order ${orderId} not found — ${changes.length} row(s) skipped`);
        continue;
      }
      if (order.status === BillingOrderStatus.CONFIRMED) {
        skipped += changes.length;
        errors.push(`Order ${order.invoiceNumber} is CONFIRMED — ${changes.length} row(s) skipped`);
        continue;
      }

      const itemsById = new Map(order.items.map((i) => [i.id, i]));
      const dirty: HandDeliveryItem[] = [];
      for (const ch of changes) {
        const item = itemsById.get(ch.itemId);
        if (!item) {
          skipped += 1;
          errors.push(`Item ${ch.itemId} not in invoice ${order.invoiceNumber}`);
          continue;
        }
        if (ch.particulars !== undefined) item.particulars = ch.particulars;
        if (ch.size !== undefined) item.size = ch.size || null;
        if (ch.quantity !== undefined) item.quantity = ch.quantity;
        if (ch.amountInr !== undefined) {
          item.amountInr = ch.amountInr;
        }
        // Always recompute derived fields from current amount/qty/rate
        const rate = Number(item.gstRate) || 5;
        const calc = reverseCalc(Number(item.amountInr), rate, item.quantity);
        item.gstRate = rate;
        item.taxableValue = calc.taxable;
        item.gstAmount = calc.gst;
        item.priceInr = calc.unitPrice;
        dirty.push(item);
      }
      if (dirty.length) {
        await this.itemRepo.save(dirty);
        updated += dirty.length;
        await this.auditService.log({
          action: AuditAction.HAND_DELIVERY_UPDATED,
          entityType: 'HandDeliveryOrder',
          entityId: order.id,
          userId: user.id,
          newValues: { bulkUpdated: dirty.length } as any,
        });
      }
    }

    return { updated, skipped, errors };
  }
}
