import {
  Body, Controller, HttpCode, Post, UseGuards,
} from '@nestjs/common';
import { IsString } from 'class-validator';
import { AdminService } from './admin.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';
import { UserRole } from '../common/enums';

class ResetDto {
  @IsString() password: string;
}

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
export class AdminController {
  constructor(private readonly service: AdminService) {}

  /// One-shot operational-data wipe. Gated by ADMIN role + a fresh password
  /// check in the request body so an active session token alone isn't enough.
  /// Intended for "start fresh today" operations; should be removed from the
  /// codebase after use.
  @Post('reset-operational-data')
  @HttpCode(200)
  reset(@Body() dto: ResetDto, @CurrentUser() user: User) {
    return this.service.resetOperationalData(user, dto.password);
  }
}
