import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, LessThanOrEqual, MoreThanOrEqual, Repository } from 'typeorm';
import * as ExcelJS from 'exceljs';
import * as PDFDocument from 'pdfkit';
import { BillingOrder } from './entities/billing-order.entity';
import { BillingItem } from './entities/billing-item.entity';
import { CreateBillingOrderDto, UpdateBillingOrderDto } from './dto/create-billing-order.dto';
import { BillingFilterDto } from './dto/billing-filter.dto';
import { AuditService } from '../audit/audit.service';
import { VehiclesService } from '../vehicles/vehicles.service';
import { AuditAction, BillingOrderStatus } from '../common/enums';
import { User } from '../users/entities/user.entity';

// IST helpers (same pattern as reports.service.ts)
function istDayStart(dateStr: string): Date {
  return new Date(`${dateStr}T00:00:00+05:30`);
}
function istDayEnd(dateStr: string): Date {
  return new Date(`${dateStr}T23:59:59.999+05:30`);
}

function amountInWords(amount: number): string {
  const ones = ['', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN', 'EIGHT', 'NINE',
    'TEN', 'ELEVEN', 'TWELVE', 'THIRTEEN', 'FOURTEEN', 'FIFTEEN', 'SIXTEEN', 'SEVENTEEN', 'EIGHTEEN', 'NINETEEN'];
  const tens = ['', '', 'TWENTY', 'THIRTY', 'FORTY', 'FIFTY', 'SIXTY', 'SEVENTY', 'EIGHTY', 'NINETY'];

  function convertHundreds(n: number): string {
    let result = '';
    if (n >= 100) { result += ones[Math.floor(n / 100)] + ' HUNDRED '; n %= 100; }
    if (n >= 20) { result += tens[Math.floor(n / 10)] + ' '; n %= 10; }
    if (n > 0) result += ones[n] + ' ';
    return result.trim();
  }

  const dollars = Math.floor(amount);
  const cents = Math.round((amount - dollars) * 100);
  let words = '';
  if (dollars >= 1000) words += convertHundreds(Math.floor(dollars / 1000)) + ' THOUSAND ';
  words += convertHundreds(dollars % 1000);
  const base = `USD ${words.trim()} ONLY`;
  if (cents > 0) return `USD ${words.trim()} AND ${convertHundreds(cents)} CENTS ONLY`;
  return base;
}

function fmtDate(d: Date | string): string {
  return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

function fmtUsd(n: number): string {
  return `$ ${Number(n).toFixed(2)}`;
}

const COMPANY = {
  name: 'THE SANGEMARMAR',
  subtitle: 'RAJ TOURS AND TRAVELS',
  address: 'Sangemarmar, India',
  phone: '',
  email: '',
  gstin: '',
};

@Injectable()
export class BillingService {
  constructor(
    @InjectRepository(BillingOrder) private readonly orderRepo: Repository<BillingOrder>,
    @InjectRepository(BillingItem) private readonly itemRepo: Repository<BillingItem>,
    private readonly auditService: AuditService,
    private readonly vehiclesService: VehiclesService,
  ) {}

  private async generateInvoiceNumber(): Promise<string> {
    const now = new Date();
    const fyStart = now.getMonth() >= 3 ? now.getFullYear() : now.getFullYear() - 1;
    const fyEnd = fyStart + 1;
    const fyLabel = `${String(fyStart).slice(2)}-${String(fyEnd).slice(2)}`;
    const startOfFy = new Date(fyStart, 3, 1); // April 1
    const count = await this.orderRepo.count({ where: { createdAt: MoreThanOrEqual(startOfFy) } });
    return `TSM/${String(count + 1).padStart(3, '0')}/${fyLabel}`;
  }

  async create(dto: CreateBillingOrderDto, user: User): Promise<BillingOrder> {
    const entry = await this.vehiclesService.findOne(dto.vehicleEntryId);
    if (!entry) throw new NotFoundException('Vehicle entry not found');

    const invoiceNumber = await this.generateInvoiceNumber();
    const { items, ...orderData } = dto;

    const order = this.orderRepo.create({
      ...orderData,
      invoiceNumber,
      createdById: user.id,
    });
    const saved = await this.orderRepo.save(order);

    const billingItems = items.map((i) =>
      this.itemRepo.create({
        billingOrderId: saved.id,
        particulars: i.particulars,
        quantity: i.quantity,
        priceUsd: i.priceUsd,
        amountUsd: i.quantity * i.priceUsd,
      }),
    );
    await this.itemRepo.save(billingItems);

    await this.auditService.log({
      action: AuditAction.BILLING_ORDER_CREATED,
      entityType: 'BillingOrder',
      entityId: saved.id,
      userId: user.id,
      newValues: { invoiceNumber, vehicleEntryId: dto.vehicleEntryId, buyerName: dto.buyerName } as any,
    });

    return this.findOne(saved.id);
  }

  async findAll(filter: BillingFilterDto): Promise<BillingOrder[]> {
    const where: any = {};
    if (filter.vehicleEntryId) where.vehicleEntryId = filter.vehicleEntryId;
    if (filter.dateFrom && filter.dateTo) {
      where.orderDate = Between(istDayStart(filter.dateFrom), istDayEnd(filter.dateTo));
    } else if (filter.dateFrom) {
      where.orderDate = MoreThanOrEqual(istDayStart(filter.dateFrom));
    } else if (filter.dateTo) {
      where.orderDate = LessThanOrEqual(istDayEnd(filter.dateTo));
    }
    return this.orderRepo.find({
      where,
      relations: ['items', 'vehicleEntry', 'createdBy'],
      order: { orderDate: 'DESC' },
    });
  }

  async findOne(id: string): Promise<BillingOrder> {
    const order = await this.orderRepo.findOne({
      where: { id },
      relations: ['items', 'vehicleEntry', 'createdBy'],
    });
    if (!order) throw new NotFoundException('Billing order not found');
    return order;
  }

  async update(id: string, dto: UpdateBillingOrderDto, user: User): Promise<BillingOrder> {
    const order = await this.findOne(id);
    if (order.status === BillingOrderStatus.CONFIRMED) {
      throw new BadRequestException('Cannot edit a confirmed order');
    }

    const { items, ...orderData } = dto;
    Object.assign(order, orderData);
    await this.orderRepo.save(order);

    if (items && items.length > 0) {
      await this.itemRepo.delete({ billingOrderId: id });
      const newItems = items.map((i) =>
        this.itemRepo.create({
          billingOrderId: id,
          particulars: i.particulars,
          quantity: i.quantity,
          priceUsd: i.priceUsd,
          amountUsd: i.quantity * i.priceUsd,
        }),
      );
      await this.itemRepo.save(newItems);
    }

    await this.auditService.log({
      action: AuditAction.BILLING_ORDER_UPDATED,
      entityType: 'BillingOrder',
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
      action: AuditAction.BILLING_ORDER_DELETED,
      entityType: 'BillingOrder',
      entityId: id,
      userId: user.id,
      newValues: {} as any,
    });
  }

  // ── PDF: Order Receipt Voucher ───────────────────────────────────────────

  async exportOrv(id: string): Promise<Buffer> {
    const order = await this.findOne(id);
    const total = order.items.reduce((s, i) => s + Number(i.amountUsd), 0);
    const totalQty = order.items.reduce((s, i) => s + i.quantity, 0);

    return new Promise((resolve) => {
      const doc = new PDFDocument({ margin: 40, size: 'A4' });
      const chunks: Buffer[] = [];
      doc.on('data', (c) => chunks.push(c));
      doc.on('end', () => resolve(Buffer.concat(chunks)));

      const W = 515; // usable width (595 - 2*40)
      const left = 40;

      // ── Header ──
      doc.fontSize(14).font('Helvetica-Bold').text(COMPANY.name, left, 40, { align: 'center', width: W });
      doc.fontSize(9).font('Helvetica').text(COMPANY.subtitle, left, doc.y, { align: 'center', width: W });
      doc.fontSize(9).text('EXPORT ORDER RECEIPT VOUCHER', left, doc.y, { align: 'center', width: W });
      doc.moveDown(0.5);
      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.3);

      // Order No + Date (right-aligned block)
      const headerY = doc.y;
      doc.fontSize(9).font('Helvetica-Bold').text(`Order No: ${order.invoiceNumber}`, left, headerY, { align: 'right', width: W });
      doc.fontSize(9).font('Helvetica').text(`Date: ${fmtDate(order.orderDate)}`, left, doc.y, { align: 'right', width: W });
      doc.fontSize(9).text(`Vehicle Entry: ${order.vehicleEntry?.vehicleNumber ?? '—'}  (${fmtDate(order.vehicleEntry?.entryDate ?? order.orderDate)})`, left, headerY + 28, { width: W * 0.6 });
      doc.moveDown(1.5);

      // ── Buyer's Details ──
      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.3);
      doc.fontSize(9).font('Helvetica-Bold').text('BUYER\'S DETAILS (IN CAPITAL LETTERS)', left, doc.y, { align: 'center', width: W });
      doc.moveDown(0.3);
      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.4);

      const col1 = left;
      const col2 = left + W / 2 + 10;
      const colW = W / 2 - 10;
      const labelFont = 'Helvetica-Bold';
      const valFont = 'Helvetica';
      const fs = 8.5;

      function buyerRow(label1: string, val1: string, label2: string, val2: string) {
        const y = doc.y;
        doc.fontSize(fs).font(labelFont).text(`${label1}:`, col1, y, { width: colW, continued: true })
          .font(valFont).text(` ${val1}`);
        doc.fontSize(fs).font(labelFont).text(`${label2}:`, col2, y, { width: colW, continued: true })
          .font(valFont).text(` ${val2}`);
        doc.moveDown(0.5);
      }

      buyerRow('Name', order.buyerName, 'Passport No.', order.buyerPassportNo);
      buyerRow('Address', order.buyerAddress, 'Date of Birth', order.buyerDOB ? fmtDate(order.buyerDOB) : '—');
      buyerRow('City', order.buyerCity, 'Nationality', order.buyerNationality);
      buyerRow('State', order.buyerState, 'Sea Port', order.buyerSeaPort);
      buyerRow('Zip Code', order.buyerZip, 'Country', order.buyerCountry);
      buyerRow('WhatsApp No.', order.buyerWhatsApp, 'E-mail', order.buyerEmail);

      doc.moveDown(0.3);
      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.5);

      // ── Items Table ──
      const c = { qty: left, part: left + 40, size: left + W - 120, amt: left + W - 70 };
      const cW = { qty: 38, part: W - 38 - 90 - 70, size: 50, amt: 70 };

      doc.fontSize(8.5).font(labelFont);
      doc.text('Qty', c.qty, doc.y, { width: cW.qty, align: 'center' });
      const headerRowY = doc.y - 11;
      doc.text('PARTICULARS', c.part, headerRowY, { width: cW.part });
      doc.text('Size', c.size, headerRowY, { width: cW.size, align: 'center' });
      doc.text('Amount (USD)', c.amt, headerRowY, { width: cW.amt, align: 'right' });
      doc.moveDown(0.3);
      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.4);

      doc.font(valFont).fontSize(8.5);
      for (const item of order.items) {
        if (doc.y > 700) doc.addPage();
        const rowY = doc.y;
        doc.text(String(item.quantity), c.qty, rowY, { width: cW.qty, align: 'center' });
        doc.text(item.particulars, c.part, rowY, { width: cW.part });
        doc.text('—', c.size, rowY, { width: cW.size, align: 'center' });
        doc.text(fmtUsd(Number(item.amountUsd)), c.amt, rowY, { width: cW.amt, align: 'right' });
        doc.moveDown(0.6);
      }

      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.4);

      // Total qty + amount
      const totalRowY = doc.y;
      doc.font(labelFont).fontSize(8.5).text(`Total Qty: ${totalQty}`, c.qty, totalRowY, { width: cW.qty + cW.part + cW.size });
      doc.text(`TOTAL: ${fmtUsd(total)}`, c.amt - 60, totalRowY, { width: cW.amt + 60, align: 'right' });
      doc.moveDown(0.8);

      // Amount in words
      doc.font(valFont).fontSize(8.5).text(`Amount in words: ${amountInWords(total)}`, left, doc.y, { width: W });
      doc.moveDown(1);

      // Terms
      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.4);
      doc.fontSize(7).font(valFont).text(
        '* Agreed to Terms & Condition Overleaf.\n* Goods reserved under this order cannot be cancelled.\n* If Any Tax / Duties at the Destination will be paid by buyer.\n* No Exchange / No Refund of Goods Once Sold.',
        left, doc.y, { width: W },
      );
      doc.moveDown(1);

      // Signatures
      const sigY = doc.y;
      doc.fontSize(8).font(labelFont).text('Buyer Signature:', left, sigY);
      doc.text(`For ${COMPANY.name}`, left + W - 150, sigY, { width: 150, align: 'right' });
      doc.moveDown(2);
      doc.font(valFont).fontSize(7).text('_________________________', left, doc.y);
      doc.text('(Manager)', left + W - 150, doc.y - 11, { width: 150, align: 'right' });

      doc.end();
    });
  }

  // ── PDF: Sales Invoice ───────────────────────────────────────────────────

  async exportInvoice(id: string): Promise<Buffer> {
    const order = await this.findOne(id);
    const total = order.items.reduce((s, i) => s + Number(i.amountUsd), 0);
    const totalQty = order.items.reduce((s, i) => s + i.quantity, 0);

    return new Promise((resolve) => {
      const doc = new PDFDocument({ margin: 40, size: 'A4' });
      const chunks: Buffer[] = [];
      doc.on('data', (c) => chunks.push(c));
      doc.on('end', () => resolve(Buffer.concat(chunks)));

      const W = 515;
      const left = 40;

      // ── Title ──
      doc.fontSize(13).font('Helvetica-Bold').text('INVOICE', left, 40, { align: 'center', width: W });
      doc.moveDown(0.5);
      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.4);

      // ── Shipper | Invoice details ──
      const shipperX = left;
      const invX = left + W / 2;
      const halfW = W / 2 - 10;
      const detailY = doc.y;

      doc.fontSize(9).font('Helvetica-Bold').text('Shipper:', shipperX, detailY, { width: halfW });
      doc.fontSize(9).font('Helvetica').text(COMPANY.name, shipperX, doc.y, { width: halfW });
      doc.text(COMPANY.subtitle, shipperX, doc.y, { width: halfW });
      if (COMPANY.address) doc.text(COMPANY.address, shipperX, doc.y, { width: halfW });
      if (COMPANY.phone) doc.text(`Ph: ${COMPANY.phone}`, shipperX, doc.y, { width: halfW });

      doc.fontSize(9).font('Helvetica-Bold').text(`Invoice No: ${order.invoiceNumber}`, invX, detailY, { width: halfW });
      doc.fontSize(9).font('Helvetica').text(`Date: ${fmtDate(order.orderDate)}`, invX, doc.y, { width: halfW });
      doc.moveDown(0.4);
      doc.text(`Buyer's Order No: ${order.vehicleEntry?.vehicleNumber ?? '—'}`, invX, doc.y, { width: halfW });
      if (COMPANY.gstin) {
        doc.moveDown(0.3);
        doc.font('Helvetica-Bold').text(`GSTIN: ${COMPANY.gstin}`, invX, doc.y, { width: halfW });
      }

      doc.moveDown(1.5);
      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.4);

      // ── Consignee ──
      const consY = doc.y;
      doc.fontSize(9).font('Helvetica-Bold').text('Consignee:', shipperX, consY, { width: halfW });
      doc.fontSize(9).font('Helvetica').text(order.buyerName, shipperX, doc.y, { width: halfW });
      doc.text(order.buyerAddress, shipperX, doc.y, { width: halfW });
      doc.text(`${order.buyerCity}, ${order.buyerState} ${order.buyerZip}`, shipperX, doc.y, { width: halfW });
      doc.text(order.buyerCountry, shipperX, doc.y, { width: halfW });

      doc.fontSize(9).font('Helvetica-Bold').text('Country of Origin:', invX, consY, { width: halfW, continued: true })
        .font('Helvetica').text(' INDIA');
      doc.font('Helvetica-Bold').text('Final Destination:', invX, doc.y, { width: halfW, continued: true })
        .font('Helvetica').text(` ${order.buyerCountry}`);
      doc.moveDown(0.4);
      doc.font('Helvetica-Bold').text('Passport No:', invX, doc.y, { width: halfW, continued: true })
        .font('Helvetica').text(` ${order.buyerPassportNo}`);
      doc.font('Helvetica-Bold').text('Nationality:', invX, doc.y, { width: halfW, continued: true })
        .font('Helvetica').text(` ${order.buyerNationality}`);

      doc.moveDown(1);
      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.5);

      // ── Items Table ──
      const cols = { no: left, desc: left + 30, qty: left + W - 160, price: left + W - 100, amt: left + W - 55 };
      const colW2 = { no: 28, desc: W - 28 - 165, qty: 55, price: 55, amt: 55 };

      doc.fontSize(8.5).font('Helvetica-Bold');
      const tHdrY = doc.y;
      doc.text('No.', cols.no, tHdrY, { width: colW2.no, align: 'center' });
      doc.text('Description of Goods', cols.desc, tHdrY, { width: colW2.desc });
      doc.text('Qty\n(PCS)', cols.qty, tHdrY, { width: colW2.qty, align: 'center' });
      doc.text('Price\n(USD)', cols.price, tHdrY, { width: colW2.price, align: 'right' });
      doc.text('Amount\n(USD)', cols.amt, tHdrY, { width: colW2.amt, align: 'right' });
      doc.moveDown(0.8);
      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.4);

      doc.font('Helvetica').fontSize(8.5);
      order.items.forEach((item, idx) => {
        if (doc.y > 680) doc.addPage();
        const ry = doc.y;
        doc.text(String(idx + 1), cols.no, ry, { width: colW2.no, align: 'center' });
        doc.text(item.particulars, cols.desc, ry, { width: colW2.desc });
        doc.text(String(item.quantity), cols.qty, ry, { width: colW2.qty, align: 'center' });
        doc.text(Number(item.priceUsd).toFixed(2), cols.price, ry, { width: colW2.price, align: 'right' });
        doc.text(Number(item.amountUsd).toFixed(2), cols.amt, ry, { width: colW2.amt, align: 'right' });
        doc.moveDown(0.7);
      });

      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.4);

      // Total row
      const totY = doc.y;
      doc.font('Helvetica-Bold').fontSize(8.5).text(`TOTAL  ${totalQty} PCS`, cols.desc, totY, { width: colW2.desc + colW2.no + colW2.qty });
      doc.text(`$ ${total.toFixed(2)}`, cols.amt, totY, { width: colW2.amt, align: 'right' });
      doc.moveDown(1);

      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.4);

      // Amount in words
      doc.font('Helvetica-Bold').fontSize(8.5).text(`Amount ${amountInWords(total)}`, left, doc.y, { width: W / 2 });
      doc.font('Helvetica').fontSize(8.5).text(`(TOTAL US $)     ${total.toFixed(2)}`, left + W / 2, doc.y - 10, { width: W / 2, align: 'right' });
      doc.moveDown(1);

      if (order.notes) {
        doc.font('Helvetica').fontSize(8).text(`Note: ${order.notes}`, left, doc.y, { width: W });
        doc.moveDown(0.8);
      }

      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.5);

      // Signature
      doc.font('Helvetica-Bold').fontSize(9).text(`For ${COMPANY.name}`, left + W - 200, doc.y, { width: 200, align: 'right' });
      doc.moveDown(2.5);
      doc.font('Helvetica').fontSize(8).text('_________________________', left + W - 200, doc.y, { width: 200, align: 'right' });
      doc.moveDown(0.2);
      doc.text('(Manager)', left + W - 200, doc.y, { width: 200, align: 'right' });

      doc.end();
    });
  }

  // ── List export ──────────────────────────────────────────────────────────

  async exportList(filter: BillingFilterDto, format: 'xlsx' | 'pdf'): Promise<Buffer> {
    const orders = await this.findAll(filter);

    if (format === 'xlsx') {
      const wb = new ExcelJS.Workbook();
      wb.creator = 'Sangemarmar VTS';
      const ws = wb.addWorksheet('BILLING ORDERS');
      ws.columns = [
        { header: 'Invoice No.', key: 'inv', width: 18 },
        { header: 'Order Date', key: 'date', width: 14 },
        { header: 'Buyer Name', key: 'buyer', width: 24 },
        { header: 'Country', key: 'country', width: 16 },
        { header: 'Vehicle No.', key: 'vehicle', width: 16 },
        { header: 'Items', key: 'items', width: 8 },
        { header: 'Total (USD)', key: 'total', width: 14 },
        { header: 'Status', key: 'status', width: 12 },
      ];
      ws.getRow(1).font = { bold: true };
      for (const o of orders) {
        const total = o.items.reduce((s, i) => s + Number(i.amountUsd), 0);
        ws.addRow({
          inv: o.invoiceNumber,
          date: new Date(o.orderDate).toLocaleDateString(),
          buyer: o.buyerName,
          country: o.buyerCountry,
          vehicle: o.vehicleEntry?.vehicleNumber ?? '—',
          items: o.items.length,
          total: +total.toFixed(2),
          status: o.status,
        });
      }
      return wb.xlsx.writeBuffer() as unknown as Promise<Buffer>;
    } else {
      return new Promise((resolve) => {
        const doc = new PDFDocument({ margin: 40, size: 'A4' });
        const chunks: Buffer[] = [];
        doc.on('data', (c) => chunks.push(c));
        doc.on('end', () => resolve(Buffer.concat(chunks)));

        doc.fontSize(14).font('Helvetica-Bold').text(COMPANY.name, { align: 'center' });
        doc.fontSize(10).font('Helvetica').text('Billing Orders Report', { align: 'center' });
        doc.moveDown();
        doc.moveTo(40, doc.y).lineTo(555, doc.y).stroke();
        doc.moveDown(0.5);

        const grandTotal = orders.reduce((s, o) => s + o.items.reduce((si, i) => si + Number(i.amountUsd), 0), 0);
        doc.font('Helvetica-Bold').fontSize(9).text(`Total Orders: ${orders.length}   Grand Total: $ ${grandTotal.toFixed(2)}`);
        doc.moveDown(0.5);

        for (const o of orders) {
          if (doc.y > 720) doc.addPage();
          const total = o.items.reduce((s, i) => s + Number(i.amountUsd), 0);
          doc.font('Helvetica-Bold').fontSize(8.5)
            .text(`${o.invoiceNumber}   ${fmtDate(o.orderDate)}   ${o.buyerName} (${o.buyerCountry})`, { continued: true })
            .font('Helvetica').text(`   Vehicle: ${o.vehicleEntry?.vehicleNumber ?? '—'}   Total: $ ${total.toFixed(2)}   [${o.status}]`);
        }

        doc.end();
      });
    }
  }
}
