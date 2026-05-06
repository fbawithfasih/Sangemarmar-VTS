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

  // Indian numbering: crore / lakh / thousand
  function indianWords(n: number): string {
    if (n === 0) return 'ZERO';
    let words = '';
    const crore = Math.floor(n / 10000000); n %= 10000000;
    const lakh = Math.floor(n / 100000); n %= 100000;
    const thousand = Math.floor(n / 1000); n %= 1000;
    if (crore > 0) words += convertHundreds(crore) + ' CRORE ';
    if (lakh > 0) words += convertHundreds(lakh) + ' LAKH ';
    if (thousand > 0) words += convertHundreds(thousand) + ' THOUSAND ';
    if (n > 0) words += convertHundreds(n);
    return words.trim();
  }

  const rupees = Math.floor(amount);
  const paise = Math.round((amount - rupees) * 100);
  const rupeeWords = indianWords(rupees);
  if (paise > 0) return `RUPEES ${rupeeWords} AND ${convertHundreds(paise)} PAISE ONLY`;
  return `RUPEES ${rupeeWords} ONLY`;
}

function fmtDate(d: Date | string): string {
  return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

function fmtInr(n: number): string {
  return `Rs. ${Number(n).toFixed(2)}`;
}

const COMPANY = {
  name: 'S.K. COTTAGE INDUSTRIES',
  subtitle: 'Manufacturers & Exporters of: Handmade Marble Inlay Handicrafts & Textiles',
  address: 'A/C-2/2, TAJ NAGRI, PHASE II, AGRA-282001 (INDIA)',
  gstin: '09ADAPK6665Q1ZT',
  iec: '0607000473',
  bankName: 'IDBI BANK LTD, TAJGANJ',
  bankBranch: 'FATEHABAD ROAD, AGRA',
  bankAccount: '303102000000426',
  bankIfsc: 'IBKL0000303',
  bankSwift: 'IBKLINBBD18',
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
    const startOfFy = new Date(fyStart, 3, 1);
    const count = await this.orderRepo.count({ where: { createdAt: MoreThanOrEqual(startOfFy) } });
    return `SKC/${String(count + 1).padStart(3, '0')}/${fyLabel}`;
  }

  async create(dto: CreateBillingOrderDto, user: User): Promise<BillingOrder> {
    if (dto.vehicleEntryId) {
      const entry = await this.vehiclesService.findOne(dto.vehicleEntryId);
      if (!entry) throw new NotFoundException('Vehicle entry not found');
    }

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
        hsnCode: i.hsnCode,
        size: i.size,
        quantity: i.quantity,
        priceInr: i.priceInr,
        amountInr: i.quantity * i.priceInr,
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
          hsnCode: i.hsnCode,
          size: i.size,
          quantity: i.quantity,
          priceInr: i.priceInr,
          amountInr: i.quantity * i.priceInr,
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
    const total = order.items.reduce((s, i) => s + Number(i.amountInr), 0);
    const totalQty = order.items.reduce((s, i) => s + i.quantity, 0);

    return new Promise((resolve) => {
      const doc = new PDFDocument({ margin: 40, size: 'A4' });
      const chunks: Buffer[] = [];
      doc.on('data', (c) => chunks.push(c));
      doc.on('end', () => resolve(Buffer.concat(chunks)));

      const W = 515;
      const left = 40;

      doc.fontSize(14).font('Helvetica-Bold').text(COMPANY.name, left, 40, { align: 'center', width: W });
      doc.fontSize(9).font('Helvetica').text(COMPANY.subtitle, left, doc.y, { align: 'center', width: W });
      doc.fontSize(8).text(COMPANY.address, left, doc.y, { align: 'center', width: W });
      doc.fontSize(9).font('Helvetica-Bold').text('EXPORT ORDER RECEIPT VOUCHER', left, doc.y + 4, { align: 'center', width: W });
      doc.moveDown(0.4);
      doc.fontSize(8).font('Helvetica').text(`GSTIN: ${COMPANY.gstin}      IEC: ${COMPANY.iec}`, left, doc.y, { align: 'center', width: W });
      doc.moveDown(0.5);
      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.3);

      const headerY = doc.y;
      doc.fontSize(9).font('Helvetica-Bold').text(`Order No: ${order.invoiceNumber}`, left, headerY, { align: 'right', width: W });
      doc.fontSize(9).font('Helvetica').text(`Date: ${fmtDate(order.orderDate)}`, left, doc.y, { align: 'right', width: W });
      doc.fontSize(8).font('Helvetica-Bold').text('Bank Details:', left, headerY);
      doc.font('Helvetica').text(`${COMPANY.bankName}, ${COMPANY.bankBranch}`, left, doc.y, { width: W * 0.6 });
      doc.text(`A/c No: ${COMPANY.bankAccount}   IFSC: ${COMPANY.bankIfsc}   SWIFT: ${COMPANY.bankSwift}`, left, doc.y, { width: W * 0.7 });
      doc.moveDown(1);

      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.3);
      doc.fontSize(9).font('Helvetica-Bold').text("BUYER'S DETAILS (IN CAPITAL LETTERS)", left, doc.y, { align: 'center', width: W });
      doc.moveDown(0.3);
      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.4);

      const col1 = left;
      const col2 = left + W / 2 + 10;
      const colW = W / 2 - 10;
      const fs = 8.5;

      function buyerRow(label1: string, val1: string, label2: string, val2: string) {
        const y = doc.y;
        doc.fontSize(fs).font('Helvetica-Bold').text(`${label1}:`, col1, y, { width: colW, continued: true })
          .font('Helvetica').text(` ${val1}`);
        doc.fontSize(fs).font('Helvetica-Bold').text(`${label2}:`, col2, y, { width: colW, continued: true })
          .font('Helvetica').text(` ${val2}`);
        doc.moveDown(0.5);
      }

      const cell = order.buyerCellAreaCode || order.buyerCellNo
        ? `${order.buyerCellAreaCode || ''} ${order.buyerCellNo || ''}`.trim()
        : '—';
      buyerRow('Name', order.buyerName, 'Passport No.', order.buyerPassportNo);
      buyerRow('Address', order.buyerAddress, 'Date of Birth', order.buyerDOB ? fmtDate(order.buyerDOB) : '—');
      buyerRow('City', order.buyerCity, 'Nationality', order.buyerNationality);
      buyerRow('State', order.buyerState, 'Sea Port', order.buyerSeaPort);
      buyerRow('Zip Code', order.buyerZip, 'Country', order.buyerCountry);
      buyerRow('Cell No.', cell, 'E-mail', order.buyerEmail);
      buyerRow('WhatsApp No.', order.buyerWhatsApp, '', '');

      doc.moveDown(0.2);
      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.5);

      // ── Items Table ──
      const c = { qty: left, part: left + 40, hsn: left + W - 180, size: left + W - 130, amt: left + W - 80 };
      const cW = { qty: 38, part: W - 38 - 100 - 50 - 80, hsn: 50, size: 50, amt: 80 };

      doc.fontSize(8.5).font('Helvetica-Bold');
      const hY = doc.y;
      doc.text('Qty', c.qty, hY, { width: cW.qty, align: 'center' });
      doc.text('PARTICULARS (Handmade Handicrafts)', c.part, hY, { width: cW.part });
      doc.text('HSN', c.hsn, hY, { width: cW.hsn, align: 'center' });
      doc.text('Size', c.size, hY, { width: cW.size, align: 'center' });
      doc.text('Amount C.I.F. Rs. P.', c.amt, hY, { width: cW.amt, align: 'right' });
      doc.moveDown(0.4);
      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.4);

      doc.font('Helvetica').fontSize(8.5);
      for (const item of order.items) {
        if (doc.y > 700) doc.addPage();
        const rowY = doc.y;
        doc.text(String(item.quantity), c.qty, rowY, { width: cW.qty, align: 'center' });
        doc.text(item.particulars, c.part, rowY, { width: cW.part });
        doc.text(item.hsnCode || '—', c.hsn, rowY, { width: cW.hsn, align: 'center' });
        doc.text(item.size || '—', c.size, rowY, { width: cW.size, align: 'center' });
        doc.text(Number(item.amountInr).toFixed(2), c.amt, rowY, { width: cW.amt, align: 'right' });
        doc.moveDown(0.6);
      }

      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.4);

      const totalRowY = doc.y;
      doc.font('Helvetica-Bold').fontSize(8.5).text(`Total Qty: ${totalQty}`, c.qty, totalRowY, { width: cW.qty + cW.part + cW.hsn + cW.size });
      doc.text(`TOTAL: ${fmtInr(total)}`, c.amt - 60, totalRowY, { width: cW.amt + 60, align: 'right' });
      doc.moveDown(0.8);

      doc.font('Helvetica').fontSize(8.5).text(`Rs. in words: ${amountInWords(total)}`, left, doc.y, { width: W });
      doc.moveDown(1);

      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.4);
      doc.fontSize(7).font('Helvetica').text(
        '* Agreed to Terms & Condition Overleaf.\n* Goods reserved under this order can not be cancelled.\n* If Any Tax / Duties at the Destination will be paid by buyer.\n* No Exchange / No Refund of Goods Once Sold.',
        left, doc.y, { width: W },
      );
      doc.moveDown(1);

      const sigY = doc.y;
      doc.fontSize(8).font('Helvetica-Bold').text('Buyer Signature:', left, sigY);
      doc.text(`For ${COMPANY.name}`, left + W - 200, sigY, { width: 200, align: 'right' });
      doc.moveDown(2);
      doc.font('Helvetica').fontSize(7).text('See Terms & Condition Over Leaf', left, doc.y);
      doc.text('(Authorised Signatory)', left + W - 200, doc.y - 11, { width: 200, align: 'right' });

      // ── Page 2: Instructions / Terms & Conditions ──
      doc.addPage();
      doc.fontSize(14).font('Helvetica-Bold').text('INSTRUCTIONS', left, 80, { align: 'center', width: W });
      doc.moveDown(2);

      const tcs = [
        'Subject to Agra (India) Jurisdiction only',
        'No Exchange / No Refund of Goods Once Sold.',
        'Goods dispatched by sea will be delivered at the nearest international sea-Port of the consignee. Name of the international Sea-Port will be given by the customer.',
        "Transportation charges from Sea-port to customer's home and off loading charge will be borne by the customer.",
        'Custom made order will be dispatched on completion of order. The time for manufacture depends upon the labour involved, normally it takes 12 to 14 weeks for manufacture of the medium size table top.',
        'C.I.F. Means cost includes, Insurance from warehouse to warehouse and ocean freight upto Seaport.',
        'If Any Tax / Duties at the Destination will be Paid By Buyer.',
        'Once the shipment reached the destination custom clearance will be done by the buyer, if any delay in custom clearance the buyer will be solely responsible for the all charges occurred.',
        'If any loss or damage in transit Consignee will claim the insurance at the destination.',
        'In future correspondence please mention order number.',
      ];

      doc.fontSize(10).font('Helvetica');
      tcs.forEach((tc, idx) => {
        doc.text(`${idx + 1}. ${tc}`, left + 20, doc.y, { width: W - 40, paragraphGap: 6 });
        doc.moveDown(0.4);
      });

      doc.end();
    });
  }

  // ── PDF: Sales Invoice ───────────────────────────────────────────────────

  async exportInvoice(id: string): Promise<Buffer> {
    const order = await this.findOne(id);
    const total = order.items.reduce((s, i) => s + Number(i.amountInr), 0);
    const totalQty = order.items.reduce((s, i) => s + i.quantity, 0);

    return new Promise((resolve) => {
      const doc = new PDFDocument({ margin: 40, size: 'A4' });
      const chunks: Buffer[] = [];
      doc.on('data', (c) => chunks.push(c));
      doc.on('end', () => resolve(Buffer.concat(chunks)));

      const W = 515;
      const left = 40;

      doc.fontSize(13).font('Helvetica-Bold').text('INVOICE', left, 40, { align: 'center', width: W });
      doc.moveDown(0.5);
      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.4);

      const shipperX = left;
      const invX = left + W / 2;
      const halfW = W / 2 - 10;
      const detailY = doc.y;

      doc.fontSize(9).font('Helvetica-Bold').text('Shipper:', shipperX, detailY, { width: halfW });
      doc.fontSize(9).font('Helvetica').text(COMPANY.name, shipperX, doc.y, { width: halfW });
      doc.text(COMPANY.subtitle, shipperX, doc.y, { width: halfW });
      doc.text(COMPANY.address, shipperX, doc.y, { width: halfW });

      doc.fontSize(9).font('Helvetica-Bold').text(`Invoice No: ${order.invoiceNumber}`, invX, detailY, { width: halfW });
      doc.fontSize(9).font('Helvetica').text(`Date: ${fmtDate(order.orderDate)}`, invX, doc.y, { width: halfW });
      doc.moveDown(0.4);
      doc.text(`Buyer's Order No: ${order.vehicleEntry?.vehicleNumber ?? '—'}`, invX, doc.y, { width: halfW });
      doc.moveDown(0.3);
      doc.font('Helvetica-Bold').text(`GSTIN: ${COMPANY.gstin}`, invX, doc.y, { width: halfW });
      doc.text(`IEC: ${COMPANY.iec}`, invX, doc.y, { width: halfW });

      doc.moveDown(1.5);
      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.4);

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

      const cols = { no: left, desc: left + 30, hsn: left + W - 215, qty: left + W - 160, price: left + W - 100, amt: left + W - 55 };
      const colW2 = { no: 28, desc: W - 28 - 220, hsn: 50, qty: 55, price: 55, amt: 55 };

      doc.fontSize(8.5).font('Helvetica-Bold');
      const tHdrY = doc.y;
      doc.text('No.', cols.no, tHdrY, { width: colW2.no, align: 'center' });
      doc.text('Description of Goods', cols.desc, tHdrY, { width: colW2.desc });
      doc.text('HSN', cols.hsn, tHdrY, { width: colW2.hsn, align: 'center' });
      doc.text('Qty\n(PCS)', cols.qty, tHdrY, { width: colW2.qty, align: 'center' });
      doc.text('Price\n(INR)', cols.price, tHdrY, { width: colW2.price, align: 'right' });
      doc.text('Amount\n(INR)', cols.amt, tHdrY, { width: colW2.amt, align: 'right' });
      doc.moveDown(0.8);
      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.4);

      doc.font('Helvetica').fontSize(8.5);
      order.items.forEach((item, idx) => {
        if (doc.y > 680) doc.addPage();
        const ry = doc.y;
        doc.text(String(idx + 1), cols.no, ry, { width: colW2.no, align: 'center' });
        doc.text(item.particulars, cols.desc, ry, { width: colW2.desc });
        doc.text(item.hsnCode || '—', cols.hsn, ry, { width: colW2.hsn, align: 'center' });
        doc.text(String(item.quantity), cols.qty, ry, { width: colW2.qty, align: 'center' });
        doc.text(Number(item.priceInr).toFixed(2), cols.price, ry, { width: colW2.price, align: 'right' });
        doc.text(Number(item.amountInr).toFixed(2), cols.amt, ry, { width: colW2.amt, align: 'right' });
        doc.moveDown(0.7);
      });

      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.4);

      const totY = doc.y;
      doc.font('Helvetica-Bold').fontSize(8.5).text(`TOTAL  ${totalQty} PCS`, cols.desc, totY, { width: colW2.desc + colW2.no + colW2.hsn + colW2.qty });
      doc.text(`Rs. ${total.toFixed(2)}`, cols.amt, totY, { width: colW2.amt, align: 'right' });
      doc.moveDown(1);

      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.4);

      doc.font('Helvetica-Bold').fontSize(8.5).text(`Amount ${amountInWords(total)}`, left, doc.y, { width: W / 2 });
      doc.font('Helvetica').fontSize(8.5).text(`(TOTAL Rs.)     ${total.toFixed(2)}`, left + W / 2, doc.y - 10, { width: W / 2, align: 'right' });
      doc.moveDown(1);

      if (order.notes) {
        doc.font('Helvetica').fontSize(8).text(`Note: ${order.notes}`, left, doc.y, { width: W });
        doc.moveDown(0.8);
      }

      doc.moveTo(left, doc.y).lineTo(left + W, doc.y).stroke();
      doc.moveDown(0.5);

      doc.font('Helvetica-Bold').fontSize(9).text(`For ${COMPANY.name}`, left + W - 200, doc.y, { width: 200, align: 'right' });
      doc.moveDown(2.5);
      doc.font('Helvetica').fontSize(8).text('_________________________', left + W - 200, doc.y, { width: 200, align: 'right' });
      doc.moveDown(0.2);
      doc.text('(Authorised Signatory)', left + W - 200, doc.y, { width: 200, align: 'right' });

      doc.end();
    });
  }

  async exportList(filter: BillingFilterDto, format: 'xlsx' | 'pdf'): Promise<Buffer> {
    const orders = await this.findAll(filter);

    if (format === 'xlsx') {
      const wb = new ExcelJS.Workbook();
      wb.creator = COMPANY.name;
      const ws = wb.addWorksheet('BILLING ORDERS');
      ws.columns = [
        { header: 'Invoice No.', key: 'inv', width: 18 },
        { header: 'Order Date', key: 'date', width: 14 },
        { header: 'Buyer Name', key: 'buyer', width: 24 },
        { header: 'Country', key: 'country', width: 16 },
        { header: 'Vehicle No.', key: 'vehicle', width: 16 },
        { header: 'Items', key: 'items', width: 8 },
        { header: 'Total (INR)', key: 'total', width: 14 },
        { header: 'Status', key: 'status', width: 12 },
      ];
      ws.getRow(1).font = { bold: true };
      for (const o of orders) {
        const total = o.items.reduce((s, i) => s + Number(i.amountInr), 0);
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

        const grandTotal = orders.reduce((s, o) => s + o.items.reduce((si, i) => si + Number(i.amountInr), 0), 0);
        doc.font('Helvetica-Bold').fontSize(9).text(`Total Orders: ${orders.length}   Grand Total: Rs. ${grandTotal.toFixed(2)}`);
        doc.moveDown(0.5);

        for (const o of orders) {
          if (doc.y > 720) doc.addPage();
          const total = o.items.reduce((s, i) => s + Number(i.amountInr), 0);
          doc.font('Helvetica-Bold').fontSize(8.5)
            .text(`${o.invoiceNumber}   ${fmtDate(o.orderDate)}   ${o.buyerName} (${o.buyerCountry})`, { continued: true })
            .font('Helvetica').text(`   Vehicle: ${o.vehicleEntry?.vehicleNumber ?? '—'}   Total: Rs. ${total.toFixed(2)}   [${o.status}]`);
        }

        doc.end();
      });
    }
  }
}
