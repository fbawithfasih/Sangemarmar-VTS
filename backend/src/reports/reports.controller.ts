import { Controller, Get, Query, Res, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { ReportsService, ReportFilter, ExportReportType } from './reports.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';
import { UserRole } from '../common/enums';

@Controller('reports')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN, UserRole.MANAGER, UserRole.SALES_STAFF)
export class ReportsController {
  constructor(private readonly reportsService: ReportsService) {}

  private extractFilter(query: any): ReportFilter {
    return {
      dateFrom: query.dateFrom,
      dateTo: query.dateTo,
      salesperson: query.salesperson,
      companyName: query.companyName,
      paymentMode: query.paymentMode,
      status: query.status,
    };
  }

  private applyScope(filter: ReportFilter, user: User): ReportFilter {
    if (user.role === UserRole.SALES_STAFF) {
      return { ...filter, salesperson: user.name };
    }
    return filter;
  }

  @Get('dashboard')
  dashboard(@Query() query: any, @CurrentUser() user: User) {
    return this.reportsService.dashboard(this.applyScope(this.extractFilter(query), user));
  }

  @Get('vehicles')
  vehicles(@Query() query: any) {
    return this.reportsService.vehicleEntries(this.extractFilter(query));
  }

  @Get('sales')
  sales(@Query() query: any, @CurrentUser() user: User) {
    return this.reportsService.sales(this.applyScope(this.extractFilter(query), user));
  }

  @Get('payments')
  payments(@Query() query: any) {
    return this.reportsService.payments(this.extractFilter(query));
  }

  @Get('commissions')
  commissions(@Query() query: any) {
    return this.reportsService.commissions(this.extractFilter(query));
  }

  @Get('export')
  async export(
    @Query() query: any,
    @CurrentUser() user: User,
    @Res() res: Response,
  ) {
    const type = query.type as ExportReportType;
    const format: 'xlsx' | 'pdf' = query.format === 'pdf' ? 'pdf' : 'xlsx';
    const filter = this.applyScope(this.extractFilter(query), user);
    const filename = `${type}_report_${new Date().toISOString().slice(0, 10)}.${format}`;

    if (format === 'xlsx') {
      const buffer = await this.reportsService.exportExcel(type, filter);
      res.set({
        'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'Content-Disposition': `attachment; filename="${filename}"`,
        'Content-Length': buffer.length,
      });
      res.end(buffer);
    } else {
      const buffer = await this.reportsService.exportPdf(type, filter);
      res.set({
        'Content-Type': 'application/pdf',
        'Content-Disposition': `attachment; filename="${filename}"`,
        'Content-Length': buffer.length,
      });
      res.end(buffer);
    }
  }
}
