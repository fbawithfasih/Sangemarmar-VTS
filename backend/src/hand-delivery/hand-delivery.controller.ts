import {
  Controller, Get, Post, Patch, Delete,
  Body, Param, Query, UseGuards,
} from '@nestjs/common';
import { HandDeliveryService } from './hand-delivery.service';
import {
  CreateHandDeliveryDto, UpdateHandDeliveryDto, HandDeliveryFilterDto,
} from './dto/create-hand-delivery.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';
import { UserRole } from '../common/enums';

@Controller('hand-delivery')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN, UserRole.MANAGER)
export class HandDeliveryController {
  constructor(private readonly service: HandDeliveryService) {}

  @Get()
  findAll(@Query() query: HandDeliveryFilterDto) {
    return this.service.findAll(query);
  }

  @Post()
  create(@Body() dto: CreateHandDeliveryDto, @CurrentUser() user: User) {
    return this.service.create(dto, user);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.service.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateHandDeliveryDto, @CurrentUser() user: User) {
    return this.service.update(id, dto, user);
  }

  @Delete(':id')
  @Roles(UserRole.ADMIN)
  delete(@Param('id') id: string, @CurrentUser() user: User) {
    return this.service.delete(id, user);
  }
}
