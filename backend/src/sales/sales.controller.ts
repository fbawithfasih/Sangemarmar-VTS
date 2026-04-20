import {
  Body, Controller, Get, Param, Patch, Post, Query, UseGuards,
} from '@nestjs/common';
import { SalesService } from './sales.service';
import { CreateSaleDto } from './dto/create-sale.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';
import { UserRole } from '../common/enums';

@Controller('sales')
@UseGuards(JwtAuthGuard)
export class SalesController {
  constructor(private readonly salesService: SalesService) {}

  @Post()
  @UseGuards(RolesGuard)
  @Roles(UserRole.GATE_OPERATOR, UserRole.SALES_STAFF, UserRole.MANAGER, UserRole.ADMIN)
  create(@Body() dto: CreateSaleDto, @CurrentUser() user: User) {
    return this.salesService.create(dto, user);
  }

  @Get()
  findAll(
    @Query('vehicleEntryId') vehicleEntryId?: string,
    @Query('salesperson') salesperson?: string,
    @Query('dateFrom') dateFrom?: string,
    @Query('dateTo') dateTo?: string,
  ) {
    return this.salesService.findAll({ vehicleEntryId, salesperson, dateFrom, dateTo });
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.salesService.findOne(id);
  }

  @Patch(':id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.GATE_OPERATOR, UserRole.SALES_STAFF, UserRole.MANAGER, UserRole.ADMIN)
  update(
    @Param('id') id: string,
    @Body() updates: Partial<CreateSaleDto>,
    @CurrentUser() user: User,
  ) {
    return this.salesService.update(id, updates, user.id);
  }
}
