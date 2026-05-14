import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, ILike, In, Repository } from 'typeorm';
import * as ExcelJS from 'exceljs';
import * as PDFDocument from 'pdfkit';
import { VehicleEntry } from '../vehicles/entities/vehicle-entry.entity';
import { Sale } from '../sales/entities/sale.entity';
import { Payment } from '../payments/entities/payment.entity';
import { Commission } from '../commissions/entities/commission.entity';
import { StatementFilterDto, StatementType } from './dto/statement-filter.dto';
import { CommissionRecipientType } from '../common/enums';

const TYPE_TO_FIELD: Record<StatementType, string> = {
  [StatementType.DRIVER]: 'driverName',
  [StatementType.GUIDE]: 'guideName',
  [StatementType.LOCAL_AGENT]: 'localAgent',
  [StatementType.COMPANY]: 'companyName',
};

const TYPE_TO_COMMISSION: Record<StatementType, CommissionRecipientType> = {
  [StatementType.DRIVER]: CommissionRecipientType.DRIVER,
  [StatementType.GUIDE]: CommissionRecipientType.GUIDE,
  [StatementType.LOCAL_AGENT]: CommissionRecipientType.LOCAL_AGENT,
  [StatementType.COMPANY]: CommissionRecipientType.COMPANY,
};

const UNIQUE_NAMES_TTL_MS = 5 * 60 * 1000;

@Injectable()
export class StatementsService {
  private readonly uniqueNamesCache = new Map<StatementType, { expiresAt: number; value: string[] }>();

  constructor(
    @InjectRepository(VehicleEntry) private readonly vehicleRepo: Repository<VehicleEntry>,
    @InjectRepository(Sale) private readonly saleRepo: Repository<Sale>,
    @InjectRepository(Payment) private readonly paymentRepo: Repository<Payment>,
    @InjectRepository(Commission) private readonly commissionRepo: Repository<Commission>,
  ) {}

  async getUniqueNames(type: StatementType): Promise<string[]> {
    const cached = this.uniqueNamesCache.get(type);
    if (cached && cached.expiresAt > Date.now()) return cached.value;

    const field = TYPE_TO_FIELD[type];
    const rows = await this.vehicleRepo
      .createQueryBuilder('ve')
      .select(`DISTINCT ve.${field}`, 'name')
      .orderBy(`ve.${field}`, 'ASC')
      .getRawMany();
    const value = rows.map((r) => r.name as string).filter(Boolean);
    this.uniqueNamesCache.set(type, { expiresAt: Date.now() + UNIQUE_NAMES_TTL_MS, value });
    return value;
  }

  async getStatement(filter: StatementFilterDto) {
    const field = TYPE_TO_FIELD[filter.type];
    const commissionType = TYPE_TO_COMMISSION[filter.type];

    const where: any = { [field]: ILike(`%${filter.name}%`) };
    if (filter.dateFrom && filter.dateTo) {
      where.entryDate = Between(new Date(filter.dateFrom), new Date(filter.dateTo));
    }

    const entries = await this.vehicleRepo.find({ where, order: { entryDate: 'DESC' } });

    const entryIds = entries.map((e) => e.id);
    const sales = entryIds.length
      ? await this.saleRepo.find({ where: { vehicleEntryId: In(entryIds) } })
      : [];
    const saleIds = sales.map((s) => s.id);
    const [payments, commissions] = saleIds.length
      ? await Promise.all([
          this.paymentRepo.find({ where: { saleId: In(saleIds) } }),
          this.commissionRepo.find({
            where: { saleId: In(saleIds), recipientType: commissionType },
          }),
        ])
      : [[], []];

    const paymentsBySale = new Map<string, typeof payments>();
    for (const p of payments) {
      const arr = paymentsBySale.get(p.saleId) ?? [];
      arr.push(p);
      paymentsBySale.set(p.saleId, arr);
    }
    const commissionBySale = new Map<string, (typeof commissions)[number]>();
    for (const c of commissions) commissionBySale.set(c.saleId, c);
    const salesByEntry = new Map<string, typeof sales>();
    for (const s of sales) {
      const arr = salesByEntry.get(s.vehicleEntryId) ?? [];
      arr.push(s);
      salesByEntry.set(s.vehicleEntryId, arr);
    }

    const entryData = entries.map((entry) => {
      const entrySales = salesByEntry.get(entry.id) ?? [];
      const saleData = entrySales.map((sale) => {
        const salePayments = paymentsBySale.get(sale.id) ?? [];
        const paymentTotal = salePayments.reduce((s, p) => s + Number(p.amount), 0);
        return {
          sale,
          payments: salePayments,
          paymentTotal,
          commission: commissionBySale.get(sale.id) ?? null,
        };
      });
      return { entry, sales: saleData };
    });

    const summary = {
      totalVehicleEntries: entries.length,
      totalSales: entryData.reduce((s, e) => s + e.sales.length, 0),
      totalGrossSale: entryData.reduce(
        (s, e) => s + e.sales.reduce((ss, d) => ss + Number(d.sale.grossSale), 0),
        0,
      ),
      totalNetSale: entryData.reduce(
        (s, e) => s + e.sales.reduce((ss, d) => ss + Number(d.sale.netSale), 0),
        0,
      ),
      totalPayments: entryData.reduce(
        (s, e) => s + e.sales.reduce((ss, d) => ss + d.paymentTotal, 0),
        0,
      ),
      totalCommission: entryData.reduce(
        (s, e) =>
          s +
          e.sales.reduce(
            (ss, d) => ss + (d.commission ? Number(d.commission.finalAmount) : 0),
            0,
          ),
        0,
      ),
    };

    return {
      type: filter.type,
      name: filter.name,
      dateFrom: filter.dateFrom,
      dateTo: filter.dateTo,
      summary,
      entries: entryData,
    };
  }

  async exportExcel(filter: StatementFilterDto): Promise<Buffer> {
    const data = await this.getStatement(filter);
    const wb = new ExcelJS.Workbook();
    wb.creator = 'Sangemarmar VTS';
    wb.created = new Date();

    // ── Summary sheet ──────────────────────────────────────────────
    const summary = wb.addWorksheet('Summary');
    summary.columns = [
      { header: 'Field', key: 'field', width: 28 },
      { header: 'Value', key: 'value', width: 20 },
    ];
    summary.getRow(1).font = { bold: true };

    const title = `${data.type.replace('_', ' ')} STATEMENT — ${data.name}`;
    summary.addRow({ field: title, value: '' });
    if (data.dateFrom) summary.addRow({ field: 'Period', value: `${data.dateFrom} to ${data.dateTo}` });
    summary.addRow({});
    summary.addRow({ field: 'Vehicle Entries', value: data.summary.totalVehicleEntries });
    summary.addRow({ field: 'Total Sales', value: data.summary.totalSales });
    summary.addRow({ field: 'Total Gross Sale', value: +data.summary.totalGrossSale.toFixed(2) });
    summary.addRow({ field: 'Total Net Sale', value: +data.summary.totalNetSale.toFixed(2) });
    summary.addRow({ field: 'Total Payments', value: +data.summary.totalPayments.toFixed(2) });
    summary.addRow({ field: 'Total Commission Earned', value: +data.summary.totalCommission.toFixed(2) });

    // ── Details sheet ──────────────────────────────────────────────
    const details = wb.addWorksheet('Details');
    details.columns = [
      { header: 'Entry Date', key: 'entryDate', width: 16 },
      { header: 'Vehicle No.', key: 'vehicleNumber', width: 16 },
      { header: 'Driver', key: 'driver', width: 20 },
      { header: 'Guide', key: 'guide', width: 20 },
      { header: 'Local Agent', key: 'agent', width: 20 },
      { header: 'Company', key: 'company', width: 20 },
      { header: 'Sale Date', key: 'saleDate', width: 14 },
      { header: 'Gross Sale', key: 'grossSale', width: 14 },
      { header: 'Net Sale', key: 'netSale', width: 14 },
      { header: 'Order Type', key: 'orderType', width: 14 },
      { header: 'Payments Total', key: 'payTotal', width: 16 },
      { header: 'Commission Rate', key: 'commRate', width: 16 },
      { header: 'Commission Amt', key: 'commAmt', width: 16 },
      { header: 'Commission Override', key: 'override', width: 18 },
    ];
    details.getRow(1).font = { bold: true };

    for (const { entry, sales } of data.entries) {
      if (sales.length === 0) {
        details.addRow({
          entryDate: new Date(entry.entryDate).toLocaleDateString(),
          vehicleNumber: entry.vehicleNumber,
          driver: entry.driverName,
          guide: entry.guideName,
          agent: entry.localAgent,
          company: entry.companyName,
          saleDate: '—',
          grossSale: 0,
          netSale: 0,
          orderType: '—',
          payTotal: 0,
          commRate: '—',
          commAmt: 0,
          override: 'No',
        });
      }
      for (const { sale, paymentTotal, commission } of sales) {
        details.addRow({
          entryDate: new Date(entry.entryDate).toLocaleDateString(),
          vehicleNumber: entry.vehicleNumber,
          driver: entry.driverName,
          guide: entry.guideName,
          agent: entry.localAgent,
          company: entry.companyName,
          saleDate: new Date(sale.saleDate).toLocaleDateString(),
          grossSale: +Number(sale.grossSale).toFixed(2),
          netSale: +Number(sale.netSale).toFixed(2),
          orderType: sale.orderType.replace('_', ' '),
          payTotal: +paymentTotal.toFixed(2),
          commRate: commission ? `${commission.rate}%` : '—',
          commAmt: commission ? +Number(commission.finalAmount).toFixed(2) : 0,
          override: commission?.isOverridden ? 'Yes' : 'No',
        });
      }
    }

    return wb.xlsx.writeBuffer() as unknown as Promise<Buffer>;
  }

  async exportPdf(filter: StatementFilterDto): Promise<Buffer> {
    const data = await this.getStatement(filter);

    return new Promise<Buffer>((resolve) => {
      const doc = new PDFDocument({ margin: 40, size: 'A4' });
      const chunks: Buffer[] = [];
      doc.on('data', (c) => chunks.push(c));
      doc.on('end', () => resolve(Buffer.concat(chunks)));

      // ── Layout constants ──────────────────────────────────────────────
      const LEFT = 40;
      const RIGHT = 555;
      const WIDTH = RIGHT - LEFT;
      const ROW_H = 18;
      const BOTTOM = 800;
      const GREEN = '#1B5E20';
      const STRIPE = '#F3F6F2';
      const BORDER = '#D5D5D5';

      const fmt = (n: number) =>
        n.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
      const dt = (d: Date | string) => new Date(d).toLocaleDateString('en-GB');

      // ── Page / table helpers ──────────────────────────────────────────
      const drawPageHeader = () => {
        const period = data.dateFrom
          ? `${data.dateFrom} to ${data.dateTo ?? data.dateFrom}`
          : 'All dates';
        doc.fillColor(GREEN).font('Helvetica-Bold').fontSize(18)
          .text('Sangemarmar VTS', LEFT, 40);
        doc.fillColor('#000000').font('Helvetica-Bold').fontSize(11)
          .text(`${data.type.replace('_', ' ')} STATEMENT - ${data.name}`, LEFT, 64);
        doc.fillColor('#666666').font('Helvetica').fontSize(9)
          .text(`Period: ${period}`, LEFT, 79)
          .text(`Generated: ${new Date().toLocaleString('en-GB')}`, LEFT, 79, {
            width: WIDTH,
            align: 'right',
          });
        doc.moveTo(LEFT, 96).lineTo(RIGHT, 96).strokeColor(GREEN).lineWidth(1.5).stroke();
        doc.y = 104;
      };

      type Col = { header: string; width: number; align?: 'left' | 'right' | 'center' };

      const clip = (text: string, width: number): string => {
        const max = width - 10;
        if (doc.widthOfString(text) <= max) return text;
        let str = text;
        while (str.length > 1 && doc.widthOfString(str + '...') > max) {
          str = str.slice(0, -1);
        }
        return str.trimEnd() + '...';
      };

      const drawCells = (
        cols: Col[],
        values: string[],
        y: number,
        font: string,
        size: number,
      ) => {
        doc.font(font).fontSize(size);
        let x = LEFT;
        for (let i = 0; i < cols.length; i++) {
          doc.text(clip(values[i] ?? '', cols[i].width), x + 5, y + 6, {
            width: cols[i].width - 10,
            align: cols[i].align ?? 'left',
            lineBreak: false,
          });
          x += cols[i].width;
        }
      };

      const drawTableHeader = (cols: Col[]) => {
        const y = doc.y;
        doc.rect(LEFT, y, WIDTH, ROW_H).fill(GREEN);
        doc.fillColor('#FFFFFF');
        drawCells(cols, cols.map((c) => c.header), y, 'Helvetica-Bold', 8);
        doc.fillColor('#000000');
        doc.y = y + ROW_H;
      };

      const drawRow = (cols: Col[], values: string[], idx: number, bold = false) => {
        if (doc.y + ROW_H > BOTTOM) {
          doc.addPage();
          drawPageHeader();
          drawTableHeader(cols);
        }
        const y = doc.y;
        if (bold) {
          doc.rect(LEFT, y, WIDTH, ROW_H).fill('#E8EFE6');
        } else if (idx % 2 === 1) {
          doc.rect(LEFT, y, WIDTH, ROW_H).fill(STRIPE);
        }
        doc.fillColor('#000000');
        drawCells(cols, values, y, bold ? 'Helvetica-Bold' : 'Helvetica', 8);
        doc.y = y + ROW_H;
      };

      // ── Render ────────────────────────────────────────────────────────
      drawPageHeader();

      // Summary band — 3-column key/value grid
      const s = data.summary;
      const summaryPairs: [string, string][] = [
        ['Vehicle Entries', s.totalVehicleEntries.toString()],
        ['Total Sales', s.totalSales.toString()],
        ['Total Gross Sale', fmt(s.totalGrossSale)],
        ['Total Net Sale', fmt(s.totalNetSale)],
        ['Total Payments', fmt(s.totalPayments)],
        ['Total Commission', fmt(s.totalCommission)],
      ];
      const sumTop = doc.y;
      const sumH = 56;
      doc.rect(LEFT, sumTop, WIDTH, sumH).fill(STRIPE);
      const cellW = WIDTH / 3;
      summaryPairs.forEach(([label, val], i) => {
        const col = i % 3;
        const rowN = Math.floor(i / 3);
        const cx = LEFT + col * cellW + 10;
        const cy = sumTop + 8 + rowN * 24;
        doc.fillColor('#666666').font('Helvetica').fontSize(8)
          .text(label, cx, cy, { width: cellW - 20, lineBreak: false });
        doc.fillColor(GREEN).font('Helvetica-Bold').fontSize(11)
          .text(val, cx, cy + 9, { width: cellW - 20, lineBreak: false });
      });
      doc.fillColor('#000000');
      doc.y = sumTop + sumH + 12;

      // Transaction table
      const cols: Col[] = [
        { header: 'Entry Date', width: 56 },
        { header: 'Vehicle No.', width: 70 },
        { header: 'Sale Date', width: 56 },
        { header: 'Order Type', width: 78 },
        { header: 'Gross', width: 58, align: 'right' },
        { header: 'Net', width: 58, align: 'right' },
        { header: 'Payments', width: 54, align: 'right' },
        { header: 'Rate', width: 33, align: 'right' },
        { header: 'Comm.', width: 52, align: 'right' },
      ];
      drawTableHeader(cols);

      let idx = 0;
      for (const { entry, sales } of data.entries) {
        if (sales.length === 0) {
          drawRow(cols, [
            dt(entry.entryDate),
            entry.vehicleNumber,
            '-', 'No sale', '-', '-', '-', '-', '-',
          ], idx++);
          continue;
        }
        for (const { sale, paymentTotal, commission } of sales) {
          drawRow(cols, [
            dt(entry.entryDate),
            entry.vehicleNumber,
            dt(sale.saleDate),
            sale.orderType.replace('_', ' '),
            fmt(Number(sale.grossSale)),
            fmt(Number(sale.netSale)),
            fmt(paymentTotal),
            commission ? `${Number(commission.rate)}%` : '-',
            commission
              ? fmt(Number(commission.finalAmount)) + (commission.isOverridden ? '*' : '')
              : '-',
          ], idx++);
        }
      }

      drawRow(cols, [
        'TOTAL', '', '', '',
        fmt(s.totalGrossSale),
        fmt(s.totalNetSale),
        fmt(s.totalPayments),
        '',
        fmt(s.totalCommission),
      ], 0, true);

      doc.moveTo(LEFT, doc.y).lineTo(RIGHT, doc.y)
        .strokeColor(BORDER).lineWidth(0.5).stroke();

      doc.fillColor('#999999').font('Helvetica').fontSize(7)
        .text('* commission amount was manually overridden', LEFT, doc.y + 6);

      doc.end();
    });
  }
}
