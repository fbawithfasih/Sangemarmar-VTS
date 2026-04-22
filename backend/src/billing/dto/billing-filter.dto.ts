import { IsOptional, IsString } from 'class-validator';

export class BillingFilterDto {
  @IsOptional() @IsString() dateFrom?: string;
  @IsOptional() @IsString() dateTo?: string;
  @IsOptional() @IsString() vehicleEntryId?: string;
  @IsOptional() @IsString() format?: string;
}
