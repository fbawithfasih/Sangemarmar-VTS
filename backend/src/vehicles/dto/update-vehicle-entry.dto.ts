import { IsDateString, IsOptional, IsString, IsUUID } from 'class-validator';

export class UpdateVehicleEntryDto {
  @IsOptional() @IsString() vehicleNumber?: string;
  @IsOptional() @IsString() driverName?: string;
  @IsOptional() @IsString() guideName?: string;
  @IsOptional() @IsString() localAgent?: string;
  @IsOptional() @IsString() companyName?: string;
  @IsOptional() @IsDateString() entryDate?: string;
  @IsOptional() @IsString() notes?: string;
  @IsOptional() @IsUUID() assignedSalesmanId?: string;
}
