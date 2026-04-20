import {
  Body, Controller, Get, Param, Patch, Post, Query, UseGuards,
} from '@nestjs/common';
import { VehiclesService } from './vehicles.service';
import { CreateVehicleEntryDto } from './dto/create-vehicle-entry.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';
import { WorkflowStatus } from '../common/enums';

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

  @Patch(':id/status')
  updateStatus(
    @Param('id') id: string,
    @Body('status') status: WorkflowStatus,
    @CurrentUser() user: User,
  ) {
    return this.vehiclesService.updateStatus(id, status, user.id);
  }
}
