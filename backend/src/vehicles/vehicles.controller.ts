import {
  Body, Controller, Delete, Get, Param, Patch, Post, Put, Query, UseGuards,
} from '@nestjs/common';
import { VehiclesService } from './vehicles.service';
import { CreateVehicleEntryDto } from './dto/create-vehicle-entry.dto';
import { UpdateVehicleEntryDto } from './dto/update-vehicle-entry.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';
import { UserRole, WorkflowStatus } from '../common/enums';

@Controller('vehicles')
@UseGuards(JwtAuthGuard)
export class VehiclesController {
  constructor(private readonly vehiclesService: VehiclesService) {}

  @Post()
  create(@Body() dto: CreateVehicleEntryDto, @CurrentUser() user: User) {
    return this.vehiclesService.create(dto, user);
  }

  @Get()
  findAll(
    @Query('vehicleNumber') vehicleNumber?: string,
    @Query('companyName') companyName?: string,
    @Query('status') status?: WorkflowStatus,
    @Query('dateFrom') dateFrom?: string,
    @Query('dateTo') dateTo?: string,
  ) {
    return this.vehiclesService.findAll({ vehicleNumber, companyName, status, dateFrom, dateTo });
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.vehiclesService.findOne(id);
  }

  @Put(':id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN)
  update(
    @Param('id') id: string,
    @Body() dto: UpdateVehicleEntryDto,
    @CurrentUser() user: User,
  ) {
    return this.vehiclesService.update(id, dto, user);
  }

  @Delete(':id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN)
  delete(@Param('id') id: string, @CurrentUser() user: User) {
    return this.vehiclesService.delete(id, user);
  }

  @Patch(':id/status')
  updateStatus(
    @Param('id') id: string,
    @Body('status') status: WorkflowStatus,
    @CurrentUser() user: User,
  ) {
    return this.vehiclesService.updateStatus(id, status, user.id);
  }
}
