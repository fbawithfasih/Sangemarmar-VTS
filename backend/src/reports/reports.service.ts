import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, LessThanOrEqual, MoreThanOrEqual, Repository } from 'typeorm';
import * as ExcelJS from 'exceljs';
import * as PDFDocument from 'pdfkit';
import { VehicleEntry } from '../vehicles/entities/vehicle-entry.entity';
import { Sale } from '../sales/entities/sale.entity';
import { Payment } from '../payments/entities/payment.entity';
import { Commission } from '../commissions/entities/commission.entity';

export interface ReportFilter {
  dateFrom?: string;
  dateTo?: string;
  salesperson?: string;
  companyName?: string;
  paymentMode?: string;
  status?: string;
}

// IST is UTC+5:30 = 330 minutes ahead of UTC
// Convert a yyyy-MM-dd date string to UTC timestamps for IST day boundaries
function istDayStart(dateStr: string): Date {
  // e.g. "2026-04-19" → 2026-04-18T18:30:00.000Z (midnight IST = 18:30 UTC prev day)
  return new Date(`${dateStr}T00:00:00+05:30`);
}

function istDayEnd(dateStr: string): Date {
  // e.g. "2026-04-19" → 2026-04-19T18:29:59.999Z (23:59:59 IST = 18:29:59 UTC same day)
  return new Date(`${dateStr}T23:59:59.999+05:30`);
}

function buildDateCondition(field: string, dateFrom?: string, dateTo?: string) {
  if (dateFrom && dateTo) {
    return { [field]: Between(istDayStart(dateFrom), istDayEnd(dateTo)) };
  }
  if (dateFrom) {
    return { [field]: MoreThanOrEqual(istDayStart(dateFrom)) };
  }
  if (dateTo) {
    return { [field]: LessThanOrEqual(istDayEnd(dateTo)) };
  }
  return {};
}

export type ExportReportType = 'sales' | 'payments' | 'vehicles' | 'commissions';

@Injectable()
export class ReportsService {
  constructor(
    @InjectRepository(VehicleEntry) private readonly vehicleRepo: Repository<VehicleEntry>,
    @InjectRepository(Sale) private readonly saleRepo: Repository<Sale>,
    @InjectRepository(Payment) private readonly paymentRepo: Repository<Payment>,
    @InjectRepository(Commission) private readonly commissionRepo: Repository<Commission>,
  ) {}

  async vehicleEntries(filter: ReportFilter) {
    const where: any = {};
    if (filter.companyName) where.companyName = filter.companyName;
    if (filter.status) where.status = filter.status;
    Object.assign(where, buildDateCondition('entryDate', filter.dateFrom, filter.dateTo));
    const entries = await this.vehicleRepo.find({ where, order: { entryDate: 'DESC' }, relations: ['createdBy'] });
    return { count: entries.length, data: entries };
  }

  async sales(filter: ReportFilter) {
    const where: any = {};
    if (filter.salesperson) where.salesperson = filter.salesperson;
    Object.assign(where, buildDateCondition('saleDate', filter.dateFrom, filter.dateTo));
    const sales = await this.saleRepo.find({ where, order: { saleDate: 'DESC' }, relations: ['vehicleEntry', 'createdBy'] });
    const totalGross = sales.reduce((s, r) => s + Number(r.grossSale), 0);
    const totalNet = sales.reduce((s, r) => s + Number(r.netSale), 0);
    return { count: sales.length, totalGross, totalNet, data: sales };
  }

  async payments(filter: ReportFilter) {
    const where: any = {};
    if (filter.paymentMode) where.mode = filter.paymentMode;
    Object.assign(where, buildDateCondition('paymentDate', filter.dateFrom, filter.dateTo));
    const payments = await this.paymentRepo.find({ where, order: { paymentDate: 'DESC' }, relations: ['sale'] });
    const totalAmount = payments.reduce((s, p) => s + Number(p.amount), 0);
    const byMode = payments.reduce((acc, p) => {
      acc[p.mode] = (acc[p.mode] || 0) + Number(p.amount);
      return acc;
    }, {} as Record<string, number>);
    return { count: payments.length, totalAmount, byMode, data: payments };
  }

  async commissions(filter: ReportFilter) {
    const where: any = {};
    Object.assign(where, buildDateCondition('createdAt', filter.dateFrom, filter.dateTo));
    const commissions = await this.commissionRepo.find({ where, order: { createdAt: 'DESC' }, relations: ['sale', 'overriddenBy'] });
    const totalCalculated = commissions.reduce((s, c) => s + Number(c.calculatedAmount), 0);
    const totalFinal = commissions.reduce((s, c) => s + Number(c.finalAmount), 0);
    const overrides = commissions.filter((c) => c.isOverridden).length;
    return { count: commissions.length, totalCalculated, totalFinal, overrides, data: commissions };
  }

  async dashboard(filter: ReportFilter) {
    const vehicleQb = this.vehicleRepo.createQueryBuilder('v');
    if (filter.companyName) vehicleQb.andWhere('v.companyName = :company', { company: filter.companyName });
    if (filter.status) vehicleQb.andWhere('v.status = :status', { status: filter.status });
    if (filter.dateFrom && filter.dateTo) {
      vehicleQb.andWhere('v.entryDate BETWEEN :df AND :dt', { df: istDayStart(filter.dateFrom), dt: istDayEnd(filter.dateTo) });
    } else if (filter.dateFrom) {
      vehicleQb.andWhere('v.entryDate >= :df', { df: istDayStart(filter.dateFrom) });
    } else if (filter.dateTo) {
      vehicleQb.andWhere('v.entryDate <= :dt', { dt: istDayEnd(filter.dateTo) });
    }

    const saleQb = this.saleRepo.createQueryBuilder('s');
    if (filter.salesperson) saleQb.andWhere('s.salesperson = :sp', { sp: filter.salesperson });
    if (filter.dateFrom && filter.dateTo) {
      saleQb.andWhere('s.saleDate BETWEEN :df AND :dt', { df: istDayStart(filter.dateFrom), dt: istDayEnd(filter.dateTo) });
    } else if (filter.dateFrom) {
      saleQb.andWhere('s.saleDate >= :df', { df: istDayStart(filter.dateFrom) });
    } else if (filter.dateTo) {
      saleQb.andWhere('s.saleDate <= :dt', { dt: istDayEnd(filter.dateTo) });
    }

    const payQb = this.paymentRepo.createQueryBuilder('p');
    if (filter.paymentMode) payQb.andWhere('p.mode = :m', { m: filter.paymentMode });
    if (filter.dateFrom && filter.dateTo) {
      payQb.andWhere('p.paymentDate BETWEEN :df AND :dt', { df: istDayStart(filter.dateFrom), dt: istDayEnd(filter.dateTo) });
    } else if (filter.dateFrom) {
      payQb.andWhere('p.paymentDate >= :df', { df: istDayStart(filter.dateFrom) });
    } else if (filter.dateTo) {
      payQb.andWhere('p.paymentDate <= :dt', { dt: istDayEnd(filter.dateTo) });
    }

    const commQb = this.commissionRepo.createQueryBuilder('c');
    if (filter.dateFrom && filter.dateTo) {
      commQb.andWhere('c.createdAt BETWEEN :df AND :dt', { df: istDayStart(filter.dateFrom), dt: istDayEnd(filter.dateTo) });
    } else if (filter.dateFrom) {
      commQb.andWhere('c.createdAt >= :df', { df: istDayStart(filter.dateFrom) });
    } else if (filter.dateTo) {
      commQb.andWhere('c.createdAt <= :dt', { dt: istDayEnd(filter.dateTo) });
    }

    const [vAgg, sAgg, pAgg, pByMode, cAgg] = await Promise.all([
      vehicleQb.clone().select('COUNT(*)', 'count').getRawOne<{ count: string }>(),
      saleQb.clone()
        .select('COUNT(*)', 'count')
        .addSelect('COALESCE(SUM(s.grossSale),0)', 'gross')
        .addSelect('COALESCE(SUM(s.netSale),0)', 'net')
        .getRawOne<{ count: string; gross: string; net: string }>(),
      payQb.clone()
        .select('COUNT(*)', 'count')
        .addSelect('COALESCE(SUM(p.amount),0)', 'amount')
        .getRawOne<{ count: string; amount: string }>(),
      payQb.clone()
        .select('p.mode', 'mode')
        .addSelect('COALESCE(SUM(p.amount),0)', 'amount')
        .groupBy('p.mode')
        .getRawMany<{ mode: string; amount: string }>(),
      commQb.clone()
        .select('COUNT(*)', 'count')
        .addSelect('COALESCE(SUM(c.finalAmount),0)', 'final')
        .addSelect("COUNT(*) FILTER (WHERE c.isOverridden = true)", 'overrides')
        .getRawOne<{ count: string; final: string; overrides: string }>(),
    ]);

    const byMode = pByMode.reduce((acc, r) => {
      acc[r.mode] = Number(r.amount);
      return acc;
    }, {} as Record<string, number>);

    return {
      vehicles: { count: Number(vAgg?.count ?? 0) },
      sales: { count: Number(sAgg?.count ?? 0), totalGross: Number(sAgg?.gross ?? 0), totalNet: Number(sAgg?.net ?? 0) },
      payments: { count: Number(pAgg?.count ?? 0), totalAmount: Number(pAgg?.amount ?? 0), byMode },
      commissions: { count: Number(cAgg?.count ?? 0), totalFinal: Number(cAgg?.final ?? 0), overrides: Number(cAgg?.overrides ?? 0) },
    };
  }

  // ── Exports ─────────────────────────────────────────────────────────────

  async exportExcel(type: ExportReportType, filter: ReportFilter): Promise<Buffer> {
    const wb = new ExcelJS.Workbook();
    wb.creator = 'Sangemarmar VTS';
    wb.created = new Date();
    const ws = wb.addWorksheet(type.toUpperCase());

    if (type === 'sales') {
      const { data, totalGross, totalNet } = await this.sales(filter);
      ws.columns = [
        { header: 'Sale Date', key: 'saleDate', width: 14 },
        { header: 'Vehicle No.', key: 'vehicle', width: 16 },
        { header: 'Salesperson', key: 'salesperson', width: 20 },
        { header: 'Order Type', key: 'orderType', width: 14 },
        { header: 'Gross Sale', key: 'grossSale', width: 14 },
        { header: 'Net Sale', key: 'netSale', width: 14 },
      ];
      ws.getRow(1).font = { bold: true };
      data.forEach((s) =>
        ws.addRow({
          saleDate: new Date(s.saleDate).toLocaleDateString(),
          vehicle: s.vehicleEntry?.vehicleNumber ?? '—',
          salesperson: s.salesperson,
          orderType: s.orderType.replace('_', ' '),
          grossSale: +Number(s.grossSale).toFixed(2),
          netSale: +Number(s.netSale).toFixed(2),
        }),
      );
      ws.addRow({});
      ws.addRow({ salesperson: 'TOTALS', grossSale: +totalGross.toFixed(2), netSale: +totalNet.toFixed(2) }).font = { bold: true };
    }

    if (type === 'payments') {
      const { data, totalAmount, byMode } = await this.payments(filter);
      ws.columns = [
        { header: 'Payment Date', key: 'date', width: 14 },
        { header: 'Mode', key: 'mode', width: 8 },
        { header: 'Amount', key: 'amount', width: 14 },
        { header: 'Sale ID', key: 'saleId', width: 38 },
        { header: 'Notes', key: 'notes', width: 24 },
      ];
      ws.getRow(1).font = { bold: true };
      data.forEach((p) =>
        ws.addRow({
          date: new Date(p.paymentDate).toLocaleDateString(),
          mode: p.mode,
          amount: +Number(p.amount).toFixed(2),
          saleId: p.saleId,
          notes: p.notes ?? '',
        }),
      );
      ws.addRow({});
      ws.addRow({ mode: 'TOTAL', amount: +totalAmount.toFixed(2) }).font = { bold: true };
      Object.entries(byMode).forEach(([mode, amt]) =>
        ws.addRow({ mode, amount: +Number(amt).toFixed(2) }),
      );
    }

    if (type === 'vehicles') {
      const { data } = await this.vehicleEntries(filter);
      ws.columns = [
        { header: 'Entry Date', key: 'date', width: 14 },
        { header: 'Vehicle No.', key: 'vehicle', width: 16 },
        { header: 'Driver', key: 'driver', width: 20 },
        { header: 'Guide', key: 'guide', width: 20 },
        { header: 'Local Agent', key: 'agent', width: 20 },
        { header: 'Company', key: 'company', width: 20 },
        { header: 'Status', key: 'status', width: 18 },
      ];
      ws.getRow(1).font = { bold: true };
      data.forEach((e) =>
        ws.addRow({
          date: new Date(e.entryDate).toLocaleDateString(),
          vehicle: e.vehicleNumber,
          driver: e.driverName,
          guide: e.guideName,
          agent: e.localAgent,
          company: e.companyName,
          status: e.status.replace(/_/g, ' '),
        }),
      );
    }

    if (type === 'commissions') {
      const { data, totalFinal } = await this.commissions(filter);
      ws.columns = [
        { header: 'Date', key: 'date', width: 14 },
        { header: 'Recipient', key: 'recipient', width: 20 },
        { header: 'Type', key: 'type', width: 14 },
        { header: 'Rate %', key: 'rate', width: 10 },
        { header: 'Calculated', key: 'calculated', width: 14 },
        { header: 'Final', key: 'final', width: 14 },
        { header: 'Overridden', key: 'overridden', width: 12 },
        { header: 'Payment Status', key: 'paymentStatus', width: 18 },
        { header: 'Paid Amount', key: 'paidAmount', width: 14 },
        { header: 'Paid Date', key: 'paidDate', width: 14 },
      ];
      ws.getRow(1).font = { bold: true };
      let totalPaid = 0;
      data.forEach((c) => {
        const paid = Number(c.paidAmount ?? 0);
        const final = Number(c.finalAmount);
        totalPaid += paid;
        const paymentStatus =
          paid <= 0 ? 'Commission Pending' : paid < final ? 'Partially Paid' : 'Paid';
        ws.addRow({
          date: new Date(c.createdAt).toLocaleDateString(),
          recipient: c.recipientName,
          type: c.recipientType.replace('_', ' '),
          rate: +Number(c.rate).toFixed(2),
          calculated: +Number(c.calculatedAmount).toFixed(2),
          final: +final.toFixed(2),
          overridden: c.isOverridden ? 'Yes' : 'No',
          paymentStatus,
          paidAmount: paid > 0 ? +paid.toFixed(2) : '',
          paidDate: c.paidAt ? new Date(c.paidAt).toLocaleDateString() : '',
        });
      });
      ws.addRow({});
      ws.addRow({
        recipient: 'TOTAL',
        final: +totalFinal.toFixed(2),
        paidAmount: +totalPaid.toFixed(2),
      }).font = { bold: true };
    }

    return wb.xlsx.writeBuffer() as unknown as Promise<Buffer>;
  }

  async exportPdf(type: ExportReportType, filter: ReportFilter): Promise<Buffer> {
    return new Promise(async (resolve) => {
      const doc = new PDFDocument({ margin: 40, size: 'A4' });
      const chunks: Buffer[] = [];
      doc.on('data', (c) => chunks.push(c));
      doc.on('end', () => resolve(Buffer.concat(chunks)));

      const period =
        filter.dateFrom ? ` | ${filter.dateFrom} — ${filter.dateTo}` : '';
      const title = `${type.toUpperCase()} REPORT${period}`;

      doc.fontSize(16).font('Helvetica-Bold').text('Sangemarmar VTS', { align: 'center' });
      doc.fontSize(12).font('Helvetica').text(title, { align: 'center' });
      doc.moveDown();
      doc.moveTo(40, doc.y).lineTo(555, doc.y).stroke();
      doc.moveDown(0.5);

      const fmt = (n: number) =>
        n.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

      if (type === 'sales') {
        const { data, totalGross, totalNet, count } = await this.sales(filter);
        doc.font('Helvetica-Bold').fontSize(10).text(`Total Records: ${count}   Gross: ${fmt(totalGross)}   Net: ${fmt(totalNet)}`);
        doc.moveDown(0.5);
        for (const s of data) {
          if (doc.y > 720) doc.addPage();
          doc.font('Helvetica-Bold').fontSize(9)
            .text(`${new Date(s.saleDate).toLocaleDateString()}  ${s.vehicleEntry?.vehicleNumber ?? '—'}  ${s.salesperson}`, { continued: true })
            .font('Helvetica')
            .text(`   Gross: ${fmt(Number(s.grossSale))}   Net: ${fmt(Number(s.netSale))}   [${s.orderType.replace('_', ' ')}]`);
        }
      }

      if (type === 'payments') {
        const { data, totalAmount, byMode, count } = await this.payments(filter);
        doc.font('Helvetica-Bold').fontSize(10).text(`Total Records: ${count}   Total Amount: ${fmt(totalAmount)}`);
        Object.entries(byMode).forEach(([m, a]) =>
          doc.font('Helvetica').fontSize(9).text(`  ${m}: ${fmt(Number(a))}`),
        );
        doc.moveDown(0.5);
        for (const p of data) {
          if (doc.y > 720) doc.addPage();
          doc.font('Helvetica').fontSize(9)
            .text(`${new Date(p.paymentDate).toLocaleDateString()}  [${p.mode}]  ${fmt(Number(p.amount))}${p.notes ? '  — ' + p.notes : ''}`);
        }
      }

      if (type === 'vehicles') {
        const { data, count } = await this.vehicleEntries(filter);
        doc.font('Helvetica-Bold').fontSize(10).text(`Total Records: ${count}`);
        doc.moveDown(0.5);
        for (const e of data) {
          if (doc.y > 720) doc.addPage();
          doc.font('Helvetica-Bold').fontSize(9).text(`${e.vehicleNumber}  [${e.status.replace(/_/g, ' ')}]  ${new Date(e.entryDate).toLocaleDateString()}`);
          doc.font('Helvetica').fontSize(8).text(`  Driver: ${e.driverName}   Guide: ${e.guideName}   Agent: ${e.localAgent}   Company: ${e.companyName}`);
        }
      }

      if (type === 'commissions') {
        const { data, totalFinal, count, overrides } = await this.commissions(filter);
        const totalPaid = data.reduce((s, c) => s + Number(c.paidAmount ?? 0), 0);
        doc.font('Helvetica-Bold').fontSize(10)
          .text(`Total Records: ${count}   Total Commission: ${fmt(totalFinal)}   Total Paid: ${fmt(totalPaid)}   Overrides: ${overrides}`);
        doc.moveDown(0.5);
        for (const c of data) {
          if (doc.y > 720) doc.addPage();
          const paid = Number(c.paidAmount ?? 0);
          const final = Number(c.finalAmount);
          const paymentStatus =
            paid <= 0 ? 'Commission Pending' : paid < final ? `Partially Paid (${fmt(paid)})` : `Paid (${fmt(paid)})`;
          const paidDate = c.paidAt ? ` on ${new Date(c.paidAt).toLocaleDateString()}` : '';
          doc.font('Helvetica').fontSize(9)
            .text(`${c.recipientName} [${c.recipientType.replace('_', ' ')}]  ${c.rate}%  →  ${fmt(final)}${c.isOverridden ? ' [OVERRIDDEN]' : ''}  —  ${paymentStatus}${paidDate}`);
        }
      }

      doc.end();
    });
  }
}
