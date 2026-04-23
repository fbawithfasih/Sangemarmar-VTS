import { IsOptional, IsString, IsUUID } from 'class-validator';

export class ShipmentFilterDto {
  @IsOptional()
  @IsUUID()
  billingOrderId?: string;

  @IsOptional()
  @IsString()
  carrier?: string;

  @IsOptional()
  @IsString()
  dateFrom?: string;

  @IsOptional()
  @IsString()
  dateTo?: string;
}
