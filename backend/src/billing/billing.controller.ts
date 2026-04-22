import {
  Controller, Get, Post, Patch, Delete,
  Body, Param, Query, Res, UseGuards,
} from '@nestjs/common';
import { Response } from 'express';
import { BillingService } from './billing.service';
import { CreateBillingOrderDto, UpdateBillingOrderDto } from './dto/create-billing-order.dto';
import { BillingFilterDto } from './dto/billing-filter.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';
import { UserRole } from '../common/enums';

@Controller('billing')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN, UserRole.MANAGER)
export class BillingController {
  constructor(private readonly billingService: BillingService) {}

  @Get()
  findAll(@Query() query: BillingFilterDto) {
    return this.billingService.findAll(query);
  }

  @Post()
  create(@Body() dto: CreateBillingOrderDto, @CurrentUser() user: User) {
    return this.billingService.create(dto, user);
  }

  // Static routes must come before :id routes
  @Get('export')
  async exportList(@Query() query: BillingFilterDto, @Res() res: Response) {
    const format: 'xlsx' | 'pdf' = query.format === 'pdf' ? 'pdf' : 'xlsx';
    const date = new Date().toISOString().slice(0, 10);
    const filename = `billing_orders_${date}.${format}`;
    const buffer = await this.billingService.exportList(query, format);

    if (format === 'xlsx') {
      res.set({
        'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'Content-Disposition': `attachment; filename="${filename}"`,
        'Content-Length': buffer.length,
      });
    } else {
      res.set({
        'Content-Type': 'application/pdf',
        'Content-Disposition': `attachment; filename="${filename}"`,
        'Content-Length': buffer.length,
      });
    }
    res.end(buffer);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.billingService.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateBillingOrderDto, @CurrentUser() user: User) {
    return this.billingService.update(id, dto, user);
  }

  @Delete(':id')
  @Roles(UserRole.ADMIN)
  delete(@Param('id') id: string, @CurrentUser() user: User) {
    return this.billingService.delete(id, user);
  }

  @Get(':id/orv')
  async exportOrv(@Param('id') id: string, @Res() res: Response) {
    const buffer = await this.billingService.exportOrv(id);
    res.set({
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename="orv_${id.slice(0, 8)}.pdf"`,
      'Content-Length': buffer.length,
    });
    res.end(buffer);
  }

  @Get(':id/invoice')
  async exportInvoice(@Param('id') id: string, @Res() res: Response) {
    const buffer = await this.billingService.exportInvoice(id);
    res.set({
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename="invoice_${id.slice(0, 8)}.pdf"`,
      'Content-Length': buffer.length,
    });
    res.end(buffer);
  }
}
