import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { LogisticsService } from './logistics.service';
import { CreateLogisticsEventDto } from './dto/create-logistics-event.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';
import { UserRole } from '../common/enums';

@Controller('logistics')
@UseGuards(JwtAuthGuard)
export class LogisticsController {
  constructor(private readonly logisticsService: LogisticsService) {}

  @Post('events')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.MANAGER, UserRole.GATE_OPERATOR)
  addEvent(@Body() dto: CreateLogisticsEventDto, @CurrentUser() user: User) {
    return this.logisticsService.addEvent(dto, user.id);
  }

  @Get('timeline/:vehicleEntryId')
  getTimeline(@Param('vehicleEntryId') vehicleEntryId: string) {
    return this.logisticsService.getTimeline(vehicleEntryId);
  }
}
