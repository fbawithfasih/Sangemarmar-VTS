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

      const fmt = (n: number) =>
        n.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

      // Header
      doc.fontSize(18).font('Helvetica-Bold').text('Sangemarmar VTS', { align: 'center' });
      doc.fontSize(13).font('Helvetica').text(
        `${data.type.replace('_', ' ')} Statement — ${data.name}`,
        { align: 'center' },
      );
      if (data.dateFrom) {
        doc.fontSize(10).text(`Period: ${data.dateFrom} to ${data.dateTo}`, { align: 'center' });
      }
      doc.moveDown();
      doc.moveTo(40, doc.y).lineTo(555, doc.y).stroke();
      doc.moveDown(0.5);

      // Summary box
      doc.fontSize(11).font('Helvetica-Bold').text('Summary');
      doc.font('Helvetica').fontSize(10);
      const s = data.summary;
      const rows = [
        ['Vehicle Entries', s.totalVehicleEntries.toString()],
        ['Total Sales', s.totalSales.toString()],
        ['Total Gross Sale', fmt(s.totalGrossSale)],
        ['Total Net Sale', fmt(s.totalNetSale)],
        ['Total Payments', fmt(s.totalPayments)],
        ['Total Commission Earned', fmt(s.totalCommission)],
      ];
      for (const [label, val] of rows) {
        doc.text(label, 40, doc.y, { continued: true, width: 260 });
        doc.text(val, { align: 'right' });
      }
      doc.moveDown();
      doc.moveTo(40, doc.y).lineTo(555, doc.y).stroke();
      doc.moveDown(0.5);

      // Details
      doc.fontSize(11).font('Helvetica-Bold').text('Transaction Details');
      doc.moveDown(0.5);

      for (const { entry, sales } of data.entries) {
        doc
          .fontSize(10)
          .font('Helvetica-Bold')
          .text(`${entry.vehicleNumber}  |  ${new Date(entry.entryDate).toLocaleDateString()}`, {
            underline: true,
          });
        doc
          .font('Helvetica')
          .fontSize(9)
          .text(
            `Driver: ${entry.driverName}   Guide: ${entry.guideName}   Agent: ${entry.localAgent}   Company: ${entry.companyName}`,
          );

        if (sales.length === 0) {
          doc.text('  No sales recorded');
        }

        for (const { sale, payments, paymentTotal, commission } of sales) {
          doc.moveDown(0.3);
          doc.font('Helvetica-Bold').fontSize(9).text(
            `  Sale — ${new Date(sale.saleDate).toLocaleDateString()}  |  ${sale.orderType.replace('_', ' ')}`,
          );
          doc.font('Helvetica').fontSize(9);
          doc.text(`    Gross: ${fmt(Number(sale.grossSale))}   Net: ${fmt(Number(sale.netSale))}`);
          doc.text(`    Payments: ${fmt(paymentTotal)}`);
          if (commission) {
            doc.text(
              `    Commission (${commission.rate}%): ${fmt(Number(commission.finalAmount))}${commission.isOverridden ? ' [overridden]' : ''}`,
            );
          }

          // Payment breakdown
          for (const p of payments) {
            doc.text(
              `      · ${p.mode}  ${fmt(Number(p.amount))}  ${new Date(p.paymentDate).toLocaleDateString()}`,
            );
          }
        }

        doc.moveDown(0.5);
        if (doc.y > 720) doc.addPage();
      }

      doc.end();
    });
  }
}
