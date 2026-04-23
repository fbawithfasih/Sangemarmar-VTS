import {
  Controller, Get, Post, Delete,
  Body, Param, Query, Res, UseGuards,
  BadRequestException, Logger,
} from '@nestjs/common';
import { Response } from 'express';
import { ShippingService } from './shipping.service';
import { GetRatesDto } from './dto/get-rates.dto';
import { CreateShipmentDto } from './dto/create-shipment.dto';
import { ShipmentFilterDto } from './dto/shipment-filter.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';
import { UserRole } from '../common/enums';

@Controller('shipping')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN, UserRole.MANAGER)
export class ShippingController {
  private readonly logger = new Logger(ShippingController.name);
  constructor(private readonly service: ShippingService) {}

  @Post('rates')
  getRates(@Body() dto: GetRatesDto) {
    return this.service.getRates(dto);
  }

  @Post()
  async create(@Body() dto: CreateShipmentDto, @CurrentUser() user: User) {
    try {
      return await this.service.create(dto, user);
    } catch (e) {
      const detail = e?.response?.data ? JSON.stringify(e.response.data) : e?.message ?? 'Carrier error';
      this.logger.error(`createShipment failed: ${detail}`);
      throw new BadRequestException(detail);
    }
  }

  @Get()
  findAll(@Query() filter: ShipmentFilterDto) {
    return this.service.findAll(filter);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.service.findOne(id);
  }

  @Get(':id/label')
  async getLabel(@Param('id') id: string, @Res() res: Response) {
    const buffer = await this.service.getLabel(id);
    res.set({
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename="label_${id.slice(0, 8)}.pdf"`,
      'Content-Length': buffer.length,
    });
    res.end(buffer);
  }

  @Get(':id/track')
  track(@Param('id') id: string) {
    return this.service.track(id);
  }

  @Delete(':id')
  @Roles(UserRole.ADMIN)
  delete(@Param('id') id: string) {
    return this.service.delete(id);
  }
}
