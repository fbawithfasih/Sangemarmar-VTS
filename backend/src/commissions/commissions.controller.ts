import { Body, Controller, Get, Param, Patch, Put, Query, UseGuards } from '@nestjs/common';
import { CommissionsService } from './commissions.service';
import { OverrideCommissionDto } from './dto/override-commission.dto';
import { UpdateCommissionConfigDto } from './dto/update-commission-config.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';
import { CommissionRecipientType, UserRole } from '../common/enums';

@Controller('commissions')
@UseGuards(JwtAuthGuard)
export class CommissionsController {
  constructor(private readonly commissionsService: CommissionsService) {}

  @Get('config')
  getConfigs() {
    return this.commissionsService.getConfigs();
  }

  @Put('config')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.MANAGER)
  updateConfigs(@Body() dto: UpdateCommissionConfigDto, @CurrentUser() user: User) {
    return this.commissionsService.updateConfigs(dto, user);
  }

  @Get()
  findAll(
    @Query('saleId') saleId?: string,
    @Query('recipientType') recipientType?: CommissionRecipientType,
  ) {
    return this.commissionsService.findAll({ saleId, recipientType });
  }

  @Get('sale/:saleId')
  findBySale(@Param('saleId') saleId: string) {
    return this.commissionsService.findBySale(saleId);
  }

  @Patch(':id/override')
  override(
    @Param('id') id: string,
    @Body() dto: OverrideCommissionDto,
    @CurrentUser() user: User,
  ) {
    return this.commissionsService.override(id, dto, user);
  }
}
